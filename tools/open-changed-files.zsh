#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

# resolve_fzf_cli
# Resolve the nils-cli `fzf-cli` binary for the compatibility wrapper.
# Usage: resolve_fzf_cli
# Notes:
# - `OPEN_CHANGED_FILES_FZF_CLI` can point tests or local smoke checks at a specific binary.
# - The local nils-cli development install is preferred before PATH to avoid stale shell sessions.
resolve_fzf_cli() {
  emulate -L zsh
  setopt pipe_fail nounset

  if [[ -n "${OPEN_CHANGED_FILES_FZF_CLI-}" ]]; then
    if [[ ! -x "$OPEN_CHANGED_FILES_FZF_CLI" ]]; then
      print -u2 -r -- "❌ OPEN_CHANGED_FILES_FZF_CLI is not executable: $OPEN_CHANGED_FILES_FZF_CLI"
      return 1
    fi
    print -r -- "$OPEN_CHANGED_FILES_FZF_CLI"
    return 0
  fi

  typeset local_bin="$HOME/.local/nils-cli/bin/fzf-cli"
  if [[ -x "$local_bin" ]]; then
    print -r -- "$local_bin"
    return 0
  fi

  command -v fzf-cli 2>/dev/null
}

fzf_cli="$(resolve_fzf_cli)" || {
  print -u2 -r -- "❌ fzf-cli not found; install nils-cli or set OPEN_CHANGED_FILES_FZF_CLI."
  exit 127
}

exec "$fzf_cli" open-changed-files "$@"
