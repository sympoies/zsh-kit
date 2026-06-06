#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr SHELL_TOOLS_SCRIPT="$REPO_ROOT/scripts/shell-tools.zsh"

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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t kill-wrappers-test.XXXXXX)" || fail "mktemp failed"

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

  output="$(ZSH_SHELL_TOOLS_FZF_CLI="$stub" FZF_CLI_STUB_LOG="$log" zsh -f -c "source '$SHELL_TOOLS_SCRIPT'; kill-port -9 1234" 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "kill-port wrapper exits 0" || fail "$output"
  assert_eq "stub:kill-port -9 1234" "$output" "kill-port dispatch stdout" || fail "$output"
  assert_eq "kill-port -9 1234" "$logged" "kill-port dispatch argv" || fail "$logged"

  : >| "$log"
  output="$(ZSH_SHELL_TOOLS_FZF_CLI="$stub" FZF_CLI_STUB_LOG="$log" zsh -f -c "source '$SHELL_TOOLS_SCRIPT'; kill-process 123 456" 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "kill-process wrapper exits 0" || fail "$output"
  assert_eq "stub:kill-process 123 456" "$output" "kill-process dispatch stdout" || fail "$output"
  assert_eq "kill-process 123 456" "$logged" "kill-process dispatch argv" || fail "$logged"

  output="$(ZSH_SHELL_TOOLS_FZF_CLI="$tmp_dir/missing" zsh -f -c "source '$SHELL_TOOLS_SCRIPT'; kill-port 1234" 2>&1)"
  rc=$?
  assert_eq 127 "$rc" "missing override exits 127" || fail "$output"
  assert_contains "$output" "ZSH_SHELL_TOOLS_FZF_CLI is not executable:" "missing override explains" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
