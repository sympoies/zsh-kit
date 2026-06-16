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
    print -r -- 'if [[ "${CLAUDE_STUB_LOG_ENV-}" == "1" ]]; then'
    print -r -- '  print -r -- "credentials=${CLAUDE_PROMPT_SEGMENT_CREDENTIALS_JSON-}" >>| "${CLAUDE_STUB_LOG:?}"'
    print -r -- '  print -r -- "color=${CLAUDE_PROMPT_SEGMENT_COLOR_ENABLED-}" >>| "${CLAUDE_STUB_LOG:?}"'
    print -r -- '  print -r -- "no_color=${NO_COLOR-}" >>| "${CLAUDE_STUB_LOG:?}"'
    print -r -- 'fi'
    print -r -- 'if [[ "${CLAUDE_STUB_RENDER_PERCENT-}" == "1" ]]; then'
    print -r -- '  print -r -- "5h:100% W:60% reset"'
    print -r -- 'else'
    print -r -- '  print -r -- "stub:${(j: :)argv}"'
    print -r -- 'fi'
  } >| "$stub"
  chmod 755 "$stub"

  typeset output='' rc=0 logged=''

  output="$(NO_COLOR= CLAUDE_PROMPT_SEGMENT_ENABLED=true CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$stub" CLAUDE_STUB_LOG="$log" "$WRAPPER" --time-format=%Y 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "render dispatch should exit 0" || fail "$output"
  assert_eq "stub:prompt-segment --time-format=%%Y" "$output" "render dispatch stdout" || fail "$output"
  assert_eq "prompt-segment --time-format=%Y" "$logged" "render dispatch argv" || fail "$logged"

  : >| "$log"
  output="$(NO_COLOR= CLAUDE_PROMPT_SEGMENT_ENABLED=true CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$stub" CLAUDE_STUB_LOG="$log" "$WRAPPER" --is-enabled 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "--is-enabled dispatch should exit 0" || fail "$output"
  assert_eq "stub:prompt-segment check" "$output" "--is-enabled dispatch stdout" || fail "$output"
  assert_eq "prompt-segment check" "$logged" "--is-enabled dispatch argv" || fail "$logged"

  : >| "$log"
  output="$(NO_COLOR= CLAUDE_PROMPT_SEGMENT_ENABLED=false CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$stub" CLAUDE_STUB_LOG="$log" "$WRAPPER" --is-enabled 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 1 "$rc" "--is-enabled should fail when disabled" || fail "$output"
  assert_eq "" "$output" "--is-enabled disabled should be quiet" || fail "$output"
  assert_eq "" "$logged" "--is-enabled disabled should not call CLI" || fail "$logged"

  : >| "$log"
  output="$(NO_COLOR= CLAUDE_PROMPT_SEGMENT_ENABLED=false CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$stub" CLAUDE_STUB_LOG="$log" "$WRAPPER" --time-format=%Y 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "render should exit 0 when disabled" || fail "$output"
  assert_eq "" "$output" "render disabled should be quiet" || fail "$output"
  assert_eq "" "$logged" "render disabled should not call CLI" || fail "$logged"

  : >| "$log"
  output="$(NO_COLOR= CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$stub" CLAUDE_STUB_LOG="$log" "$WRAPPER" --status --format json 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "--status dispatch should exit 0" || fail "$output"
  assert_eq "stub:prompt-segment status --format json" "$output" "--status dispatch stdout" || fail "$output"
  assert_eq "prompt-segment status --format json" "$logged" "--status dispatch argv" || fail "$logged"

  typeset home="$tmp_dir/home"
  mkdir -p -- "$home/.claude"
  print -r -- '{"claudeAiOauth":{"accessToken":"token-123"}}' >| "$home/.claude/.credentials.json"

  : >| "$log"
  output="$(
    HOME="$home" \
      NO_COLOR= \
      CLAUDE_PROMPT_SEGMENT_ENABLED=true \
      CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$stub" \
      CLAUDE_STUB_LOG="$log" \
      CLAUDE_STUB_LOG_ENV=1 \
      "$WRAPPER" --is-enabled 2>&1
  )"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "--is-enabled with default credentials should exit 0" || fail "$output"
  [[ "$logged" == *'credentials={"claudeAiOauth":{"accessToken":"token-123"}}'* ]] || fail "default credentials not loaded: $logged"

  : >| "$log"
  output="$(
    HOME="$home" \
      NO_COLOR= \
      CLAUDE_PROMPT_SEGMENT_ENABLED=true \
      CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$stub" \
      CLAUDE_STUB_LOG="$log" \
      CLAUDE_STUB_LOG_ENV=1 \
      CLAUDE_STUB_RENDER_PERCENT=1 \
      "$WRAPPER" --time-format=%Y 2>&1
  )"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "render with default credentials should exit 0" || fail "$output"
  assert_eq "5h:100%% W:60%% reset" "$output" "render should be zsh prompt escaped" || fail "$output"
  [[ "$logged" == *'credentials={"claudeAiOauth":{"accessToken":"token-123"}}'* ]] || fail "default credentials not loaded: $logged"
  [[ "$logged" == *$'\ncolor=\n'* ]] || fail "render should preserve CLI color default: $logged"
  [[ "$logged" == *$'\nno_color=\n'* || "$logged" == *$'\nno_color=' ]] || fail "render should preserve NO_COLOR default: $logged"

  output="$(CLAUDE_PROMPT_SEGMENT_CLAUDE_CLI="$tmp_dir/missing" "$WRAPPER" 2>&1)"
  rc=$?
  assert_eq 1 "$rc" "missing override should return 1" || fail "$output"
  assert_eq "" "$output" "missing override should be quiet" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
