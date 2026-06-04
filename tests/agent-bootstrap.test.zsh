#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr BOOTSTRAP_SCRIPT="$REPO_ROOT/bootstrap/agent-bootstrap.zsh"
typeset -gr DISPATCHER="$REPO_ROOT/.agents/scripts/bootstrap.sh"
typeset -gr ZSH_BIN="$(command -v zsh)"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

assert_eq() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset expected="$1" actual="$2" context="$3"
  if [[ "$actual" != "$expected" ]]; then
    print -u2 -r -- "Expected: $expected"
    print -u2 -r -- "Actual  : $actual"
    print -u2 -r -- "Context : $context"
    return 1
  fi
}

assert_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" needle="$2" context="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    print -u2 -r -- "Missing substring: $needle"
    print -u2 -r -- "Context         : $context"
    return 1
  fi
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-agent-bootstrap-test.XXXXXX)" || fail "mktemp failed"

{
  mkdir -p -- "$tmp_dir/bin" "$tmp_dir/home"
  cat > "$tmp_dir/bin/zsh-kit" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$ZSH_KIT_ARGS_FILE"
exit 0
EOF
  chmod +x "$tmp_dir/bin/zsh-kit"

  typeset output='' rc=0 args=''
  output="$(
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
      HOME="$tmp_dir/home" \
      ZSH_KIT_ARGS_FILE="$tmp_dir/args-direct" \
      "$ZSH_BIN" -f -- "$BOOTSTRAP_SCRIPT" \
        --apply \
        --repo "$REPO_ROOT" \
        --dest "$tmp_dir/dest" \
        --features docker,opencode \
        --install-tools repo \
        --force \
        --format json \
        --no-smoke \
        2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "agent bootstrap direct apply should pass" || fail "$output"
  assert_contains "$output" "mode=apply" "direct output mode" || fail "$output"
  assert_contains "$output" "repo=$REPO_ROOT" "direct output repo" || fail "$output"
  args="$(<"$tmp_dir/args-direct")"
  assert_contains "$args" "setup" "direct zsh-kit args" || fail "$args"
  assert_contains "$args" "--apply" "direct zsh-kit args" || fail "$args"
  assert_contains "$args" "--write-zshenv" "direct zsh-kit args" || fail "$args"
  assert_contains "$args" "--install-tools" "direct zsh-kit args" || fail "$args"
  assert_contains "$args" "repo" "direct zsh-kit args" || fail "$args"
  assert_contains "$args" "--features" "direct zsh-kit args" || fail "$args"
  assert_contains "$args" "--force" "direct zsh-kit args" || fail "$args"
  assert_contains "$args" "--format" "direct zsh-kit args" || fail "$args"

  output="$(
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
      HOME="$tmp_dir/home" \
      ZSH_KIT_ARGS_FILE="$tmp_dir/args-dispatch" \
      "$DISPATCHER" \
        --dry-run \
        --repo "$REPO_ROOT" \
        --dest "$tmp_dir/dispatch-dest" \
        --no-write-zshenv \
        --no-smoke \
        2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "project bootstrap dispatcher should pass args through" || fail "$output"
  args="$(<"$tmp_dir/args-dispatch")"
  assert_contains "$args" "--dry-run" "dispatcher zsh-kit args" || fail "$args"
  assert_contains "$args" "$tmp_dir/dispatch-dest" "dispatcher zsh-kit dest" || fail "$args"

  output="$(
    PATH="/usr/bin:/bin" \
      HOME="$tmp_dir/home" \
      "$ZSH_BIN" -f -- "$BOOTSTRAP_SCRIPT" --dry-run --no-smoke \
      2>&1
  )"
  rc=$?
  assert_eq 1 "$rc" "missing zsh-kit should fail" || fail "$output"
  assert_contains "$output" "zsh-kit not found" "missing zsh-kit output" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
