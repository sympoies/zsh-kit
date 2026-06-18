#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr OVERRIDES_SCRIPT="$REPO_ROOT/scripts/builtin-overrides.zsh"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

# Source the wrappers; this also defines the `ls` override under test.
source "$OVERRIDES_SCRIPT" || fail "sourcing builtin-overrides.zsh failed"

(( $+functions[ls] )) || fail "ls wrapper not defined after sourcing"

# This test process is non-interactive (`zsh -f`), so the wrapper must delegate
# to the real `ls` and produce byte-identical output — never the eza grid. This
# guards the script / pipeline safety contract regardless of whether eza is
# installed on the host running the suite.
typeset got='' want=''
got="$(ls "$REPO_ROOT")"          || fail "ls wrapper returned non-zero"
want="$(command ls "$REPO_ROOT")" || fail "command ls returned non-zero"
[[ "$got" == "$want" ]] || fail "non-interactive ls must match real ls (got=[$got] want=[$want])"

# eza must not be on the resolved path for a non-interactive `ls`: a stub that
# would corrupt output if invoked proves the guard short-circuits first.
eza() { print -r -- "EZA-WAS-CALLED"; }
got="$(ls "$REPO_ROOT")" || fail "ls wrapper returned non-zero with eza stub present"
[[ "$got" != *"EZA-WAS-CALLED"* ]] || fail "non-interactive ls must not invoke eza"

print -r -- "ok"
