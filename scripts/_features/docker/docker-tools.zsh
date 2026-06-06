# ────────────────────────────────────────────────────────
# docker-tools (feature: docker)
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias docker-tools
fi

# _zsh_docker_tools_bin
# Resolve the native nils-cli docker-tools binary.
# Usage: _zsh_docker_tools_bin
# Env:
# - ZSH_DOCKER_TOOLS_BIN: executable override for wrapper dispatch.
_zsh_docker_tools_bin() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset override="${ZSH_DOCKER_TOOLS_BIN-}"
  if [[ -n "$override" ]]; then
    if [[ ! -x "$override" ]]; then
      print -u2 -r -- "docker-tools: ZSH_DOCKER_TOOLS_BIN is not executable: $override"
      return 127
    fi
    print -r -- "$override"
    return 0
  fi

  typeset candidate="$HOME/.local/nils-cli/bin/docker-tools"
  if [[ -x "$candidate" ]]; then
    print -r -- "$candidate"
    return 0
  fi

  candidate="$(whence -p docker-tools 2>/dev/null || true)"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    print -r -- "$candidate"
    return 0
  fi

  print -u2 -r -- "docker-tools: docker-tools binary not found (install nils-cli or set ZSH_DOCKER_TOOLS_BIN)"
  return 127
}

# _zsh_docker_tools_exec [args...]
# Execute the resolved nils-cli docker-tools binary.
# Usage: _zsh_docker_tools_exec [args...]
_zsh_docker_tools_exec() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset bin=''
  bin="$(_zsh_docker_tools_bin)" || return $?
  command -- "$bin" "$@"
}

# _zsh_docker_tools_usage
# Print zsh-kit docker-tools wrapper usage.
# Usage: _zsh_docker_tools_usage
_zsh_docker_tools_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  print -r -- "Usage:"
  print -r -- "  docker-tools <group> <command> [args]"
  print -r --
  print -r -- "Groups:"
  print -r -- "  container  sh | zsh | rm      (delegated to nils-cli docker-tools)"
  print -r -- "  compose    down               (delegated to nils-cli docker-tools)"
  print -r -- "  run        zsh                (delegated to nils-cli docker-tools)"
  print -r -- "  alias      list | enable | disable | status"
  print -r --
  print -r -- "Env:"
  print -r -- "  ZSH_DOCKER_TOOLS_BIN          Override delegated docker-tools binary"
  print -r -- "  ZSH_DOCKER_COMPOSE_CMD        Forwarded to nils-cli docker-tools"
  return 0
}

# _zsh_docker_tools_alias_usage
# Print docker-tools alias group usage.
# Usage: _zsh_docker_tools_alias_usage
_zsh_docker_tools_alias_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  print -r -- "Usage: docker-tools alias <command> [args]"
  print -r -- "  list | enable | disable | status"
  return 0
}

# docker-container-sh [-u|--user <user>|--root] <container>
# Exec into a running container via nils-cli docker-tools.
# Usage: docker-container-sh [-u|--user <user>|--root] <container>
docker-container-sh() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _zsh_docker_tools_exec container sh "$@"
}

# docker-container-zsh [-u|--user <user>|--root] <container>
# Exec into a running container via nils-cli docker-tools.
# Usage: docker-container-zsh [-u|--user <user>|--root] <container>
docker-container-zsh() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _zsh_docker_tools_exec container zsh "$@"
}

# docker-container-rm [--no-force] [-v|--volumes] <container...>
# Remove containers via nils-cli docker-tools.
# Usage: docker-container-rm [--no-force] [-v|--volumes] <container...>
docker-container-rm() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _zsh_docker_tools_exec container rm "$@"
}

# docker-compose-down [--all] [--yes] [compose down args...]
# Run docker compose down via nils-cli docker-tools.
# Usage: docker-compose-down [--all] [--yes] [compose down args...]
docker-compose-down() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _zsh_docker_tools_exec compose down "$@"
}

# docker-run-zsh [--no-mount] [--workdir <path>] [--name <name>] [--user <user>|--root] <image>
# Run an interactive container via nils-cli docker-tools.
# Usage: docker-run-zsh [--no-mount] [--workdir <path>] [--name <name>] [--user <user>|--root] <image>
docker-run-zsh() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _zsh_docker_tools_exec run zsh "$@"
}

# docker-tools <group> <command> [args...]
# Dispatch Docker helpers to nils-cli while keeping alias mutation in zsh.
# Usage: docker-tools <group> <command> [args...]
docker-tools() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset group="${1-}"
  case "$group" in
    ''|-h|--help|help)
      _zsh_docker_tools_usage
      return 0
      ;;
    alias)
      shift || true
      typeset cmd="${1-}"
      case "$cmd" in
        ''|-h|--help|help)
          _zsh_docker_tools_alias_usage
          return 0
          ;;
      esac

      if ! (( $+functions[docker-aliases] )); then
        print -u2 -r -- "docker-tools: docker-aliases is not loaded (feature init missing?)"
        return 1
      fi

      case "$cmd" in
        list|enable|disable|status)
          docker-aliases "$@"
          ;;
        *)
          print -u2 -r -- "Unknown alias command: $cmd"
          _zsh_docker_tools_alias_usage
          return 2
          ;;
      esac
      ;;
    *)
      _zsh_docker_tools_exec "$@"
      ;;
  esac
}
