#!/usr/bin/env -S zsh -f

# Only define once
typeset -f plugin_fetch_if_missing_from_entry >/dev/null && return

# plugin_fetcher.zsh – fetch/update Zsh plugins

ZSH_PLUGINS_DIR="${ZSH_PLUGINS_DIR:-$ZDOTDIR/plugins}"
PLUGIN_FETCH_DRY_RUN_ENABLED="${PLUGIN_FETCH_DRY_RUN_ENABLED-false}"
PLUGIN_FETCH_FORCE_ENABLED="${PLUGIN_FETCH_FORCE_ENABLED-false}"
PLUGIN_UPDATE_FILE="$ZSH_CACHE_DIR/plugin.timestamp"
# Single source of truth for the auto-update cadence. Both the trigger
# (plugin_maybe_auto_update) and the status countdown (plugin_print_status)
# derive from this value so they can never drift apart.
typeset -gi PLUGIN_UPDATE_INTERVAL_DAYS="${PLUGIN_UPDATE_INTERVAL_DAYS:-7}"

# _zsh_plugin_cli
# Resolve the native nils-cli zsh-kit binary used for plugin helpers.
# Usage: _zsh_plugin_cli
# Env:
# - ZSH_KIT_PLUGIN_CLI: executable override for tests or local development.
_zsh_plugin_cli() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset override="${ZSH_KIT_PLUGIN_CLI-}"
  if [[ -n "$override" ]]; then
    if [[ ! -x "$override" ]]; then
      print -u2 -r -- "plugin_fetcher: ZSH_KIT_PLUGIN_CLI is not executable: $override"
      return 127
    fi
    print -r -- "$override"
    return 0
  fi

  typeset candidate="$HOME/.local/nils-cli/bin/zsh-kit"
  if [[ -x "$candidate" ]]; then
    print -r -- "$candidate"
    return 0
  fi

  candidate="$(whence -p zsh-kit 2>/dev/null || true)"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    print -r -- "$candidate"
    return 0
  fi

  print -u2 -r -- "plugin_fetcher: zsh-kit binary not found (install nils-cli or set ZSH_KIT_PLUGIN_CLI)"
  return 127
}

# _zsh_plugin_cli_exec [args...]
# Execute the resolved nils-cli zsh-kit binary.
# Usage: _zsh_plugin_cli_exec [args...]
_zsh_plugin_cli_exec() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset bin=''
  bin="$(_zsh_plugin_cli)" || return $?
  command -- "$bin" "$@"
}

# _zsh_plugin_is_true <value> <name>
# Test a plugin boolean env value.
# Usage: _zsh_plugin_is_true <value> <name>
_zsh_plugin_is_true() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset value="${1-}"
  typeset name="${2-boolean}"

  if (( $+functions[zsh_env::is_true] )); then
    zsh_env::is_true "$value" "$name"
    return $?
  fi

  case "${value:l}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

# plugin_fetch_if_missing_from_entry <entry>
# Ensure the plugin referenced by a `config/plugins.list` entry exists under $ZSH_PLUGINS_DIR.
# Usage: plugin_fetch_if_missing_from_entry <entry>
# Env:
# - ZSH_PLUGINS_DIR: plugin base directory (default: $ZDOTDIR/plugins)
# - PLUGIN_FETCH_DRY_RUN_ENABLED: when true, do not modify filesystem (default: false)
# - PLUGIN_FETCH_FORCE_ENABLED: when true, delete and re-clone existing plugin dirs (default: false)
# Safety:
# - When PLUGIN_FETCH_FORCE_ENABLED=true and PLUGIN_FETCH_DRY_RUN_ENABLED=false, this removes the plugin directory.
plugin_fetch_if_missing_from_entry() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset entry="${1-}"
  typeset -a args=(plugin fetch --entry "$entry" --plugins-dir "$ZSH_PLUGINS_DIR")

  if _zsh_plugin_is_true "${PLUGIN_FETCH_FORCE_ENABLED-}" "PLUGIN_FETCH_FORCE_ENABLED"; then
    args+=(--force)
  fi
  if _zsh_plugin_is_true "${PLUGIN_FETCH_DRY_RUN_ENABLED-}" "PLUGIN_FETCH_DRY_RUN_ENABLED"; then
    args+=(--dry-run)
  fi

  _zsh_plugin_cli_exec "${args[@]}"
}

# plugin_update_all
# Update all git plugin repos under $ZSH_PLUGINS_DIR (fast-forward only).
# Usage: plugin_update_all
# Env:
# - ZSH_PLUGINS_DIR: plugin base directory (default: $ZDOTDIR/plugins)
# - PLUGIN_FETCH_DRY_RUN_ENABLED: when true, do not modify repos; print intended commands (default: false)
plugin_update_all() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -a args=(plugin update --plugins-dir "$ZSH_PLUGINS_DIR")
  if _zsh_plugin_is_true "${PLUGIN_FETCH_DRY_RUN_ENABLED-}" "PLUGIN_FETCH_DRY_RUN_ENABLED"; then
    args+=(--dry-run)
  fi

  _zsh_plugin_cli_exec "${args[@]}"
}

# plugin_maybe_auto_update
# Auto-update plugins based on the timestamp in $PLUGIN_UPDATE_FILE.
# Usage: plugin_maybe_auto_update
# Notes:
# - Delegates cadence checks, update, and timestamp writes to `zsh-kit plugin maybe-update`.
# - Threshold: $PLUGIN_UPDATE_INTERVAL_DAYS (default 7 days).
plugin_maybe_auto_update() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -a args=(
    plugin maybe-update
    --plugins-dir "$ZSH_PLUGINS_DIR"
    --timestamp-file "$PLUGIN_UPDATE_FILE"
    --interval-days "$PLUGIN_UPDATE_INTERVAL_DAYS"
  )
  if _zsh_plugin_is_true "${PLUGIN_FETCH_DRY_RUN_ENABLED-}" "PLUGIN_FETCH_DRY_RUN_ENABLED"; then
    args+=(--dry-run)
  fi

  _zsh_plugin_cli_exec "${args[@]}"
}

# plugin_print_status
# Print plugin auto-update status based on $PLUGIN_UPDATE_FILE.
# Usage: plugin_print_status
plugin_print_status() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _zsh_plugin_cli_exec \
    plugin status \
    --timestamp-file "$PLUGIN_UPDATE_FILE" \
    --interval-days "$PLUGIN_UPDATE_INTERVAL_DAYS"
}
