#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr EXPORTS_SCRIPT="$REPO_ROOT/scripts/_internal/paths.exports.zsh"
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
  return 0
}

[[ -f "$EXPORTS_SCRIPT" ]] || fail "missing script: $EXPORTS_SCRIPT"

typeset tmp_home=''
tmp_home="$(mktemp -d 2>/dev/null || mktemp -d -t paths-exports-test.XXXXXX)" || fail "mktemp failed"

{
  typeset expected_zdotdir="$tmp_home/.config/zsh"
  typeset expected_cache_dir="$expected_zdotdir/cache"
  typeset expected_histfile="$expected_cache_dir/.zsh_history"
  typeset expected_bin_dir="$expected_zdotdir/bin"
  typeset expected_auth_file="$tmp_home/.codex/auth.json"
  typeset expected_secret_dir="$tmp_home/.config/codex_secrets"

  typeset output='' rc=0
  output="$("$ZSH_BIN" -f -c '
    unset ZDOTDIR \
      ZSH_CONFIG_DIR \
      ZSH_BOOTSTRAP_SCRIPT_DIR \
      ZSH_SCRIPT_DIR \
      ZSH_BIN_DIR \
      ZSH_TOOLS_DIR \
      ZSH_CACHE_DIR \
      ZSH_COMPDUMP \
      HISTFILE \
      CODEX_AUTH_FILE \
      CODEX_SECRET_DIR \
      CODEX_PROMPT_SEGMENT_ENABLED \
      CLAUDE_PROMPT_SEGMENT_ENABLED
    HOME="$1"
    source "$2"
    print -r -- "$ZDOTDIR"
    print -r -- "$ZSH_BIN_DIR"
    print -r -- "$ZSH_CACHE_DIR"
    print -r -- "$HISTFILE"
    print -r -- "$CODEX_AUTH_FILE"
    print -r -- "$CODEX_SECRET_DIR"
    print -r -- "$CODEX_PROMPT_SEGMENT_ENABLED"
    print -r -- "$CLAUDE_PROMPT_SEGMENT_ENABLED"
    typeset bin_index="$path[(I)$ZDOTDIR/bin]"
    print -r -- "${path[$bin_index]-}"
  ' zsh "$tmp_home" "$EXPORTS_SCRIPT" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "sourcing paths.exports should exit 0" || fail "$output"

  typeset -a lines=("${(@f)output}")
  if (( ${#lines[@]} < 9 )); then
    fail "unexpected output (expected 9 lines): $output"
  fi

  assert_eq "$expected_zdotdir" "${lines[1]}" "ZDOTDIR should default to HOME/.config/zsh" || fail "$output"
  assert_eq "$expected_bin_dir" "${lines[2]}" "ZSH_BIN_DIR should default under ZDOTDIR" || fail "$output"
  assert_eq "$expected_cache_dir" "${lines[3]}" "ZSH_CACHE_DIR should default under ZDOTDIR" || fail "$output"
  assert_eq "$expected_histfile" "${lines[4]}" "HISTFILE should default under cache dir" || fail "$output"
  assert_eq "$expected_auth_file" "${lines[5]}" "CODEX_AUTH_FILE should default to Codex CLI auth path" || fail "$output"
  assert_eq "$expected_secret_dir" "${lines[6]}" "CODEX_SECRET_DIR should default to local config secrets" || fail "$output"
  assert_eq false "${lines[7]}" "Codex prompt segment should default to opt-in" || fail "$output"
  assert_eq false "${lines[8]}" "Claude prompt segment should default to opt-in" || fail "$output"
  assert_eq "$expected_bin_dir" "${lines[9]}" "ZDOTDIR/bin should be on PATH for repo wrappers" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_home"
}
