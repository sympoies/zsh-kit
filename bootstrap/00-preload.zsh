# safe_unalias [-v] <name...>
# Safely remove one or more aliases without causing errors.
#
# This utility function checks whether each given name is an existing alias,
# and only unaliases it if it exists. This avoids "no such hash table element"
# errors when running scripts that are sourced multiple times or across environments.
#
# It also supports an optional `-v` flag to enable verbose output for debugging.
#
# Usage:
#   safe_unalias foo bar       # Silently unalias 'foo' and 'bar' if they exist
#   safe_unalias -v foo bar    # Verbosely unalias 'foo' and 'bar'
#
# Notes:
# - This function is meant to be defined early in the shell environment,
#   so it can be reused safely in all scripts.
# - It only affects aliases (not functions or commands).
safe_unalias() {
  typeset verbose=false
  typeset first_arg="${1-}"

  if [[ "$first_arg" == "-v" ]]; then
    verbose=true
    shift
  fi

  for name in "$@"; do
    if alias "$name" &>/dev/null; then
      $verbose && printf "🔁 Unaliasing %s\n" "$name"
      unalias "$name"
    fi
  done

  return 0
}

# get_clipboard
# Read clipboard contents and print to stdout.
# Usage: get_clipboard
# Notes:
# - Requires pbpaste (macOS) or xclip/xsel (Linux).
get_clipboard() {
  if command -v pbpaste >/dev/null 2>&1; then
    pbpaste
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --output
  else
    printf "❌ No clipboard tool found (requires pbpaste, xclip, or xsel)\n" >&2
    return 1
  fi
}

# set_clipboard
# Read stdin and write it to the system clipboard.
# Usage: <command> | set_clipboard
# Notes:
# - Requires pbcopy (macOS) or xclip/xsel (Linux).
set_clipboard() {
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -i
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
  else
    printf "❌ No clipboard tool found (requires pbcopy, xclip, or xsel)\n" >&2
    return 1
  fi
}

if [[ -z ${_ZSH_BOOTSTRAP_PRELOAD_PATH+1} ]]; then
  typeset -gr _ZSH_BOOTSTRAP_PRELOAD_PATH="${(%):-%N}"
fi

# ────────────────────────────────────────────────────────
# Env helpers
# ────────────────────────────────────────────────────────

if [[ -z ${_ZSH_ENV_BOOL_INVALID_WARNED+1} ]]; then
  typeset -gA _ZSH_ENV_BOOL_INVALID_WARNED=()
fi

# zsh_env::is_true <value> [name]
# Return 0 when the input value is `true` (case-insensitive).
#
# Rules:
# - Only `true` and `false` are accepted.
# - Empty/unset: treated as false (no warning).
# - Invalid (non-empty, not true/false): warn once to stderr and treat as false.
zsh_env::is_true() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset raw="${1-}"
  [[ -n "$raw" ]] || return 1

  typeset name="${2-}"
  typeset lowered="${raw:l}"
  case "$lowered" in
    true) return 0 ;;
    false) return 1 ;;
    *)
      if [[ -n "$name" && -z "${_ZSH_ENV_BOOL_INVALID_WARNED[$name]-}" ]]; then
        _ZSH_ENV_BOOL_INVALID_WARNED[$name]=1
        print -u2 -r -- "warning: ${name} must be true|false (got: ${raw}); treating as false"
      elif [[ -z "$name" ]]; then
        print -u2 -r -- "warning: invalid boolean value (expected true|false; got: ${raw}); treating as false"
      fi
      return 1
      ;;
  esac
}
