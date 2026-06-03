# scripts/_internal/

This folder contains **internal modules** that are intentionally **not auto-loaded** by the
bootstrap script loader (paths starting with `_` are skipped).

The code here is meant to be sourced explicitly by a caller that needs it.

---

## paths

Files:

- `scripts/_internal/paths.exports.zsh` (exports only)
- `scripts/_internal/paths.init.zsh` (minimal init: ensure cache dir exists)

Purpose:

- Define core `ZSH_*` path variables (`ZSH_CONFIG_DIR`, `ZSH_SCRIPT_DIR`, `ZSH_CACHE_DIR`, etc.)
  in one place.
- `paths.exports.zsh` is intended to be sourced **very early** (now via `$ZDOTDIR/.zshenv`).
- `paths.init.zsh` is intended to be sourced by interactive/login entrypoints (e.g. `.zshrc`, `.zprofile`).

Notes:

- This module is intentionally under `_internal/` so it is **not auto-loaded** by the bootstrap
  script group loader; callers opt-in via `source`.

> The cached CLI wrapper generator (`wrappers.zsh` + `tools/bundle-wrapper.zsh`) was removed:
> the legacy CLI tools it bundled now ship as native `nils-cli` binaries, and
> `open-changed-files` is provided as a shell function in `scripts/shell-tools.zsh`.
