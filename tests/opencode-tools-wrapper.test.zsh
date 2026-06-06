#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr OPENCODE_TOOLS_SCRIPT="$REPO_ROOT/scripts/_features/opencode/opencode-tools.zsh"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-opencode-tools-test.XXXXXX)" \
  || fail "mktemp failed"

{
  typeset stub="$tmp_dir/opencode-cli"
  typeset stub_log="$tmp_dir/opencode-cli.log"
  : >| "$stub_log" || fail "failed to create stub log"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt pipe_fail nounset'
    print -r -- 'print -r -- "${(j: :)argv}" >>| "${OPENCODE_TOOLS_STUB_LOG:?}"'
  } >| "$stub" || fail "failed to write opencode-cli stub"
  chmod 755 "$stub" || fail "failed to chmod opencode-cli stub"

  typeset -x OPENCODE_TOOLS_CLI="$stub"
  typeset -x OPENCODE_TOOLS_STUB_LOG="$stub_log"

  [[ -f "$OPENCODE_TOOLS_SCRIPT" ]] || fail "missing script: $OPENCODE_TOOLS_SCRIPT"
  source "$OPENCODE_TOOLS_SCRIPT"

  opencode-tools advice "hello world" || fail "advice wrapper failed"
  opencode-tools knowledge "closures" || fail "knowledge wrapper failed"
  opencode-tools commit-with-scope -p "Prefer terse subject" || fail "commit wrapper failed"
  opencode-tools -- "commit starts raw" || fail "raw -- wrapper failed"
  opencode-tools "raw prompt" || fail "raw fallback wrapper failed"
  opencode-advice direct || fail "direct advice wrapper failed"

  typeset log_text=''
  log_text="$(command cat -- "$stub_log")" || fail "failed to read stub log"

  assert_contains "$log_text" "agent advice hello world" "advice delegation" || fail "$log_text"
  assert_contains "$log_text" "agent knowledge closures" "knowledge delegation" || fail "$log_text"
  assert_contains "$log_text" "agent commit -p Prefer terse subject" "commit delegation" || fail "$log_text"
  assert_contains "$log_text" "agent prompt commit starts raw" "forced raw delegation" || fail "$log_text"
  assert_contains "$log_text" "agent prompt raw prompt" "unknown command raw delegation" || fail "$log_text"
  assert_contains "$log_text" "agent advice direct" "direct advice delegation" || fail "$log_text"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
