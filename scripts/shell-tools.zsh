# ───────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    fd-files fd-dirs fdf fdd \
    bat-view batp \
    kp kpid \
    reload execz zz zsh-reload zsh-restart \
    histflush history-flush \
    edit-zsh y \
    cheat weather \
    open-changed-files ocf \
    bff his
fi

# Legacy cleanup (functions removed from shell-tools.zsh).
for _su_fn in bat-all zdef fsearch fzf-history-wrapper; do
  (( $+functions[$_su_fn] )) && unfunction "$_su_fn"
done
unset _su_fn

# ────────────────────────────────────────────────────────
# fd helpers (file and directory search)
# ────────────────────────────────────────────────────────

# fd-files: Find files via fd (includes hidden; excludes .git).
# Usage: fd-files [fd args...]
alias fd-files='fd --type f --hidden --follow --exclude .git'

# fd-dirs: Find directories via fd (includes hidden; excludes .git).
# Usage: fd-dirs [fd args...]
alias fd-dirs='fd --type d --hidden --follow --exclude .git'

# fdf
# Prefer `fzf-cli file` when available; fallback to `fd-files`.
# Usage: fdf [args...]
# Env:
# - FZF_FILE_OPEN_WITH: file opener: `vi` (default) or `vscode`.
# Notes:
# - If `fzf-cli` exists (and interactive TTY), dispatches to: fzf-cli file [args...]
# - Otherwise, falls back to: fd-files [args...]
fdf() {
  emulate -L zsh
  setopt err_return

  if [[ -o interactive && -t 1 ]] && command -v fzf-cli >/dev/null 2>&1; then
    fzf-cli file "$@"
  else
    fd-files "$@"
  fi
}

# fdd
# Prefer `fzf-cli directory` when available; fallback to `fd-dirs`.
# Usage: fdd [args...]
# Notes:
# - If `fzf-cli` exists (and interactive TTY), dispatches to: fzf-cli directory [args...]
# - Otherwise, falls back to: fd-dirs [args...]
fdd() {
  emulate -L zsh
  setopt err_return

  if [[ -o interactive && -t 1 ]] && command -v fzf-cli >/dev/null 2>&1; then
    fzf-cli directory "$@"
  else
    fd-dirs "$@"
  fi
}

# ────────────────────────────────────────────────────────
# Process helpers
# ────────────────────────────────────────────────────────

# _zsh_shell_tools_fzf_cli
# Resolve the nils-cli `fzf-cli` binary for shell-tools wrappers.
# Usage: _zsh_shell_tools_fzf_cli
# Env:
# - ZSH_SHELL_TOOLS_FZF_CLI: test/local override for a specific executable.
_zsh_shell_tools_fzf_cli() {
  emulate -L zsh
  setopt pipe_fail nounset

  if [[ -n "${ZSH_SHELL_TOOLS_FZF_CLI-}" ]]; then
    if [[ ! -x "$ZSH_SHELL_TOOLS_FZF_CLI" ]]; then
      print -u2 -r -- "❌ ZSH_SHELL_TOOLS_FZF_CLI is not executable: $ZSH_SHELL_TOOLS_FZF_CLI"
      return 1
    fi
    print -r -- "$ZSH_SHELL_TOOLS_FZF_CLI"
    return 0
  fi

  typeset local_bin="$HOME/.local/nils-cli/bin/fzf-cli"
  if [[ -x "$local_bin" ]]; then
    print -r -- "$local_bin"
    return 0
  fi

  command -v fzf-cli 2>/dev/null
}

# _zsh_shell_tools_fzf_cli_exec [args...]
# Execute the resolved native `fzf-cli`.
# Usage: _zsh_shell_tools_fzf_cli_exec [args...]
_zsh_shell_tools_fzf_cli_exec() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset bin=''
  bin="$(_zsh_shell_tools_fzf_cli)" || {
    print -u2 -r -- "❌ fzf-cli not found; install nils-cli or set ZSH_SHELL_TOOLS_FZF_CLI."
    return 127
  }

  "$bin" "$@"
}

# kill-port [-9] <port>
# Kill process(es) listening on a TCP/UDP port.
# Usage: kill-port [-9] <port>
# Options:
# - -9: send SIGKILL (9) instead of SIGTERM (15).
# Notes:
# - Delegates behavior to `fzf-cli kill-port`; this function is shell glue.
# Safety:
# - Killing processes may interrupt services and cause data loss.
kill-port() {
  emulate -L zsh
  setopt pipe_fail err_return

  _zsh_shell_tools_fzf_cli_exec kill-port "$@"
}

# kp: Alias of kill-port.
# Usage: kp [-9] <port>
alias kp='kill-port'

# kill-process [-9] <pid> [pid...]
# Kill one or more PIDs.
# Usage: kill-process [-9] <pid> [pid...]
# Options:
# - -9: send SIGKILL (9) instead of SIGTERM (15).
# Safety:
# - Killing processes may interrupt services and cause data loss.
kill-process() {
  emulate -L zsh
  setopt pipe_fail err_return

  _zsh_shell_tools_fzf_cli_exec kill-process "$@"
}

# kpid: Alias of kill-process.
# Usage: kpid [-9] <pid> [pid...]
alias kpid='kill-process'

# ────────────────────────────────────────────────────────
# Shell session helpers
# ────────────────────────────────────────────────────────

# zsh-reload
# Reload the Zsh environment by re-sourcing bootstrap/bootstrap.zsh.
# Usage: zsh-reload
zsh-reload() {
  emulate -L zsh

  # NOTE: Do NOT enable `err_return` here.
  # The bootstrap/plugin loader is best-effort and may intentionally return non-zero.
  # Enabling `err_return` could abort the reload prematurely.

  print -r -- ""
  print -r -- "🔁 Reloading bootstrap/bootstrap.zsh..."
  print -r -- "💡 For major changes, consider running: zsh-restart"
  print -r -- ""

  if ! source "$ZDOTDIR/bootstrap/bootstrap.zsh"; then
    print -u2 -r -- "❌ Failed to reload Zsh environment"
    print -r -- ""
    return 1
  fi
}

# reload: Alias of zsh-reload.
# Usage: reload
alias reload='zsh-reload'

# zsh-restart
# Restart the current shell session (exec zsh).
# Usage: zsh-restart
# Notes:
# - Replaces the current process; unsaved shell state is lost.
zsh-restart() {
  emulate -L zsh

  print -r -- ""
  print -r -- "🚪 Restarting Zsh shell (exec zsh)..."
  print -r -- "🧼 This will start a clean session using current configs."
  print -r -- ""

  # Best-effort: don't let history flush failure block restart.
  (( $+functions[history-flush] )) && history-flush || true

  exec zsh
}

# execz: Alias of zsh-restart.
# Usage: execz
alias execz='zsh-restart'

# zz: Alias of zsh-restart.
# Usage: zz
alias zz='zsh-restart'

# history-flush
# Flush in-memory history to the history file.
# Usage: history-flush
history-flush() {
  emulate -L zsh

  # Append in-memory history to $HISTFILE; optionally re-read to merge.
  fc -AI
}

# histflush: Alias of history-flush.
# Usage: histflush
alias histflush='history-flush'

# edit-zsh
# Open the Zsh config directory in VS Code, then return to the current directory.
# Usage: edit-zsh
edit-zsh() {
  emulate -L zsh
  setopt err_return

  typeset cwd=''
  cwd="$(pwd)"

  code "$ZDOTDIR"
  builtin cd -- "$cwd" >/dev/null
}

# open-changed-files
# Open changed files in VS Code (delegates to fzf-cli through a compatibility wrapper).
# Usage: open-changed-files [--git] [--dry-run] [files...]
# Notes:
# - Keeps the historical zsh-kit entrypoint; nils-cli owns the CLI behavior.
open-changed-files() {
  emulate -L zsh
  setopt err_return

  typeset tool="${ZSH_TOOLS_DIR:-${ZDOTDIR:-$HOME/.config/zsh}/tools}/open-changed-files.zsh"
  if [[ ! -r "$tool" ]]; then
    print -u2 -r -- "❌ open-changed-files tool not found: $tool"
    return 127
  fi

  zsh -f -- "$tool" "$@"
}

# ocf: Alias of open-changed-files.
# Usage: ocf [--git] [--dry-run] [files...]
alias ocf='open-changed-files'

# y [dir] [yazi args...]
# Launch yazi and change to the last visited directory on exit.
# Usage: y [dir] [yazi args...]
# Notes:
# - If the first argument does not start with `-`, it is treated as a zoxide target.
y() {
  emulate -L zsh
  setopt pipe_fail err_return

  if ! command -v yazi >/dev/null 2>&1; then
    print -u2 -r -- "❌ yazi not found"
    return 127
  fi

  # Detect directory alias/keyword as the first argument (non‑flag)
  if [[ -n "$1" && "$1" != -* ]]; then
    typeset target="$1"
    shift
    if (( $+functions[__zoxide_z] )); then
      __zoxide_z "$target"
    else
      builtin cd -- "$target" 2>/dev/null || {
        print -u2 -r -- "❌ Unable to resolve directory: $target"
        return 1
      }
    fi
  fi

  # Launch yazi and persist the last visited directory on exit
  typeset tmp='' cwd=''
  tmp="$(mktemp -t 'yazi-cwd.XXXXXX')" || return 1
  {
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(<"$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
      builtin cd -- "$cwd"
    fi
  } always {
    command rm -f -- "$tmp" >/dev/null 2>&1 || true
  }
}

# ────────────────────────────────────────────────────────
# Network helpers (curl-based)
# ────────────────────────────────────────────────────────

# cheat <query>
# Query cheat.sh via curl.
# Usage: cheat <query>
# Notes:
# - Requires network access.
cheat() {
  emulate -L zsh
  setopt err_return

  if (( $# == 0 )); then
    print -u2 -r -- "Usage: cheat <query>"
    return 2
  fi

  typeset query="${(j:+:)@}"
  curl -s -- "https://cheat.sh/${query}"
}

# weather [location]
# Print weather information (prefers `weather-cli`; falls back to wttr.in).
# Usage: weather [location]
# Env:
# - ZSH_WEATHER_CITY: default city for `weather-cli` when no location is given.
# Notes:
# - Requires network access.
# - `weather-cli` needs a city (argument or ZSH_WEATHER_CITY); otherwise wttr.in is used.
weather() {
  emulate -L zsh
  setopt err_return

  typeset city="${*:-${ZSH_WEATHER_CITY-}}"
  if command -v weather-cli >/dev/null 2>&1 && [[ -n "$city" ]]; then
    weather-cli today --city "$city"
    return $?
  fi

  if ! command -v curl >/dev/null 2>&1; then
    print -u2 -r -- "❌ curl not found"
    return 127
  fi

  typeset location="${(j:+:)@}"
  if [[ -n "$location" ]]; then
    curl -s -- "https://wttr.in/${location}"
  else
    curl -s -- "https://wttr.in"
  fi
}
