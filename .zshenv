# ──────────────────────────────
# Zsh environment (always loaded)
# ──────────────────────────────

# Why this exists even if `.zshrc`/`.zprofile` also define paths:
# - `.zshenv` is loaded for non-interactive shells (e.g. `zsh -c ...`) where `.zshrc`/`.zprofile`
#   may not run. Keeping core `ZSH_*` exports here makes paths available everywhere.
# - Keep this file minimal + silent (exports only). Any init work belongs in `paths.init.zsh`.
#
# Note on `ZDOTDIR`:
# - Zsh chooses which `.zshenv` to load *before* it executes any user code, so setting `ZDOTDIR`
#   inside `~/.zshenv` won’t automatically make Zsh load `$ZDOTDIR/.zshenv`.
# - The recommended setup is: keep a tiny `~/.zshenv` that exports `ZDOTDIR="$HOME/.config/zsh"`
#   and then explicitly sources `$ZDOTDIR/.zshenv`. See `docs/guides/startup-files.md`.

[[ -r "${ZDOTDIR:-$HOME/.config/zsh}/scripts/_internal/paths.exports.zsh" ]] && \
  source "${ZDOTDIR:-$HOME/.config/zsh}/scripts/_internal/paths.exports.zsh"

# >>> codex forge-cli inbox private env >>>
# Machine-local defaults for forge-cli inbox GitLab readiness.
# FORGE_CLI_BIN intentionally not defaulted: let PATH resolve forge-cli
# (brew install) so plan-issue dispatch tracks brew upgrades.
export FORGE_CLI_INBOX_GITLAB_HOST="${FORGE_CLI_INBOX_GITLAB_HOST:-gitlab.gamania.com}"
export FORGE_CLI_INBOX_GITLAB_VPN="${FORGE_CLI_INBOX_GITLAB_VPN:-required}"
export FORGE_CLI_INBOX_GITLAB_VPN_CHECK="${FORGE_CLI_INBOX_GITLAB_VPN_CHECK:-tcp:${FORGE_CLI_INBOX_GITLAB_HOST:-gitlab.gamania.com}:443}"
export FORGE_CLI_INBOX_GITLAB_VPN_CHECK_TIMEOUT="${FORGE_CLI_INBOX_GITLAB_VPN_CHECK_TIMEOUT:-5s}"
export FORGE_CLI_INBOX_PROVIDER_TIMEOUT="${FORGE_CLI_INBOX_PROVIDER_TIMEOUT:-20s}"
export FORGE_CLI_INBOX_CACHE_FALLBACK="${FORGE_CLI_INBOX_CACHE_FALLBACK:-true}"
export FORGE_CLI_INBOX_CACHE_MAX_AGE="${FORGE_CLI_INBOX_CACHE_MAX_AGE:-30m}"
if [ -z "${FORGE_CLI_INBOX_GITLAB_OPENVPN_PROFILE:-}" ]; then
  export FORGE_CLI_INBOX_GITLAB_OPENVPN_PROFILE="$HOME/Documents/$(printf '\164\145\162\162\171\154\151\156\100\147\141\155\141\156\151\141\056\143\157\155\056\157\166\160\156')"
fi
# <<< codex forge-cli inbox private env <<<

# nils-cli agent-out 寫 artifacts 的根
export AGENT_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/agent-runtime-kit"

# agent-docs catalog root (active agent-runtime-kit checkout)
export AGENT_DOCS_HOME="$HOME/Project/graysurf/agent-runtime-kit"

# ──────────────────────────────
# Codex CLI
# ──────────────────────────────
export CODEX_HOME="$HOME/.codex"
export CODEX_AUTH_FILE="$HOME/.codex/auth.json"
export CODEX_SECRET_DIR="$HOME/.config/codex_secrets"
export CODEX_CLI_EPHEMERAL_ENABLED=true
export CODEX_PROMPT_SEGMENT_TTL=1m
export CODEX_RATE_LIMITS_CACHE_TTL=1m

# ──────────────────────────────
# nils-cli wrapper (debug vs installed mode)
# ──────────────────────────────
export NILS_WRAPPER_MODE=debug      # auto|debug|installed
export NILS_WRAPPER_INSTALL_PREFIX="$HOME/.local/nils-cli"

# ──────────────────────────────
# google-cli credential store
# ──────────────────────────────
export GOOGLE_CLI_CONFIG_DIR="$HOME/.config/google/credentials"

# ──────────────────────────────
# Misc machine markers
# ──────────────────────────────
export MAIN_SERVER=true
