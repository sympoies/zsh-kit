# nils-cli aliases
#
# Source Homebrew's nils-cli alias bundle when available.
# Keep this interactive-only because aliases are shell UX, not runtime deps.
#
# Forking `brew --prefix nils-cli` on every shell startup is slow. The Homebrew
# `opt/<formula>` symlink path is stable, so probe the standard prefixes first
# and only fall back to `brew` when neither has the bundle.
[[ -o interactive ]] || return 0

typeset nils_cli_aliases=''
typeset nils_cli_rel='share/zsh/site-functions/aliases.zsh'

typeset nils_cli_opt=''
for nils_cli_opt in /opt/homebrew/opt/nils-cli /usr/local/opt/nils-cli; do
  if [[ -f "$nils_cli_opt/$nils_cli_rel" ]]; then
    nils_cli_aliases="$nils_cli_opt/$nils_cli_rel"
    break
  fi
done

if [[ -z "$nils_cli_aliases" ]] && command -v brew >/dev/null 2>&1; then
  typeset nils_cli_prefix=''
  nils_cli_prefix="$(brew --prefix nils-cli 2>/dev/null || true)"
  if [[ -n "$nils_cli_prefix" && -f "$nils_cli_prefix/$nils_cli_rel" ]]; then
    nils_cli_aliases="$nils_cli_prefix/$nils_cli_rel"
  fi
fi

if [[ -f "$nils_cli_aliases" ]]; then
  source "$nils_cli_aliases"
fi
