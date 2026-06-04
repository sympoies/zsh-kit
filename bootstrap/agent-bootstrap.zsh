#!/usr/bin/env -S zsh -f

setopt pipe_fail err_exit nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr REPO_ROOT="${SCRIPT_PATH:h:h}"
typeset -gr DEFAULT_REPO_URL="https://github.com/graysurf/zsh-kit.git"

# agent_bootstrap::usage
# Print agent bootstrap usage.
# Usage: agent_bootstrap::usage
agent_bootstrap::usage() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "Usage: bootstrap/agent-bootstrap.zsh [--dry-run|--apply] [options]"
  print -r -- ""
  print -r -- "Options:"
  print -r -- "  --dry-run                 Preview zsh-kit setup actions (default)."
  print -r -- "  --apply                   Apply zsh-kit setup."
  print -r -- "  --repo URL_OR_PATH        Repository to install from (default: origin URL, then public HTTPS)."
  print -r -- "  --dest PATH               Destination ZDOTDIR (default: \$HOME/.config/zsh)."
  print -r -- "  --features CSV            Forward optional feature flags."
  print -r -- "  --install-tools POLICY    Forward skip|repo tool install policy (default: skip)."
  print -r -- "  --write-zshenv            Write managed \$HOME/.zshenv (default)."
  print -r -- "  --no-write-zshenv         Do not write managed \$HOME/.zshenv."
  print -r -- "  --force                   Forward zsh-kit setup --force."
  print -r -- "  --smoke                   Run post-setup smoke when the destination hook exists (default)."
  print -r -- "  --no-smoke                Skip post-setup smoke."
  print -r -- "  --format text|json        Forward zsh-kit setup output format (default: text)."
}

# agent_bootstrap::die <message...>
# Print an error message and exit.
# Usage: agent_bootstrap::die "message"
agent_bootstrap::die() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "agent bootstrap: $*"
  exit 1
}

# agent_bootstrap::info <message...>
# Print a setup progress message.
# Usage: agent_bootstrap::info "message"
agent_bootstrap::info() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "agent bootstrap: $*"
}

# agent_bootstrap::origin_url
# Print the repo origin URL or the public fallback URL.
# Usage: agent_bootstrap::origin_url
agent_bootstrap::origin_url() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset origin=''
  origin="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
  if [[ -n "$origin" ]]; then
    print -r -- "$origin"
  else
    print -r -- "$DEFAULT_REPO_URL"
  fi
}

# agent_bootstrap::main [args...]
# Run zsh-kit setup for agent-driven bootstrap.
# Usage: agent_bootstrap::main "$@"
agent_bootstrap::main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset mode='dry-run'
  typeset repo_url=''
  typeset dest="${ZSH_KIT_DEST:-$HOME/.config/zsh}"
  typeset features="${ZSH_FEATURES-}"
  typeset install_tools='skip'
  typeset write_zshenv=true
  typeset force=false
  typeset smoke=true
  typeset format='text'

  repo_url="$(agent_bootstrap::origin_url)"

  while (( $# > 0 )); do
    case "$1" in
      --dry-run)
        mode='dry-run'
        ;;
      --apply)
        mode='apply'
        ;;
      --repo)
        shift || agent_bootstrap::die "--repo requires a value"
        (( $# > 0 )) || agent_bootstrap::die "--repo requires a value"
        repo_url="$1"
        ;;
      --repo=*)
        repo_url="${1#--repo=}"
        ;;
      --dest)
        shift || agent_bootstrap::die "--dest requires a value"
        (( $# > 0 )) || agent_bootstrap::die "--dest requires a value"
        dest="$1"
        ;;
      --dest=*)
        dest="${1#--dest=}"
        ;;
      --features)
        shift || agent_bootstrap::die "--features requires a value"
        (( $# > 0 )) || agent_bootstrap::die "--features requires a value"
        features="$1"
        ;;
      --features=*)
        features="${1#--features=}"
        ;;
      --install-tools)
        shift || agent_bootstrap::die "--install-tools requires a value"
        (( $# > 0 )) || agent_bootstrap::die "--install-tools requires a value"
        install_tools="$1"
        ;;
      --install-tools=*)
        install_tools="${1#--install-tools=}"
        ;;
      --write-zshenv)
        write_zshenv=true
        ;;
      --no-write-zshenv)
        write_zshenv=false
        ;;
      --force)
        force=true
        ;;
      --smoke)
        smoke=true
        ;;
      --no-smoke)
        smoke=false
        ;;
      --format)
        shift || agent_bootstrap::die "--format requires a value"
        (( $# > 0 )) || agent_bootstrap::die "--format requires a value"
        format="$1"
        ;;
      --format=*)
        format="${1#--format=}"
        ;;
      -h|--help)
        agent_bootstrap::usage
        return 0
        ;;
      *)
        agent_bootstrap::die "unknown option: $1"
        ;;
    esac
    shift || true
  done

  case "$install_tools" in
    skip|repo) ;;
    *) agent_bootstrap::die "--install-tools must be skip|repo (got: $install_tools)" ;;
  esac
  case "$format" in
    text|json) ;;
    *) agent_bootstrap::die "--format must be text|json (got: $format)" ;;
  esac

  command -v zsh-kit >/dev/null 2>&1 || {
    agent_bootstrap::die "zsh-kit not found. Install nils-cli first: brew tap sympoies/tap && brew install nils-cli"
  }

  typeset -a setup_cmd=(
    zsh-kit setup
    --repo "$repo_url"
    --dest "$dest"
    --install-tools "$install_tools"
    --format "$format"
    "--$mode"
  )
  [[ -n "$features" ]] && setup_cmd+=(--features "$features")
  [[ "$write_zshenv" == true ]] && setup_cmd+=(--write-zshenv)
  [[ "$force" == true ]] && setup_cmd+=(--force)

  agent_bootstrap::info "mode=$mode"
  agent_bootstrap::info "repo=$repo_url"
  agent_bootstrap::info "dest=$dest"
  agent_bootstrap::info "write-zshenv=$write_zshenv"
  agent_bootstrap::info "install-tools=$install_tools"
  [[ -n "$features" ]] && agent_bootstrap::info "features=$features"

  "${setup_cmd[@]}"

  if [[ "$smoke" == true ]]; then
    typeset hook="$dest/bootstrap/zsh-kit-setup.zsh"
    if [[ -r "$hook" ]]; then
      typeset -a smoke_cmd=(zsh -f "$hook" --install-tools skip --dry-run --smoke)
      [[ -n "$features" ]] && smoke_cmd+=(--features "$features")
      agent_bootstrap::info "running smoke hook=$hook"
      "${smoke_cmd[@]}"
    else
      agent_bootstrap::info "smoke skipped: setup hook not present at $hook"
    fi
  fi

  agent_bootstrap::info "complete"
}

agent_bootstrap::main "$@"
