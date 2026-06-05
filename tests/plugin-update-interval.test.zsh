#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr PRELOAD_SCRIPT="$REPO_ROOT/bootstrap/00-preload.zsh"
typeset -gr FETCHER_SCRIPT="$REPO_ROOT/bootstrap/plugin_fetcher.zsh"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-plugin-interval-test.XXXXXX)" || fail "mktemp failed"

typeset cache_dir="$tmp_dir/cache"
mkdir -p -- "$cache_dir" || fail "failed to create cache dir"

# Export ZSH_PLUGINS_DIR so the fetcher's `${ZSH_PLUGINS_DIR:-$ZDOTDIR/plugins}`
# never dereferences $ZDOTDIR, which is unset in a clean CI environment under nounset.
typeset -x ZSH_PLUGINS_DIR="$tmp_dir/plugins"
typeset -x ZSH_CACHE_DIR="$cache_dir"

[[ -f "$PRELOAD_SCRIPT" ]] || fail "missing preload script: $PRELOAD_SCRIPT"
source "$PRELOAD_SCRIPT"

[[ -f "$FETCHER_SCRIPT" ]] || fail "missing fetcher script: $FETCHER_SCRIPT"
source "$FETCHER_SCRIPT"

# The auto-update fires at PLUGIN_UPDATE_INTERVAL_DAYS (default 7). The status
# countdown must derive its "days left" from the SAME interval, not a divergent
# hard-coded value.
(( PLUGIN_UPDATE_INTERVAL_DAYS == 7 )) || fail "expected default interval of 7 days, got: ${PLUGIN_UPDATE_INTERVAL_DAYS-<unset>}"

typeset -i now=0
now=$(date +%s)
# Seed "last updated" 2.5 days ago → 2 whole days elapsed, so a 7-day interval
# leaves exactly 5 days remaining.
print -r -- "$(( now - (2 * 86400 + 43200) ))" >| "$PLUGIN_UPDATE_FILE" \
  || fail "failed to seed timestamp"

typeset status_out=''
status_out="$(plugin_print_status)" || fail "plugin_print_status returned non-zero"

[[ "$status_out" == *"(2 days ago)"* ]] \
  || fail "expected '2 days ago' in status output, got: $status_out"
[[ "$status_out" == *"expected in: 5 days"* ]] \
  || fail "expected 7-day-interval countdown ('5 days'), got: $status_out"

print -r -- "ok"
