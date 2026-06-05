# ──────────────────────────────
# Setup completion functions first
# ──────────────────────────────
if [[ ! -o interactive || ! -t 0 ]]; then
  return 0
fi

# compinit-reset [dump_file]
# Reset zsh completion by removing the compdump and rerunning `compinit`.
# Usage: compinit-reset [path/to/.zcompdump]
# Env:
# - ZSH_COMPDUMP: Default dump file path.
# - ZSH_CACHE_DIR: Fallback dir when ZSH_COMPDUMP is unset (uses `$ZSH_CACHE_DIR/.zcompdump`).
# Notes:
# - Removes the dump file and rebuilds it; the next completion may be slower.
compinit-reset() {
  emulate -L zsh
  setopt err_return pipe_fail nounset

  typeset dump_file="${1-${ZSH_COMPDUMP-}}"
  if [[ -z "$dump_file" ]]; then
    typeset cache_dir="${ZSH_CACHE_DIR:-${ZDOTDIR-}/cache}"
    [[ -n "$cache_dir" ]] && dump_file="$cache_dir/.zcompdump"
  fi

  if [[ -z "$dump_file" ]]; then
    print -u2 -r -- "compinit-reset: missing dump file path (set ZSH_COMPDUMP)"
    return 2
  fi

  typeset dump_dir="${dump_file:h}"
  [[ -d "$dump_dir" ]] || mkdir -p -- "$dump_dir"

  command rm -f -- "$dump_file" "${dump_file}.zwc"
  autoload -Uz compinit
  compinit -i -d "$dump_file"
}

# rz [dump_file]
# Shorthand for `compinit-reset`.
# Usage: rz [path/to/.zcompdump]
rz() {
  compinit-reset "$@"
}

fpath=("$ZDOTDIR/scripts/_completion" $fpath)
autoload -Uz compinit
compinit -i -d "$ZSH_COMPDUMP"

# zoxide registers its completion via `compdef`, but it may be initialized
# before `compinit` (and thus miss the `compdef` call). Re-register here.
if (( $+functions[__zoxide_z_complete] )); then
  compdef __zoxide_z_complete z
fi
typeset -g ZSH_COMPLETION_CACHE_DIR="${ZSH_COMPLETION_CACHE_DIR:-$ZSH_CACHE_DIR/completion-cache}"
[[ -d "$ZSH_COMPLETION_CACHE_DIR" ]] || mkdir -p -- "$ZSH_COMPLETION_CACHE_DIR"

# ──────────────────────────────────────
# fzf-tab configuration (after compinit)
# ──────────────────────────────────────
setopt extendedglob
# Surface dotfiles in completion without enabling `globdots` session-wide
# (which would silently make `rm *` / `cp *` / `ls *` match dotfiles too).
# `_comp_options` is applied by the completion system only while completing.
_comp_options+=(globdots)
# avoid auto-inserting common prefix before menu
unsetopt AUTO_MENU MENU_COMPLETE
# Use modern menu selection
zstyle ':completion:*' menu yes select
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)${LS_COLORS-}}
# Keep input as typed; don't auto-insert longest common prefix before showing menu
zstyle ':completion:*' insert-unambiguous false
# Enable fuzzy matching: case-insensitive; keep '-' significant so camelCase vs kebab-case don't collapse
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._]=* r:|=*'

# Enable fzf-tab with styled preview menu
zstyle ':fzf-tab:*' prefix ''
zstyle ':fzf-tab:*' fzf-command fzf
zstyle ':fzf-tab:*' fzf-flags  --height=60% --layout=reverse --prompt='⮕ '
zstyle ':fzf-tab:*' query-string input  # keep fzf query/prompt in the original typed case
zstyle ':fzf-tab:*' ignore-case smart
# do not pre-insert common prefix; open menu immediately
zstyle ':fzf-tab:*' skip-unambiguous yes

zmodload zsh/complist

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_COMPLETION_CACHE_DIR"

