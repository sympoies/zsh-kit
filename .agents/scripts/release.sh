#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  .agents/scripts/release.sh [--dry-run] VERSION

Release flow:
  1. Read release notes from CHANGELOG.md section "## VERSION".
  2. Verify the working tree is clean and main matches origin/main.
  3. Run the local release validation gate.
  4. Create a GitHub release for VERSION from origin/main.

VERSION may be provided as v2.1.4 or 2.1.4.
USAGE
}

die() {
  echo "release: error: $*" >&2
  exit 1
}

info() {
  echo "release: $*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

normalize_version() {
  local raw="$1"
  case "$raw" in
    v[0-9]*.[0-9]*.[0-9]*) printf '%s\n' "$raw" ;;
    [0-9]*.[0-9]*.[0-9]*) printf 'v%s\n' "$raw" ;;
    *) die "version must look like vX.Y.Z or X.Y.Z (got: $raw)" ;;
  esac
}

extract_changelog_section() {
  local version="$1"
  local changelog="$2"
  local output="$3"

  awk -v version="$version" '
    function is_version_heading(line) {
      return line == "## " version || index(line, "## " version " ") == 1
    }
    /^## v[0-9]/ && in_section {
      exit
    }
    is_version_heading($0) {
      in_section = 1
    }
    in_section {
      print
      found = 1
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$changelog" >"$output" || die "CHANGELOG.md has no section for $version"

  [ -s "$output" ] || die "empty changelog notes for $version"
}

ensure_clean_worktree() {
  if ! git diff --quiet --ignore-submodules --; then
    die "working tree has unstaged changes"
  fi
  if ! git diff --cached --quiet --ignore-submodules --; then
    die "index has staged changes"
  fi
  if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    die "working tree has untracked files"
  fi
}

ensure_main_matches_remote() {
  local branch="$1"
  local local_head=""
  local remote_head=""

  [ "$branch" = "main" ] || die "release must run from main (current: $branch)"

  info "fetching origin/main and tags"
  git fetch origin main --tags --quiet

  local_head="$(git rev-parse HEAD)"
  remote_head="$(git rev-parse origin/main)"
  if [ "$local_head" != "$remote_head" ]; then
    die "HEAD does not match origin/main"
  fi
}

ensure_version_available() {
  local version="$1"
  local repo="$2"

  if git rev-parse -q --verify "refs/tags/$version" >/dev/null; then
    die "local tag already exists: $version"
  fi
  if git ls-remote --exit-code --tags origin "refs/tags/$version" >/dev/null 2>&1; then
    die "remote tag already exists: $version"
  fi
  if gh release view "$version" --repo "$repo" >/dev/null 2>&1; then
    die "GitHub release already exists: $version"
  fi
}

run_validation() {
  info "running release validation"
  zsh -f ./tools/fix-typeset-empty-string-quotes.zsh --check
  zsh -f ./tools/fix-typeset-initializers.zsh --check
  ./tools/check.zsh --smoke --completions --env-bools
  bash ./scripts/ci/markdownlint-audit.sh --strict
  ./tests/run.zsh
}

main() {
  local dry_run=false
  local version_arg=""
  local version=""
  local repo_root=""
  local repo_slug="sympoies/zsh-kit"
  local branch=""
  local target="main"
  local notes_dir=""
  local notes_file=""
  local release_url=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      -h|--help)
        usage
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        [ -z "$version_arg" ] || die "only one version argument is supported"
        version_arg="$1"
        shift
        ;;
    esac
  done

  [ -n "$version_arg" ] || {
    usage >&2
    die "missing VERSION"
  }

  require_command git
  require_command gh
  require_command awk
  require_command zsh

  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" ||
    die "not inside a git work tree"
  cd "$repo_root"

  version="$(normalize_version "$version_arg")"
  branch="$(git branch --show-current)"
  notes_dir="${AGENT_OUT_DIR:-$repo_root/out}/release"
  mkdir -p "$notes_dir"
  notes_file="$notes_dir/$version-notes.md"

  extract_changelog_section "$version" "$repo_root/CHANGELOG.md" "$notes_file"
  ensure_main_matches_remote "$branch"
  if [ "$dry_run" = false ]; then
    ensure_clean_worktree
  elif [ -n "$(git status --short)" ]; then
    info "dry-run: skipping clean-worktree enforcement"
  fi
  ensure_version_available "$version" "$repo_slug"
  run_validation

  if [ "$dry_run" = true ]; then
    info "dry-run: would create GitHub release $version from $target"
    info "notes-file=$notes_file"
    return 0
  fi

  info "creating GitHub release $version"
  gh release create "$version" \
    --repo "$repo_slug" \
    --target "$target" \
    --title "$version" \
    --notes-file "$notes_file"

  git fetch origin "refs/tags/$version:refs/tags/$version" --quiet || true
  release_url="$(gh release view "$version" --repo "$repo_slug" --json url --jq .url)"
  info "release-url=$release_url"
}

main "$@"
