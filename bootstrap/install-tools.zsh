#!/usr/bin/env -S zsh -f

# install-tools.zsh — Install required CLI tools via Homebrew (macOS/Linux)
#
# Usage:
#   ./install-tools.zsh [--dry-run] [--quiet] [--all] [--yes] [--update-brew]
#
# Options:
#   --dry-run   Simulate the installation process without installing anything.
#               Useful for previewing which tools are missing.
#
#   --quiet     Suppress all Homebrew output during installation.
#               Only summary messages will be shown.
#
#   --all       Install both required and optional tools (tools.list + tools.optional.list).
#
#   --yes       Install missing tools without prompting.
#
#   --update-brew
#               Accepted by the user-facing wrapper; no-op here.
#
# Description:
#   This script checks for required CLI tools defined in $ZSH_CONFIG_DIR/tools.list.
#   With --all, it also installs optional tools from $ZSH_CONFIG_DIR/tools.optional.list.
#
#   On macOS (darwin), it will also include tools from:
#     - $ZSH_CONFIG_DIR/tools.macos.list
#     - $ZSH_CONFIG_DIR/tools.optional.macos.list (with --all, if present)
#
#   On Linux (linux), it will also include tools from:
#     - $ZSH_CONFIG_DIR/tools.linux.list
#     - $ZSH_CONFIG_DIR/tools.optional.linux.list (with --all, if present)
#
#   Note:
#   - This script installs tools via Homebrew only. If you maintain apt-only lists
#     (e.g. tools.*.linux.apt.list), install them separately.
#
#   It prompts for confirmation before proceeding, unless --dry-run or --yes is used.
#
#   Homebrew runs on both macOS and Linux; if brew is missing, run ./install-tools.zsh to bootstrap it.
#
#   If all tools are already installed, it exits cleanly with a success message.
#
# Example:
#   ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED=true ./install-tools.zsh  # Alternate dry-run using env var
#   ./install-tools.zsh --quiet           # Quiet mode install

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${SCRIPT_DIR:h}"
export ZDOTDIR="$REPO_ROOT"

typeset -gr PATHS_FILE="$ZDOTDIR/scripts/_internal/paths.exports.zsh"
if [[ -f "$PATHS_FILE" ]]; then
  source "$PATHS_FILE"
else
  printf "❌ paths file not found: %s\n" "$PATHS_FILE"
  exit 1
fi

typeset -gr PRELOAD_FILE="$ZDOTDIR/bootstrap/00-preload.zsh"
[[ -f "$PRELOAD_FILE" ]] && source "$PRELOAD_FILE"

typeset -gr HOMEBREW_HELPER_FILE="$ZDOTDIR/scripts/_internal/homebrew.zsh"
if [[ -f "$HOMEBREW_HELPER_FILE" ]]; then
  source "$HOMEBREW_HELPER_FILE"
else
  printf "❌ homebrew helper not found: %s\n" "$HOMEBREW_HELPER_FILE"
  exit 1
fi

TOOLS_REQUIRED_LIST="$ZSH_CONFIG_DIR/tools.list"
TOOLS_OPTIONAL_LIST="$ZSH_CONFIG_DIR/tools.optional.list"
TOOLS_MACOS_LIST="$ZSH_CONFIG_DIR/tools.macos.list"
TOOLS_OPTIONAL_MACOS_LIST="$ZSH_CONFIG_DIR/tools.optional.macos.list"
TOOLS_LINUX_LIST="$ZSH_CONFIG_DIR/tools.linux.list"
TOOLS_OPTIONAL_LINUX_LIST="$ZSH_CONFIG_DIR/tools.optional.linux.list"
ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED="${ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED-false}"
ZSH_INSTALL_TOOLS_QUIET_ENABLED="${ZSH_INSTALL_TOOLS_QUIET_ENABLED-false}"
ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED="${ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED-false}"
ZSH_INSTALL_TOOLS_ASSUME_YES_ENABLED="${ZSH_INSTALL_TOOLS_ASSUME_YES_ENABLED-false}"

# _install_tools::parse_tools_list_line <line>
# Parse one tools.list line into $reply as: (<tool> <brew_name> <comment>).
# Usage: _install_tools::parse_tools_list_line <line>
function _install_tools::parse_tools_list_line() {
  emulate -L zsh
  setopt errexit nounset pipefail

  local line="$1"
  line="${line%$'\r'}"   # tolerate CRLF checkouts (strip trailing CR)
  local -a parts=()
  parts=("${(@s/::/)line}")

  local tool="${parts[1]-}"
  local brew_name="${parts[2]-}"
  local comment=''
  if (( ${#parts} >= 3 )); then
    comment="${(j/::/)parts[3,-1]}"
  fi

  # Trim surrounding whitespace from the tool/brew fields so a stray space or
  # CR around a column does not become part of the command/formula name.
  tool="${tool#"${tool%%[![:space:]]*}"}"; tool="${tool%"${tool##*[![:space:]]}"}"
  brew_name="${brew_name#"${brew_name%%[![:space:]]*}"}"; brew_name="${brew_name%"${brew_name##*[![:space:]]}"}"

  brew_name="${brew_name:-$tool}"
  reply=("$tool" "$brew_name" "$comment")
}

# _install_tools::ensure_homebrew_on_path
# Ensure brew is available on PATH without eval'ing `brew shellenv`.
# Usage: _install_tools::ensure_homebrew_on_path
function _install_tools::ensure_homebrew_on_path() {
  emulate -L zsh
  setopt errexit nounset pipefail

  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  local brew_path=''
  brew_path="$(zsh_brew::discover || true)"
  [[ -n "$brew_path" ]] || return 1
  zsh_brew::apply_env "$brew_path"
}

# _install_tools::is_installed <tool> <brew_name>
# Return success if the command or its Homebrew formula is installed.
# Usage: _install_tools::is_installed <tool> <brew_name>
function _install_tools::is_installed() {
  emulate -L zsh
  setopt errexit nounset pipefail

  local tool="$1"
  local brew_name="$2"

  if command -v "$tool" >/dev/null 2>&1; then
    return 0
  fi

  if command -v brew >/dev/null 2>&1 && brew list --versions "$brew_name" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED=true
      ;;
    --quiet)
      ZSH_INSTALL_TOOLS_QUIET_ENABLED=true
      ;;
    --all)
      ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED=true
      ;;
    --yes)
      ZSH_INSTALL_TOOLS_ASSUME_YES_ENABLED=true
      ;;
    --update-brew)
      ;;
    *)
      printf "❌ Unknown option: %s\n" "$arg"
      printf "Usage: %s [--dry-run] [--quiet] [--all]\n" "$0"
      exit 1
      ;;
  esac
done

typeset -a tools_list_files=("$TOOLS_REQUIRED_LIST")
case "${OSTYPE-}" in
  darwin*)
    if [[ -f "$TOOLS_MACOS_LIST" ]]; then
      tools_list_files+=("$TOOLS_MACOS_LIST")
    fi
    ;;
  linux*)
    if [[ -f "$TOOLS_LINUX_LIST" ]]; then
      tools_list_files+=("$TOOLS_LINUX_LIST")
    fi
    ;;
esac
if zsh_env::is_true "${ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED-}" "ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED"; then
  tools_list_files+=("$TOOLS_OPTIONAL_LIST")
  case "${OSTYPE-}" in
    darwin*)
      if [[ -f "$TOOLS_OPTIONAL_MACOS_LIST" ]]; then
        tools_list_files+=("$TOOLS_OPTIONAL_MACOS_LIST")
      fi
      ;;
    linux*)
      if [[ -f "$TOOLS_OPTIONAL_LINUX_LIST" ]]; then
        tools_list_files+=("$TOOLS_OPTIONAL_LINUX_LIST")
      fi
      ;;
  esac
fi

if [[ ! -f "$TOOLS_REQUIRED_LIST" ]]; then
  printf "❌ tools.list not found at %s\n" "$TOOLS_REQUIRED_LIST"
  exit 1
fi
if zsh_env::is_true "${ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED-}" "ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED" \
    && [[ ! -f "$TOOLS_OPTIONAL_LIST" ]]; then
  printf "❌ tools.optional.list not found at %s\n" "$TOOLS_OPTIONAL_LIST"
  exit 1
fi

if zsh_env::is_true "${ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED-}" "ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED"; then
  printf "🧪 DRY RUN mode enabled — no installations will be performed\n"
fi

if zsh_env::is_true "${ZSH_INSTALL_TOOLS_QUIET_ENABLED-}" "ZSH_INSTALL_TOOLS_QUIET_ENABLED"; then
  printf "🔇 QUIET mode enabled — suppressing brew output\n"
fi
if zsh_env::is_true "${ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED-}" "ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED"; then
  printf "🧩 ALL mode enabled — including optional tools\n"
fi
if zsh_env::is_true "${ZSH_INSTALL_TOOLS_ASSUME_YES_ENABLED-}" "ZSH_INSTALL_TOOLS_ASSUME_YES_ENABLED"; then
  printf "✅ YES mode enabled — installing missing tools without prompting\n"
fi

if ! zsh_env::is_true "${ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED-}" "ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED"; then
  if ! _install_tools::ensure_homebrew_on_path; then
    printf "❌ Homebrew not found. Run ./install-tools.zsh to bootstrap it (or install Homebrew manually).\n"
    exit 1
  fi
fi

# Scan for missing tools (only if not dry-run)
if ! zsh_env::is_true "${ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED-}" "ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED"; then
  typeset -A seen_tools=()
  missing=()

  for tools_list_file in "${tools_list_files[@]}"; do
    while IFS= read -r line; do
      # Skip blank lines and comments (allow leading whitespace before `#`).
      [[ "$line" =~ '^[[:space:]]*(#|$)' ]] && continue
      _install_tools::parse_tools_list_line "$line"
      tool="$reply[1]"
      brew_name="$reply[2]"
      [[ -n "${seen_tools[$tool]-}" ]] && continue
      seen_tools[$tool]=1
      if ! _install_tools::is_installed "$tool" "$brew_name"; then
        missing+=("$tool")
      fi
    done < "$tools_list_file"
  done

  if (( ${#missing[@]} > 0 )); then
    printf "📦 The following tools are missing and will be installed via Homebrew:\n"
    for tool in "${missing[@]}"; do
      printf "  - %s\n" "$tool"
    done
    printf "\n"
    printf "🛠  You can run this script with --dry-run to preview without installing.\n"
    if zsh_env::is_true "${ZSH_INSTALL_TOOLS_ASSUME_YES_ENABLED-}" "ZSH_INSTALL_TOOLS_ASSUME_YES_ENABLED"; then
      printf "➡️  Proceeding because --yes was supplied.\n"
    elif [[ -t 0 ]]; then
      printf "❓ Proceed with installation? [y/N]: "
      read -r confirm
      if [[ ! "$confirm" =~ '^[Yy]([Ee][Ss])?$' ]]; then
        printf "❌ Aborted by user.\n"
        exit 1
      fi
    else
      printf "❌ Missing tools require confirmation. Re-run with --yes to install non-interactively.\n"
      printf "❌ Aborted by user.\n"
      exit 1
    fi
  else
    printf "✅ All tools are already installed. Nothing to do.\n"
    exit 0
  fi
fi

printf "🔍 Checking and installing CLI tools via Homebrew...\n"

# Counters
installed=0
skipped=0
failed=0

typeset -A seen_tools=()
for tools_list_file in "${tools_list_files[@]}"; do
  while IFS= read -r line; do
    # Skip blank lines and comments (allow leading whitespace before `#`).
    [[ "$line" =~ '^[[:space:]]*(#|$)' ]] && continue

    _install_tools::parse_tools_list_line "$line"
    tool="$reply[1]"
    brew_name="$reply[2]"
    [[ -n "${seen_tools[$tool]-}" ]] && continue
    seen_tools[$tool]=1

    printf "🔧 %-12s " "$tool"

    if _install_tools::is_installed "$tool" "$brew_name"; then
      printf "✓ Already installed\n"
      ((skipped++))
      continue
    fi

    if zsh_env::is_true "${ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED-}" "ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED"; then
      printf "💤 Skipped due to dry-run (%s)\n" "$brew_name"
      continue
    else
      printf "➕ Will install (%s)...\n" "$brew_name"
    fi

    if zsh_env::is_true "${ZSH_INSTALL_TOOLS_QUIET_ENABLED-}" "ZSH_INSTALL_TOOLS_QUIET_ENABLED"; then
      if brew install "$brew_name" >/dev/null 2>&1; then
        printf "✅ %s installed\n" "$tool"
        ((installed++))
      else
        printf "❌ Failed to install %s\n" "$tool"
        ((failed++))
      fi
    else
      if brew install "$brew_name"; then
        printf "✅ %s installed\n" "$tool"
        ((installed++))
      else
        printf "❌ Failed to install %s\n" "$tool"
        ((failed++))
      fi
    fi
  done < "$tools_list_file"
done

printf "\n"
printf "🧾 Install Summary:\n"
printf "   ✅ Installed: %d\n" "$installed"
printf "   ⏭ Skipped:   %d\n" "$skipped"
printf "   ❌ Failed:    %d\n" "$failed"

if (( failed > 0 )); then
  printf "\n"
  printf "❌ One or more tools failed to install.\n"
  exit 1
fi
