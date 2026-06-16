# 📜 Zsh Startup Files: `.zshenv`, `.zprofile`, `.zshrc`

This repo uses Zsh’s startup file system to keep **always-loaded exports** fast and universal,
while keeping **interactive UX** (plugins, prompt, keybinds) isolated to interactive shells.

---

## ⚙️ Load Order (What Zsh Reads)

Zsh loads different files depending on whether the shell is:

- **interactive** (`zsh -i`)
- **login** (`zsh -l`)
- **non-interactive** (`zsh -c '...'`)

At a high level (user-level files):

| Shell type | Loaded files |
| --- | --- |
| non-interactive | `.zshenv` |
| interactive | `.zshenv` → `.zshrc` |
| login (non-interactive) | `.zshenv` → `.zprofile` |
| login + interactive | `.zshenv` → `.zprofile` → `.zshrc` |

Notes:

- `zsh -f` disables startup files entirely.
- `.zlogin` / `.zlogout` exist, but this repo doesn’t rely on them.

---

## 📍 `ZDOTDIR` and the XDG Layout

This repo stores Zsh config under an XDG-style directory:

```text
$HOME/.config/zsh
```

Zsh uses `$ZDOTDIR` to locate startup files. The catch is:

- `.zshenv` is loaded **first**
- if you set `ZDOTDIR` *inside* `~/.zshenv`, Zsh will not “restart” and load `$ZDOTDIR/.zshenv` automatically

So the common solution is to keep a tiny `~/.zshenv` in `$HOME` that:

1. exports `ZDOTDIR`
2. explicitly sources `$ZDOTDIR/.zshenv`

Example (matches the intent of this repo’s setup):

```zsh
export ZDOTDIR="$HOME/.config/zsh"
if [[ -n "${ZDOTDIR-}" && "$ZDOTDIR" != "$HOME" && -r "$ZDOTDIR/.zshenv" ]]; then
  source "$ZDOTDIR/.zshenv"
fi
```

If you instead export `ZDOTDIR` *before launching Zsh* (e.g. via your OS environment), Zsh will
directly load `$ZDOTDIR/.zshenv` and won’t read `~/.zshenv` at all.

---

## 🧩 What Each File Does (In This Repo)

### `$ZDOTDIR/.zshenv` (always-loaded exports)

Purpose: **exports only** and **fast**.

What it does:

- sources `scripts/_internal/paths.exports.zsh`
- defines core `ZSH_*` directory exports (`ZSH_CACHE_DIR`, `ZSH_SCRIPT_DIR`, etc.)
- defines `HISTFILE` under `cache/`
- defines non-secret Codex helper defaults (`CODEX_AUTH_FILE`, `CODEX_SECRET_DIR`,
  `CODEX_PROMPT_SEGMENT_ENABLED`)
- sources `.private/zshenv.zsh` when present for machine-local env defaults
- sets a minimal, deduplicated `PATH` (via `typeset -U path PATH`) including:
  - Homebrew (`/opt/homebrew/bin`, `/opt/homebrew/sbin`) when present
  - GNU “gnubin” shims (e.g. `coreutils` for `shuf`) when present
  - first-party wrappers (`$ZDOTDIR/bin`)
  - user bins (`$HOME/bin`, `$HOME/.local/bin`)

What does **not** belong here:

- plugin loading
- `compinit`
- prompt/terminal UI
- network calls (`curl`, `git`, etc.)
- personal secrets or company-specific defaults in tracked files

This file runs in places you may not expect (e.g. `zsh -c`, fzf preview subshells, editor tasks), so
keep it quiet and predictable.

---

### `$ZDOTDIR/.zprofile` (login-only environment)

Purpose: **login-session environment** (one-time-ish setup).

What it does:

- runs `brew shellenv` when Homebrew exists, which configures more than just `PATH` (e.g. `MANPATH`)
- sets `HOMEBREW_AUTO_UPDATE_SECS=604800` (7 days)

Why this is login-only:

- it’s slightly heavier than just adding `/opt/homebrew/bin` to `PATH`
- many tools don’t need the full Homebrew environment in non-login shells

This repo still ensures `brew` is discoverable in non-login shells via
`scripts/_internal/paths.exports.zsh`.

---

### `$ZDOTDIR/.zshrc` (interactive session bootstrap)

Purpose: interactive UX + modular boot flow.

What it does:

1. Ensures `scripts/_internal/paths.exports.zsh` + `scripts/_internal/paths.init.zsh` are loaded
   (with a fallback for manual sourcing).
2. Configures history behavior and a few boot flags (`ZSH_DEBUG`, `ZSH_BOOT_WEATHER_ENABLED`, `ZSH_BOOT_QUOTE_ENABLED`).
3. Optionally shows the login banner (weather + quote).
4. Sources `bootstrap/bootstrap.zsh`, which loads the rest of the repo modules under `scripts/`.
5. Optionally prints the enabled feature list when `ZSH_BOOT_FEATURES_ENABLED=true` (default: false).

---

## 🐛 `ZSH_DEBUG` levels (startup diagnostics)

`ZSH_DEBUG` is a numeric verbosity level for interactive startup diagnostics.

Levels:

- `0` (default): quiet boot (no per-file timing output)
- `1`: prints `✅ Loaded <label> in <N>ms` for each sourced bootstrap/module file
- `2`: adds `🔍 Loading: <path>` and script-group headers
- `3`: also prints the full collected/filtered script lists for each group

Notes:

- Levels are additive (higher levels include lower-level output).
- Migration: if you previously used `ZSH_DEBUG=0` to see timings, use `ZSH_DEBUG=1` now.
- Some modules treat `ZSH_DEBUG>=2` as "show warnings" (e.g. feature loader, docker completion).
- `codex-rate-limits -d` is roughly equivalent to `ZSH_DEBUG>=2` for keeping stderr / per-account errors.

Related:

- `ZSH_BOOT_FEATURES_ENABLED=true` shows the one-line enabled feature summary at startup (TTY only).

Quick example:

```bash
ZSH_BOOT_WEATHER_ENABLED=false ZSH_BOOT_QUOTE_ENABLED=false ZSH_DEBUG=1 zsh -i -c 'exit'
```

---

## 🧪 Quick Verification

Non-interactive shells should still see the exported paths and core tools:

```bash
env -i HOME="$HOME" zsh -c 'print -r -- "$ZDOTDIR"; print -r -- "$ZSH_CACHE_DIR"; print -r -- "$HISTFILE"; command -v brew; command -v shuf'
```

Interactive non-login shells (common in GUI apps like VS Code) should still find Homebrew tools:

```bash
env -i HOME="$HOME" ZSH_BOOT_WEATHER_ENABLED=false ZSH_BOOT_QUOTE_ENABLED=false zsh -i -c 'print -r -- "$HISTFILE"; command -v brew; command -v shuf; exit'
```

Login + interactive shells should load everything (including `.zprofile`):

```bash
ZSH_BOOT_WEATHER_ENABLED=false ZSH_BOOT_QUOTE_ENABLED=false zsh -il -c 'print -r -- "login=$options[login] interactive=$options[interactive]"; exit'
```

---

## 🔍 Common Pitfalls

- **“Why doesn’t `.zprofile` run in VS Code?”**  
  VS Code typically spawns a **non-login interactive** shell. Use `zsh -l`, or configure the terminal to start login shells.

- **“Why is `brew` missing?”**  
  `brew shellenv` runs only in login shells here. The fallback path is handled in
  `scripts/_internal/paths.exports.zsh` (make sure `/opt/homebrew/bin` exists on your machine).

- **“Why is history writing to `$ZDOTDIR/.zsh_history`?”**  
  On macOS, `/etc/zshrc` sets `HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history` for interactive shells.
  This repo re-asserts `HISTFILE` under `$ZSH_CACHE_DIR` in `$ZDOTDIR/.zshrc`.

- **“Why keep `.zshenv` so minimal?”**  
  Because it runs in non-interactive contexts and must not produce output or introduce slow startup.

---

## 🔗 See Also

- `README.md` (Setup section)
- `scripts/_internal/paths.exports.zsh`
- `scripts/_internal/paths.init.zsh`
- `bootstrap/bootstrap.zsh`
- `docs/guides/login-banner.md`
