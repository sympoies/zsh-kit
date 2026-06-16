# ──────────────────────────────
# Define Zsh environment paths (exports only)
# ──────────────────────────────
(( ${+_ZSH_INTERNAL_PATHS_EXPORTS_SOURCED} )) && return 0
typeset -g _ZSH_INTERNAL_PATHS_EXPORTS_SOURCED=1

export ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"

export ZSH_CONFIG_DIR="${ZSH_CONFIG_DIR:-$ZDOTDIR/config}"
export ZSH_BOOTSTRAP_SCRIPT_DIR="${ZSH_BOOTSTRAP_SCRIPT_DIR:-$ZDOTDIR/bootstrap}"
export ZSH_SCRIPT_DIR="${ZSH_SCRIPT_DIR:-$ZDOTDIR/scripts}"
export ZSH_BIN_DIR="${ZSH_BIN_DIR:-$ZDOTDIR/bin}"
export ZSH_TOOLS_DIR="${ZSH_TOOLS_DIR:-$ZDOTDIR/tools}"
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$ZDOTDIR/cache}"
export ZSH_COMPDUMP="${ZSH_COMPDUMP:-$ZSH_CACHE_DIR/.zcompdump}"
export HISTFILE="$ZSH_CACHE_DIR/.zsh_history"

# Codex helper defaults. These are non-secret paths/flags; actual token
# material remains in the referenced auth/secret files.
export CODEX_AUTH_FILE="${CODEX_AUTH_FILE:-$HOME/.codex/auth.json}"
export CODEX_SECRET_DIR="${CODEX_SECRET_DIR:-$HOME/.config/codex_secrets}"
export CODEX_PROMPT_SEGMENT_ENABLED="${CODEX_PROMPT_SEGMENT_ENABLED:-true}"

# ──────────────────────────────
# PATH
# ──────────────────────────────
# Use unique path entries (prevents duplicates)
typeset -U path=($path) PATH="${PATH-}"

# Prepend critical paths to PATH
typeset -a _zsh_path_prepend=()

# GNU tools (Homebrew "gnubin" shims)
[[ -d /opt/homebrew/opt/coreutils/libexec/gnubin ]] && _zsh_path_prepend+=(/opt/homebrew/opt/coreutils/libexec/gnubin)
[[ -d /opt/homebrew/opt/grep/libexec/gnubin ]] && _zsh_path_prepend+=(/opt/homebrew/opt/grep/libexec/gnubin)
[[ -d /usr/local/opt/coreutils/libexec/gnubin ]] && _zsh_path_prepend+=(/usr/local/opt/coreutils/libexec/gnubin)
[[ -d /usr/local/opt/grep/libexec/gnubin ]] && _zsh_path_prepend+=(/usr/local/opt/grep/libexec/gnubin)

# Database clients (keg-only Homebrew packages)
[[ -d /opt/homebrew/opt/libpq/bin ]] && _zsh_path_prepend+=(/opt/homebrew/opt/libpq/bin)
[[ -d /usr/local/opt/libpq/bin ]] && _zsh_path_prepend+=(/usr/local/opt/libpq/bin)
[[ -d /home/linuxbrew/.linuxbrew/opt/libpq/bin ]] && _zsh_path_prepend+=(/home/linuxbrew/.linuxbrew/opt/libpq/bin)
[[ -d /opt/homebrew/opt/mysql-client/bin ]] && _zsh_path_prepend+=(/opt/homebrew/opt/mysql-client/bin)
[[ -d /usr/local/opt/mysql-client/bin ]] && _zsh_path_prepend+=(/usr/local/opt/mysql-client/bin)
[[ -d /home/linuxbrew/.linuxbrew/opt/mysql-client/bin ]] && _zsh_path_prepend+=(/home/linuxbrew/.linuxbrew/opt/mysql-client/bin)
[[ -d /opt/homebrew/opt/mssql-tools18/bin ]] && _zsh_path_prepend+=(/opt/homebrew/opt/mssql-tools18/bin)
[[ -d /usr/local/opt/mssql-tools18/bin ]] && _zsh_path_prepend+=(/usr/local/opt/mssql-tools18/bin)
[[ -d /home/linuxbrew/.linuxbrew/opt/mssql-tools18/bin ]] && _zsh_path_prepend+=(/home/linuxbrew/.linuxbrew/opt/mssql-tools18/bin)

# nils-cli dev override is applied late in `.zshrc` (after `.zprofile`
# re-prepends /opt/homebrew/bin). Doing it here would be a no-op for
# login shells, so keep the override centralised in `.zshrc`.

# Homebrew (Apple Silicon)
[[ -d /opt/homebrew/bin ]] && _zsh_path_prepend+=(/opt/homebrew/bin /opt/homebrew/sbin)

# Rust (rustup)
[[ -d "$HOME/.cargo/bin" ]] && _zsh_path_prepend+=("$HOME/.cargo/bin")

_zsh_path_prepend+=(
  $ZSH_BIN_DIR
  /usr/local/bin
  /usr/bin
  $HOME/bin
  $HOME/.local/bin
)

path=(
  $_zsh_path_prepend
  $path
)

unset _zsh_path_prepend
