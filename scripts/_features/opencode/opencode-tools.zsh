typeset -g OPENCODE_CLI_MODEL="${OPENCODE_CLI_MODEL:-}"
typeset -g OPENCODE_CLI_VARIANT="${OPENCODE_CLI_VARIANT:-}"

if command -v safe_unalias >/dev/null; then
  safe_unalias \
    oc
fi

# oc
# Alias of `opencode-tools`.
# Usage: oc <command> [args...]
alias oc='opencode-tools'

# opencode-tools: Prompt helpers (feature: opencode).
#
# Provides compatibility wrappers around native nils-cli `opencode-cli`:
# - `opencode-tools` (dispatcher, alias `oc`)
# - `opencode-commit-with-scope`
# - `opencode-advice`
# - `opencode-knowledge`

# _opencode_tools_cli
# Resolve the native nils-cli opencode-cli binary used by OpenCode helpers.
# Usage: _opencode_tools_cli
# Env:
# - OPENCODE_TOOLS_CLI: executable override for tests or local development.
_opencode_tools_cli() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset override="${OPENCODE_TOOLS_CLI-}"
  if [[ -n "$override" ]]; then
    if [[ ! -x "$override" ]]; then
      print -u2 -r -- "opencode-tools: OPENCODE_TOOLS_CLI is not executable: $override"
      return 127
    fi
    print -r -- "$override"
    return 0
  fi

  typeset candidate="$HOME/.local/nils-cli/bin/opencode-cli"
  if [[ -x "$candidate" ]]; then
    print -r -- "$candidate"
    return 0
  fi

  candidate="$(whence -p opencode-cli 2>/dev/null || true)"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    print -r -- "$candidate"
    return 0
  fi

  print -u2 -r -- "opencode-tools: opencode-cli binary not found (install nils-cli or set OPENCODE_TOOLS_CLI)"
  return 127
}

# _opencode_tools_cli_exec [args...]
# Execute the resolved native opencode-cli binary.
# Usage: _opencode_tools_cli_exec [args...]
_opencode_tools_cli_exec() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset bin=''
  bin="$(_opencode_tools_cli)" || return $?
  "$bin" "$@"
}

# opencode-commit-with-scope [-p|--push] [-a|--auto-stage] [extra prompt...]
# Run the native OpenCode semantic-commit workflow.
opencode-commit-with-scope() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _opencode_tools_cli_exec agent commit "$@"
}

# opencode-advice [question...]
# Run actionable-advice prompt.
opencode-advice() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _opencode_tools_cli_exec agent advice "$@"
}

# opencode-knowledge [question...]
# Run actionable-knowledge prompt.
opencode-knowledge() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _opencode_tools_cli_exec agent knowledge "$@"
}

# _opencode_tools_usage [fd]
# Print top-level usage for `opencode-tools`.
# Usage: _opencode_tools_usage [fd]
_opencode_tools_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset fd="${1-1}"
  print -u"$fd" -r -- 'Usage:'
  print -u"$fd" -r -- '  opencode-tools <command> [args...]'
  print -u"$fd" -r -- '  opencode-tools <prompt...>'
  print -u"$fd" -r -- '  opencode-tools -- <prompt...>   (force prompt mode)'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Commands:'
  print -u"$fd" -r -- '  prompt [prompt...]                             Run a raw prompt'
  print -u"$fd" -r -- '  commit-with-scope [-p|--push] [-a|--auto-stage] [extra prompt...]'
  print -u"$fd" -r -- '  advice [question]                              Get actionable engineering advice'
  print -u"$fd" -r -- '  knowledge [concept]                            Get clear explanation and angles for a concept'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Config: OPENCODE_CLI_MODEL, OPENCODE_CLI_VARIANT, OPENCODE_TOOLS_CLI'
  return 0
}

# _opencode_tools_run_raw_prompt [prompt...]
# Run a raw prompt through native opencode-cli.
_opencode_tools_run_raw_prompt() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _opencode_tools_cli_exec agent prompt "$@"
}

# opencode-tools <command> [args...]
# Dispatcher for OpenCode prompt helpers.
# Usage: opencode-tools <command> [args...]
opencode-tools() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset cmd="${1-}"

  case "$cmd" in
    ''|-h|--help|help)
      _opencode_tools_usage 1
      return 0
      ;;
    list)
      print -u2 -r -- "opencode-tools: use \`opencode-tools help\`"
      return 64
      ;;
    *)
      ;;
  esac

  shift

  case "$cmd" in
    --|prompt)
      _opencode_tools_run_raw_prompt "$@"
      ;;
    commit-with-scope|commit)
      opencode-commit-with-scope "$@"
      ;;
    advice)
      opencode-advice "$@"
      ;;
    knowledge)
      opencode-knowledge "$@"
      ;;
    *)
      _opencode_tools_run_raw_prompt "$cmd" "$@"
      ;;
  esac
}
