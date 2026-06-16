#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr WRAPPER="$REPO_ROOT/bin/codex-prompt-segment"

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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t codex-prompt-segment-test.XXXXXX)" || fail "mktemp failed"

{
  typeset stub="$tmp_dir/codex-cli"
  typeset log="$tmp_dir/codex-cli.log"
  : >| "$log"

  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt pipe_fail nounset'
    print -r -- 'print -r -- "${(j: :)argv}" >>| "${CODEX_STUB_LOG:?}"'
    print -r -- 'print -r -- "escape=${CODEX_PROMPT_SEGMENT_ZSH_ESCAPE_ENABLED-}" >>| "${CODEX_STUB_LOG:?}"'
    print -r -- 'print -r -- "color=${CODEX_PROMPT_SEGMENT_COLOR_ENABLED-}" >>| "${CODEX_STUB_LOG:?}"'
    print -r -- 'print -r -- "no_color=${NO_COLOR-}" >>| "${CODEX_STUB_LOG:?}"'
    print -r -- 'if [[ "${2-}" != check && "${2-}" != status ]]; then'
    print -r -- '  print -r -- "stub:${(j: :)argv} 5h:99% W:44%%"'
    print -r -- 'else'
    print -r -- '  print -r -- "stub:${(j: :)argv}"'
    print -r -- 'fi'
  } >| "$stub"
  chmod 755 "$stub"

  typeset output='' rc=0 logged=''

  output="$(NO_COLOR= CODEX_PROMPT_SEGMENT_CODEX_CLI="$stub" CODEX_STUB_LOG="$log" "$WRAPPER" --time-format=%Y 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "render dispatch should exit 0" || fail "$output"
  assert_eq "stub:prompt-segment --time-format=%%Y 5h:99%% W:44%%" "$output" "render dispatch stdout" || fail "$output"
  assert_eq $'prompt-segment --time-format=%Y\nescape=true\ncolor=\nno_color=' "$logged" "render dispatch argv/env" || fail "$logged"

  : >| "$log"
  output="$(NO_COLOR= CODEX_PROMPT_SEGMENT_CODEX_CLI="$stub" CODEX_STUB_LOG="$log" "$WRAPPER" --is-enabled 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "--is-enabled dispatch should exit 0" || fail "$output"
  assert_eq "stub:prompt-segment check" "$output" "--is-enabled dispatch stdout" || fail "$output"
  assert_eq $'prompt-segment check\nescape=\ncolor=\nno_color=' "$logged" "--is-enabled should not request render escaping" || fail "$logged"

  : >| "$log"
  output="$(NO_COLOR= CODEX_PROMPT_SEGMENT_CODEX_CLI="$stub" CODEX_STUB_LOG="$log" "$WRAPPER" --status --format json 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "--status dispatch should exit 0" || fail "$output"
  assert_eq "stub:prompt-segment status --format json" "$output" "--status dispatch stdout" || fail "$output"
  assert_eq $'prompt-segment status --format json\nescape=\ncolor=\nno_color=' "$logged" "--status should not request render escaping" || fail "$logged"

  output="$(CODEX_PROMPT_SEGMENT_CODEX_CLI="$tmp_dir/missing" "$WRAPPER" 2>&1)"
  rc=$?
  assert_eq 1 "$rc" "missing override should return 1" || fail "$output"
  assert_eq "" "$output" "missing override should be quiet" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
