#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr MACOS_SCRIPT="$REPO_ROOT/scripts/macos.zsh"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

# The wrapper prefers the fixed Homebrew locations; on a host that has one of
# them installed this test cannot exercise the PATH fallback.
if [[ -x /opt/homebrew/bin/mactop || -x /usr/local/bin/mactop ]]; then
  print -r -- "SKIP: a Homebrew mactop is installed on this host"
  exit 0
fi

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t macos-mactop-test.XXXXXX)" || fail "mktemp failed"

{
  typeset empty_bin="$tmp_dir/empty-bin"
  typeset stub_bin="$tmp_dir/stub-bin"
  mkdir -p -- "$empty_bin" "$stub_bin" || fail "mkdir failed"

  {
    print -r -- '#!/bin/sh'
    print -r -- 'printf "stub-mactop\n"'
  } >| "$stub_bin/mactop"
  chmod 755 "$stub_bin/mactop"

  run_wrapper() {
    emulate -L zsh
    typeset bin_dir="$1"
    zsh -f -c '
      OSTYPE=darwin24
      source "$1" >/dev/null 2>&1
      PATH="$2:/usr/bin:/bin"
      mactop
    ' run-wrapper "$MACOS_SCRIPT" "$bin_dir" 2>&1
  }

  typeset output=''
  typeset -i rc=0

  output="$(run_wrapper "$empty_bin")" || rc=$?
  (( rc == 127 )) || fail "missing mactop: expected exit 127, got $rc (output: $output)"
  [[ "$output" == *"mactop not found"* ]] || fail "missing mactop: expected not-found message, got: $output"
  [[ "$output" != *"FUNCNEST"* ]] || fail "missing mactop: wrapper recursed into itself"

  rc=0
  output="$(run_wrapper "$stub_bin")" || rc=$?
  (( rc == 0 )) || fail "PATH mactop: expected exit 0, got $rc (output: $output)"
  [[ "$output" == *"stub-mactop"* ]] || fail "PATH mactop: expected stub output, got: $output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
