#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr FETCHER_SCRIPT="$REPO_ROOT/bootstrap/plugin_fetcher.zsh"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-plugin-missing-cli-test.XXXXXX)" || fail "mktemp failed"

{
  typeset -x HOME="$tmp_dir/home"
  typeset -x PATH="/usr/bin:/bin"
  typeset -x ZDOTDIR="$tmp_dir/zdotdir"
  typeset -x ZSH_CACHE_DIR="$tmp_dir/cache"
  typeset -x ZSH_PLUGINS_DIR="$tmp_dir/plugins"
  typeset -x PLUGIN_FETCH_DRY_RUN_ENABLED=true

  mkdir -p -- "$HOME" "$ZDOTDIR" "$ZSH_CACHE_DIR" "$ZSH_PLUGINS_DIR" \
    || fail "failed to create temp dirs"

  [[ -f "$FETCHER_SCRIPT" ]] || fail "missing fetcher script: $FETCHER_SCRIPT"
  source "$FETCHER_SCRIPT"

  typeset output='' rc=0

  output="$(plugin_fetch_if_missing_from_entry "zsh-autosuggestions::zsh-autosuggestions.zsh::git=https://example.com/zsh-autosuggestions.git" 2>&1)"
  rc=$?
  (( rc == 127 )) || fail "expected missing CLI dry-run fetch to return 127, got $rc: $output"
  [[ -z "$output" ]] || fail "expected missing CLI dry-run fetch to stay quiet, got: $output"

  output="$(plugin_maybe_auto_update 2>&1)"
  rc=$?
  (( rc == 127 )) || fail "expected missing CLI dry-run maybe-update to return 127, got $rc: $output"
  [[ -z "$output" ]] || fail "expected missing CLI dry-run maybe-update to stay quiet, got: $output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
