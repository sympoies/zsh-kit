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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-plugin-fetcher-test.XXXXXX)" || fail "mktemp failed"

typeset plugins_dir="$tmp_dir/plugins"
mkdir -p -- "$plugins_dir" || fail "failed to create plugins dir"
print -r -- "sentinel" >| "$plugins_dir/keep.txt" || fail "failed to write sentinel"

typeset cache_dir="$tmp_dir/cache"
mkdir -p -- "$cache_dir" || fail "failed to create cache dir"

typeset stub="$tmp_dir/zsh-kit"
typeset stub_log="$tmp_dir/zsh-kit.log"
: >| "$stub_log" || fail "failed to create stub log"
{
  print -r -- '#!/usr/bin/env -S zsh -f'
  print -r -- 'setopt pipe_fail nounset'
  print -r -- 'print -r -- "${(j: :)argv}" >>| "${ZSH_KIT_PLUGIN_STUB_LOG:?}"'
  print -r -- 'exit 65'
} >| "$stub" || fail "failed to write zsh-kit stub"
chmod 755 "$stub" || fail "failed to chmod zsh-kit stub"

typeset -x ZSH_PLUGINS_DIR="$plugins_dir"
typeset -x ZSH_CACHE_DIR="$cache_dir"
typeset -x PLUGIN_FETCH_FORCE_ENABLED=true
typeset -x PLUGIN_FETCH_DRY_RUN_ENABLED=false
typeset -x ZSH_KIT_PLUGIN_CLI="$stub"
typeset -x ZSH_KIT_PLUGIN_STUB_LOG="$stub_log"

[[ -f "$PRELOAD_SCRIPT" ]] || fail "missing preload script: $PRELOAD_SCRIPT"
source "$PRELOAD_SCRIPT"

[[ -f "$FETCHER_SCRIPT" ]] || fail "missing fetcher script: $FETCHER_SCRIPT"
source "$FETCHER_SCRIPT"

plugin_fetch_if_missing_from_entry "::git=https://example.com/repo.git" && fail "expected invalid entry to fail"
[[ -d "$plugins_dir" ]] || fail "plugins dir should remain after invalid entry"
[[ -f "$plugins_dir/keep.txt" ]] || fail "sentinel should remain after invalid entry"

plugin_fetch_if_missing_from_entry "   " && fail "expected whitespace entry to fail"
[[ -d "$plugins_dir" ]] || fail "plugins dir should remain after whitespace entry"
[[ -f "$plugins_dir/keep.txt" ]] || fail "sentinel should remain after whitespace entry"

typeset traversal_dir="$tmp_dir/evil"
mkdir -p -- "$traversal_dir" || fail "failed to create traversal dir"
print -r -- "evil-sentinel" >| "$traversal_dir/keep.txt" || fail "failed to write traversal sentinel"

plugin_fetch_if_missing_from_entry "../evil" && fail "expected traversal entry to fail"
[[ -d "$plugins_dir" ]] || fail "plugins dir should remain after traversal entry"
[[ -f "$plugins_dir/keep.txt" ]] || fail "sentinel should remain after traversal entry"
[[ -d "$traversal_dir" ]] || fail "traversal dir should remain after traversal entry"
[[ -f "$traversal_dir/keep.txt" ]] || fail "traversal sentinel should remain after traversal entry"

typeset log_text=''
log_text="$(command cat -- "$stub_log")" || fail "failed to read stub log"
[[ "$log_text" == *"plugin fetch --entry ../evil --plugins-dir $plugins_dir --force"* ]] \
  || fail "expected traversal entry to be delegated with --force, got: $log_text"
