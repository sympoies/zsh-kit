#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

# When this test runs inside a git hook (e.g. lefthook pre-push), git exports
# GIT_DIR / GIT_WORK_TREE / GIT_INDEX_FILE into the environment. They leak into
# the `git clone` that `zsh-kit setup` performs against its own temp repos and
# break it ("working tree already exists" / wrong detected origin). This test
# manages its own repos, so drop any inherited git context up front.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_REFLOG_ACTION

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr HOOK_SCRIPT="$REPO_ROOT/bootstrap/zsh-kit-setup.zsh"
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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-setup-test.XXXXXX)" || fail "mktemp failed"

{
  [[ -f "$HOOK_SCRIPT" ]] || fail "hook missing: $HOOK_SCRIPT"

  typeset output='' rc=0
  output="$(
    HOME="$tmp_dir/home" \
      ZDOTDIR="$tmp_dir/not-zdotdir" \
      "$ZSH_BIN" -f -- "$HOOK_SCRIPT" \
        --features 'docker, opencode,docker' \
        --install-tools skip \
        --dry-run \
        2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "dry-run hook should pass" || fail "$output"
  assert_contains "$output" "features=docker,opencode" "features should normalize and dedupe" || fail "$output"
  assert_contains "$output" "install-tools skipped" "skip policy should not run installer" || fail "$output"
  [[ ! -e "$tmp_dir/home/.zshenv" ]] || fail "dry-run hook must not create home .zshenv"

  typeset fake_bin="$tmp_dir/fake-bin"
  mkdir -p -- "$fake_bin"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'if [[ "${1-}" == print-config ]]; then'
    print -r -- '  print -u2 -r -- "WARN - (starship::config): Error in '\''Custom'\'' at '\''unsafe_no_escape'\'': Unknown key"'
    print -r -- '  exit 0'
    print -r -- 'fi'
    print -r -- 'exit 1'
  } >| "$fake_bin/starship"
  chmod 755 "$fake_bin/starship"

  output="$(
    HOME="$tmp_dir/home" \
      ZSH_KIT_SETUP_STARSHIP_BIN="$fake_bin/starship" \
      "$ZSH_BIN" -f -- "$HOOK_SCRIPT" \
        --features docker \
        --install-tools skip \
        --dry-run \
        2>&1
  )"
  rc=$?
  assert_eq 1 "$rc" "old starship should fail setup validation" || fail "$output"
  assert_contains "$output" "installed starship cannot parse config" "old starship output" || fail "$output"

  typeset fake_linuxbrew_bin="$tmp_dir/home/.linuxbrew/bin"
  mkdir -p -- "$fake_linuxbrew_bin"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'if [[ "${1-}" == print-config ]]; then'
    print -r -- '  print -r -- "[custom.codex_rate_limits]"'
    print -r -- '  print -r -- "unsafe_no_escape = true"'
    print -r -- '  print -r -- "[custom.claude_rate_limits]"'
    print -r -- '  print -r -- "unsafe_no_escape = true"'
    print -r -- '  exit 0'
    print -r -- 'fi'
    print -r -- 'exit 0'
  } >| "$fake_linuxbrew_bin/starship"
  chmod 755 "$fake_linuxbrew_bin/starship"

  output="$(
    HOME="$tmp_dir/home" \
      "$ZSH_BIN" -f -- "$HOOK_SCRIPT" \
        --features docker \
        --install-tools skip \
        --dry-run \
        2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "setup should prefer HOME Linuxbrew starship in non-login shells" || fail "$output"
  assert_contains "$output" "zsh-kit setup: complete" "Linuxbrew starship output" || fail "$output"
  rm -f -- "$fake_linuxbrew_bin/starship"

  output="$(
    HOME="$tmp_dir/home" \
      "$ZSH_BIN" -f -- "$HOOK_SCRIPT" \
        --features 'bad/value' \
        --install-tools skip \
        --dry-run \
        2>&1
  )"
  rc=$?
  assert_eq 2 "$rc" "invalid feature should fail with usage status" || fail "$output"
  assert_contains "$output" "invalid feature name" "invalid feature output" || fail "$output"

  output="$(
    HOME="$tmp_dir/home" \
      "$ZSH_BIN" -f -- "$HOOK_SCRIPT" \
        --features docker \
        --install-tools skip \
        --dry-run \
        --smoke \
        2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "smoke hook should pass" || fail "$output"
  assert_contains "$output" "running smoke validation" "smoke output" || fail "$output"

  if command -v zsh-kit >/dev/null 2>&1; then
    typeset cli_home="$tmp_dir/cli-home"
    typeset cli_dest="$tmp_dir/cli-dest"
    mkdir -p -- "$cli_home"

    output="$(
      env -u ZDOTDIR -u ZSH_CONFIG_DIR -u ZSH_BOOTSTRAP_SCRIPT_DIR -u ZSH_SCRIPT_DIR \
        -u ZSH_TOOLS_DIR -u ZSH_CACHE_DIR -u ZSH_COMPDUMP \
        HOME="$cli_home" \
        zsh-kit setup \
          --repo "$REPO_ROOT" \
          --dest "$cli_dest" \
          --write-zshenv \
          --features docker,opencode \
          --install-tools skip \
          --apply \
          --format json \
          2>&1
    )"
    rc=$?
    assert_eq 0 "$rc" "fresh-home zsh-kit apply should pass" || fail "$output"
    assert_contains "$output" '"mutation_status":"applied"' "fresh-home apply output" || fail "$output"

    output="$(
      env -u ZDOTDIR -u ZSH_CONFIG_DIR -u ZSH_BOOTSTRAP_SCRIPT_DIR -u ZSH_SCRIPT_DIR \
        -u ZSH_TOOLS_DIR -u ZSH_CACHE_DIR -u ZSH_COMPDUMP \
        HOME="$cli_home" \
        zsh-kit setup \
          --repo "$REPO_ROOT" \
          --dest "$cli_dest" \
          --write-zshenv \
          --features docker,opencode \
          --install-tools skip \
          --apply \
          --format json \
          2>&1
    )"
    rc=$?
    assert_eq 0 "$rc" "repeated zsh-kit apply should pass" || fail "$output"

    [[ -f "$cli_home/.zshenv" ]] || fail "managed home .zshenv was not written"
    assert_contains "$(<"$cli_home/.zshenv")" "Managed by zsh-kit" "managed zshenv marker" || fail "$(<"$cli_home/.zshenv")"

    output="$(
      env -u ZDOTDIR -u ZSH_CONFIG_DIR -u ZSH_BOOTSTRAP_SCRIPT_DIR -u ZSH_SCRIPT_DIR \
        -u ZSH_TOOLS_DIR -u ZSH_CACHE_DIR -u ZSH_COMPDUMP \
        HOME="$cli_home" \
        ZSH_BOOT_WEATHER_ENABLED=false \
        ZSH_BOOT_QUOTE_ENABLED=false \
        PLUGIN_FETCH_DRY_RUN_ENABLED=true \
        "$ZSH_BIN" -ic 'print -r -- "zdot=$ZDOTDIR"; print -r -- "features=$ZSH_FEATURES"; exit' \
        2>&1
    )"
    rc=$?
    assert_eq 0 "$rc" "managed zshenv shell smoke should pass" || fail "$output"
    assert_contains "$output" "zdot=$cli_dest" "managed zshenv should set ZDOTDIR" || fail "$output"
    assert_contains "$output" "features=docker,opencode" "managed zshenv should set features" || fail "$output"
  else
    print -r -- "SKIP: zsh-kit CLI not found"
  fi

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
