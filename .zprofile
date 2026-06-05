# ──────────────────────────────
# Homebrew environment setup (login shell only)
# ──────────────────────────────

# Notes:
# - `.zprofile` is only loaded for login shells (`zsh -l`).
# - Keep this file silent and minimal (no prompts / no UI / no network).
# - `brew shellenv` configures more than just `PATH` (e.g. `MANPATH`), which is why it lives here.
# - This repo also prepends `/opt/homebrew/bin` (and GNU "gnubin" shims) via
#   `scripts/_internal/paths.exports.zsh` so non-login shells can still find `brew`.
#   See `docs/guides/startup-files.md`.
# - Brew discovery + env application is shared with the installers via
#   `scripts/_internal/homebrew.zsh` (sourced below).

typeset _zsh_brew_helper="${ZDOTDIR:-$HOME/.config/zsh}/scripts/_internal/homebrew.zsh"
[[ -r "$_zsh_brew_helper" ]] && source "$_zsh_brew_helper"
unset _zsh_brew_helper

if (( ${+functions[zsh_brew::discover]} && ${+functions[zsh_brew::apply_env]} )); then
  typeset homebrew_path=''
  homebrew_path="$(zsh_brew::discover || true)"
  if [[ -n "$homebrew_path" ]]; then
    zsh_brew::apply_env "$homebrew_path"
    export HOMEBREW_AUTO_UPDATE_SECS=604800 # 7 days
  fi
  unset homebrew_path
fi
