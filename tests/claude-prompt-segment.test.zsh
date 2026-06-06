#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr WRAPPER="$REPO_ROOT/bin/claude-prompt-segment"

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

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t claude-prompt-segment-test.XXXXXX)" || fail "mktemp failed"

{
  typeset stub="$tmp_dir/claude-cli"
  typeset log="$tmp_dir/claude-cli.log"
  : >| "$log"

  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt pipe_fail nounset'
    print -r -- 'print -r -- "${(j: :)argv}" >>| "${CLAUDE_STUB_LOG:?}"'
    print -r -- 'print -r -- "stub:${(j: :)argv}"'
  } >| "$stub"
  chmod 755 "$stub"

  typeset output='' rc=0 logged=''

  output="$(CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$stub" CLAUDE_STUB_LOG="$log" "$WRAPPER" --time-format=%Y 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "render dispatch should exit 0" || fail "$output"
  assert_eq "stub:prompt-segment --time-format=%Y" "$output" "render dispatch stdout" || fail "$output"
  assert_eq "prompt-segment --time-format=%Y" "$logged" "render dispatch argv" || fail "$logged"

  : >| "$log"
  output="$(CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$stub" CLAUDE_STUB_LOG="$log" "$WRAPPER" --is-enabled 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "--is-enabled dispatch should exit 0" || fail "$output"
  assert_eq "stub:prompt-segment check" "$output" "--is-enabled dispatch stdout" || fail "$output"
  assert_eq "prompt-segment check" "$logged" "--is-enabled dispatch argv" || fail "$logged"

  : >| "$log"
  output="$(CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$stub" CLAUDE_STUB_LOG="$log" "$WRAPPER" --status --format json 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "--status dispatch should exit 0" || fail "$output"
  assert_eq "stub:prompt-segment status --format json" "$output" "--status dispatch stdout" || fail "$output"
  assert_eq "prompt-segment status --format json" "$logged" "--status dispatch argv" || fail "$logged"

  output="$(CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$tmp_dir/missing" "$WRAPPER" 2>&1)"
  rc=$?
  assert_eq 1 "$rc" "missing override should return 1" || fail "$output"
  assert_eq "" "$output" "missing override should be quiet" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
