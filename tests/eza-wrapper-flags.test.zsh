#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr EZA_SCRIPT="$REPO_ROOT/scripts/eza.zsh"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

# Source the wrappers, then stub `eza` to echo the exact argv each wrapper composes.
source "$EZA_SCRIPT" || fail "sourcing eza.zsh failed"
eza() { print -r -- "${(j: :)@}" }

typeset out=''

# Plain long listing carries the shared base flags and the path passthrough.
out="$(ll somedir)" || fail "ll returned non-zero"
[[ "$out" == *"-alh"* ]]                       || fail "ll: missing -alh ($out)"
[[ "$out" == *"--icons"* ]]                    || fail "ll: missing --icons ($out)"
[[ "$out" == *"--group-directories-first"* ]]  || fail "ll: missing --group-directories-first ($out)"
[[ "$out" == *"--time-style=iso"* ]]           || fail "ll: missing --time-style=iso ($out)"
[[ "$out" == *"somedir"* ]]                    || fail "ll: missing path passthrough ($out)"
[[ "$out" != *"--git"* ]]                      || fail "ll: should not enable --git ($out)"

# Git-aware wrapper adds the shared git flags on top of the base.
out="$(lg somedir)" || fail "lg returned non-zero"
[[ "$out" == *"--git"* && "$out" == *"--color=always"* ]] || fail "lg: missing git flags ($out)"
[[ "$out" == *"--time-style=iso"* ]]           || fail "lg: missing shared base ($out)"

# Standardization: the tree view now also carries the shared base (incl. --time-style).
out="$(lt)" || fail "lt returned non-zero"
[[ "$out" == *"-aT"* ]]                        || fail "lt: missing -aT ($out)"
[[ "$out" == *"--time-style=iso"* ]]           || fail "lt: expected shared base --time-style=iso ($out)"

# The optional-depth helper turns a bare leading number into -L <n>.
out="$(ll 2)" || fail "ll 2 returned non-zero"
[[ "$out" == *"-L 2"* ]]                       || fail "ll 2: expected depth -L 2 ($out)"

print -r -- "ok"
