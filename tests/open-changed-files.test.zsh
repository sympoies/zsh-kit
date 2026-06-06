#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr TOOL_SCRIPT="$REPO_ROOT/tools/open-changed-files.zsh"
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

assert_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" needle="$2" context="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    print -u2 -r -- "Missing substring: $needle"
    print -u2 -r -- "Context         : $context"
    return 1
  fi
  return 0
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t open-changed-files-test.XXXXXX)" || fail "mktemp failed"

{
  typeset stub="$tmp_dir/fzf-cli"
  typeset log="$tmp_dir/fzf-cli.log"
  : >| "$log"

  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt pipe_fail nounset'
    print -r -- 'print -r -- "${(j: :)argv}" >>| "${FZF_CLI_STUB_LOG:?}"'
    print -r -- 'print -r -- "stub:${(j: :)argv}"'
  } >| "$stub"
  chmod 755 "$stub"

  typeset output='' rc=0 logged=''

  output="$(OPEN_CHANGED_FILES_FZF_CLI="$stub" FZF_CLI_STUB_LOG="$log" "$ZSH_BIN" -f -- "$TOOL_SCRIPT" --git --dry-run 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "wrapper dispatch should exit 0" || fail "$output"
  assert_eq "stub:open-changed-files --git --dry-run" "$output" "wrapper dispatch stdout" || fail "$output"
  assert_eq "open-changed-files --git --dry-run" "$logged" "wrapper dispatch argv" || fail "$logged"

  output="$(OPEN_CHANGED_FILES_FZF_CLI="$tmp_dir/missing" "$ZSH_BIN" -f -- "$TOOL_SCRIPT" 2>&1)"
  rc=$?
  assert_eq 127 "$rc" "missing override should return 127" || fail "$output"
  assert_contains "$output" "OPEN_CHANGED_FILES_FZF_CLI is not executable:" "missing override should explain" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
