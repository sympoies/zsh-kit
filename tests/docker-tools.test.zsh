#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr FEATURE_SCRIPT="$REPO_ROOT/scripts/_features/docker/docker-tools.zsh"

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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t docker-tools-test.XXXXXX)" || fail "mktemp failed"

{
  typeset stub="$tmp_dir/docker-tools"
  typeset log="$tmp_dir/docker-tools.log"
  : >| "$log"

  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt pipe_fail nounset'
    print -r -- 'print -r -- "${(j: :)argv}" >>| "${DOCKER_TOOLS_STUB_LOG:?}"'
    print -r -- 'print -r -- "stub:${(j: :)argv}"'
  } >| "$stub"
  chmod 755 "$stub"

  typeset output='' rc=0 logged=''

  output="$(ZSH_DOCKER_TOOLS_BIN="$stub" DOCKER_TOOLS_STUB_LOG="$log" zsh -f -c "source '$FEATURE_SCRIPT'; docker-container-sh --root web" 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "docker-container-sh wrapper exits 0" || fail "$output"
  assert_eq "stub:container sh --root web" "$output" "docker-container-sh dispatch stdout" || fail "$output"
  assert_eq "container sh --root web" "$logged" "docker-container-sh dispatch argv" || fail "$logged"

  : >| "$log"
  output="$(ZSH_DOCKER_TOOLS_BIN="$stub" DOCKER_TOOLS_STUB_LOG="$log" zsh -f -c "source '$FEATURE_SCRIPT'; docker-compose-down --all --yes --timeout 5" 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "docker-compose-down wrapper exits 0" || fail "$output"
  assert_eq "stub:compose down --all --yes --timeout 5" "$output" "docker-compose-down dispatch stdout" || fail "$output"
  assert_eq "compose down --all --yes --timeout 5" "$logged" "docker-compose-down dispatch argv" || fail "$logged"

  : >| "$log"
  output="$(ZSH_DOCKER_TOOLS_BIN="$stub" DOCKER_TOOLS_STUB_LOG="$log" zsh -f -c "source '$FEATURE_SCRIPT'; docker-tools run zsh alpine:latest" 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"
  assert_eq 0 "$rc" "docker-tools run wrapper exits 0" || fail "$output"
  assert_eq "stub:run zsh alpine:latest" "$output" "docker-tools run dispatch stdout" || fail "$output"
  assert_eq "run zsh alpine:latest" "$logged" "docker-tools run dispatch argv" || fail "$logged"

  output="$(ZSH_DOCKER_TOOLS_BIN="$tmp_dir/missing" zsh -f -c "source '$FEATURE_SCRIPT'; docker-tools container rm old" 2>&1)"
  rc=$?
  assert_eq 127 "$rc" "missing override exits 127" || fail "$output"
  assert_contains "$output" "ZSH_DOCKER_TOOLS_BIN is not executable:" "missing override explains" || fail "$output"

  output="$(zsh -f -c "source '$FEATURE_SCRIPT'; docker-aliases() { print -r -- alias:\$*; }; docker-tools alias enable omz" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "alias group exits 0" || fail "$output"
  assert_eq "alias:enable omz" "$output" "alias group stays in zsh" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
