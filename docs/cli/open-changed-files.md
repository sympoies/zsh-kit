# open-changed-files

Open a set of changed files in Visual Studio Code for quick review.

This tool is intended to be used after an LLM edits files, so you can immediately inspect the touched files in VSCode.

## TL;DR

- Open explicit files (default): `open-changed-files path/to/a path/to/b`
- Open from stdin (no args): `printf "%s\\n" path/to/a path/to/b | open-changed-files`
- Open git changes: `open-changed-files --git`
- Preview commands: `open-changed-files --dry-run ...`

## Entrypoint

zsh-kit ships an `open-changed-files` shell function (alias: `ocf`) in `scripts/shell-tools.zsh`.
The shell entrypoint delegates to `./tools/open-changed-files.zsh`, which is a compatibility
wrapper for `fzf-cli open-changed-files`.

Outside an interactive zsh-kit shell (scripts, subshells), call the script directly via
`./tools/open-changed-files.zsh ...`.

The CLI behavior is owned by nils-cli. zsh-kit keeps only the shell function, alias, and wrapper
entrypoint.

## Behavior

- If the `code` CLI is not found:
  - Normal mode: does nothing, exits `0`, prints nothing.
  - `--dry-run`: still prints planned `code ...` invocations.
- If `OPEN_CHANGED_FILES_CODE_PATH` is set but invalid (not found or not executable):
  - Normal mode: does nothing, exits `0`, prints nothing.
  - `--verbose`: prints a no-op reason to stderr.
- Default maximum opened files: `5` (configurable).
- Workspace behavior:
  - Default (`--workspace-mode pwd`): open everything in a single VSCode window with workspace set to `$PWD`.
  - `--workspace-mode git`: search up to 5 parent directories for a `.git` root per file, and open different git roots in different VSCode windows.
  - When opening many files (after increasing `--max-files`): opens per-workspace in batches of 50 to avoid argv
    limits (first batch uses `--new-window`, subsequent batches use `--reuse-window`).

## Usage

```zsh
open-changed-files [--list|--git] [--workspace-mode pwd|git] [--dry-run] [--verbose] [--max-files N] [--] [files...]
# or: ./tools/open-changed-files.zsh ...
```

### Modes

- `--list` (default): open file paths from CLI args; when no args are provided, read newline-delimited paths from stdin.
- `--git`: open changed files from git:
  - staged + unstaged + untracked
  - deleted paths are skipped

### Options

- `--dry-run`: print the planned `code ...` commands without executing them
- `--verbose`: explain no-op behavior and ignored paths (stderr only)
- `--workspace-mode pwd|git`: workspace strategy (default: `pwd`)
- `--max-files N`: cap opened files (default: `5`)

### Environment

- `OPEN_CHANGED_FILES_SOURCE`: `list` (default) or `git`
- `OPEN_CHANGED_FILES_WORKSPACE_MODE`: `pwd` (default) or `git`
- `OPEN_CHANGED_FILES_MAX_FILES`: max files to open (default: `5`)
- `OPEN_CHANGED_FILES_CODE_PATH`: `auto` (default), `none` (force no-op), or a `code` path/name override
- `OPEN_CHANGED_FILES_FZF_CLI`: optional zsh-kit wrapper override for the `fzf-cli` executable
