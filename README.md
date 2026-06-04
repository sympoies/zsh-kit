# zsh-kit

A modular, self-contained Zsh environment focused on manual control, clean structure, and script-based extensibility,
with emoji-powered UX and built-in Git tools.

## ✨ Core Features

> This Zsh environment provides a clean structure and several built-in tools.

- 🌟 [Login banner](docs/guides/login-banner.md): Emoji-powered shell intro with rotating quotes
- 🧩 [Plugin System](docs/guides/plugin-system.md): Git-powered declarative loader with auto-clone and update support
- 🚀 [Starship](https://starship.rs): Customized prompt with language & context awareness
- 🧭 [Zoxide](https://github.com/ajeetdsouza/zoxide): Smart directory jumping, aliased as `z`
- 🛠 [nils-cli](https://github.com/sympoies/nils-cli) integration: native `fzf-cli` / `git-cli` workflows wired into hotkeys and aliases
- 🔧 Modular and lazy-friendly structure under `scripts/`
- 🧹 Centralized `cache/` and `.private/` folders for clean separation of history, state, and secrets

## Structure

```text
.
├── assets/            # Static data files
├── cache/             # Runtime cache dir (.zcompdump, plugin update timestamps, etc.)
├── docs/              # Markdown documentation
│   ├── cli/           # User-facing commands
│   └── guides/        # Concepts and system behavior
├── prompts/           # Shared prompt templates (used by codex/opencode helpers)
├── bootstrap/         # Script orchestrator and plugin logic
├── config/            # Configuration files for third-party tools
├── plugins/           # Vendored upstream plugins (third-party)
├── scripts/           # Modular Zsh behavior scripts
│   ├── _completion/   # Custom completions for CLI tools or aliases
│   ├── _features/     # Optional feature modules (opt-in via `ZSH_FEATURES`)
│   ├── _internal/     # Internal modules (not auto-loaded; paths, features helpers)
│   ├── git/           # Git workflow aliases (compound flows via nils-cli `git-cli`)
│   └── interactive/   # Interactive shell scripts (completion, plugin hooks, etc.)
├── tests/             # Zsh test scripts (audit, regression, etc.)
├── tools/             # Standalone executable scripts or compiled helpers
└── .private/          # Local state + secrets (not for sharing)
```

## 🪄 Startup Snapshot

> Login messages include randomly selected inspirational quotes and an optional cached weather snapshot
> (`weather-cli` when configured, wttr.in fallback), stored in local files that grow over time.

An example Zsh startup log with this config (`weather-cli` + `ZSH_WEATHER_CITY` configured;
the wttr.in fallback prints the classic ASCII report instead):

```text
🌦  Taipei  25~35°C  ☔ 59%  Drizzle

📜 "Focus on how far you have come in life rather than looking at the accomplishments of others." — Lolly Daskal
🌿  Thinking shell initialized. Expect consequences...

🍎 yourname on MacBook ~ 🐳 orbstack
08:00:00.000 ✔︎
```

To show a one-line feature summary at startup, set:

```bash
export ZSH_BOOT_FEATURES_ENABLED=true
```

## Setup

This repo is designed to be used as your Zsh config directory via `ZDOTDIR`.

### Install On A New Mac

Install Homebrew first if it is not already available, then install the
`zsh-kit` setup CLI from `nils-cli`:

```bash
brew tap sympoies/tap
brew install nils-cli
```

Run a dry-run before mutating shell startup files:

```bash
zsh-kit setup \
  --repo https://github.com/graysurf/zsh-kit.git \
  --write-zshenv \
  --install-tools skip \
  --dry-run
```

Apply the setup after reviewing the dry-run:

```bash
zsh-kit setup \
  --repo https://github.com/graysurf/zsh-kit.git \
  --write-zshenv \
  --install-tools skip \
  --apply
```

Forward optional feature flags with `--features`:

```bash
zsh-kit setup \
  --repo https://github.com/graysurf/zsh-kit.git \
  --write-zshenv \
  --install-tools skip \
  --features docker,opencode \
  --apply
```

The safe default is `--install-tools skip`, which does not install or modify
third-party CLI tools. After the shell setup is in place, preview required tools:

```bash
cd "$HOME/.config/zsh"
./install-tools.zsh --dry-run
```

Install missing required tools only after reviewing the list:

```bash
./install-tools.zsh --yes
```

Use `./install-tools.zsh --all --yes` for optional tools, and
`./install-tools.zsh --update-brew --yes` only when you intentionally want to
run `brew update` first. The installer does not run `brew upgrade`.

Existing commands already on `PATH` are treated as installed even when they came
from another package manager such as Homebrew, `mise`, `asdf`, `pipx`, `cargo`,
or a vendor installer.

### Existing `~/.zshenv`

`zsh-kit setup --write-zshenv` writes a managed `~/.zshenv` that exports
`ZDOTDIR` and sources this repo's `.zshenv`. If the user already has an
unmanaged `~/.zshenv`, setup stops with a conflict instead of overwriting it.

Keep the existing file and add this snippet manually:

```bash
export ZDOTDIR="$HOME/.config/zsh"
export ZSH_FEATURES="${ZSH_FEATURES:-}"
if [[ -r "$ZDOTDIR/.zshenv" ]]; then
  source "$ZDOTDIR/.zshenv"
fi
```

Use `--force` only after backing up or intentionally replacing the existing
file:

```bash
zsh-kit setup \
  --repo https://github.com/graysurf/zsh-kit.git \
  --write-zshenv \
  --install-tools skip \
  --apply \
  --force
```

### Runtime Setup With `zsh-kit`

The repository exposes a stable setup hook at
`bootstrap/zsh-kit-setup.zsh`. The nils-cli `zsh-kit` binary clones or updates
the repository, validates this hook, and dispatches the repo-owned setup
behavior. For repository-local validation, the hook can be run without private
mutations:

```bash
bootstrap/zsh-kit-setup.zsh --features docker --install-tools skip --dry-run --smoke
```

For agent-driven setup from a checked-out copy of this repository, the project
also exposes `.agents/scripts/bootstrap.sh` for the runtime-kit `$bootstrap`
skill. The dispatcher defaults to a dry-run:

```bash
agent-run exec --cwd "$HOME/.config/zsh" -- ./.agents/scripts/bootstrap.sh --dry-run
```

After reviewing the plan, apply the same setup:

```bash
agent-run exec --cwd "$HOME/.config/zsh" -- ./.agents/scripts/bootstrap.sh --apply
```

Pass `--repo https://github.com/graysurf/zsh-kit.git` when the checked-out
repository's `origin` is SSH but the target machine should install over HTTPS.
The bootstrap dispatcher defaults to `--write-zshenv`, `--install-tools skip`,
and a post-setup smoke check when the destination hook exists.

In your `~/.zshenv`, set the custom config location **and explicitly source** this repo’s `.zshenv`:

```bash
export ZDOTDIR="$HOME/.config/zsh"
if [[ -r "$ZDOTDIR/.zshenv" ]]; then
  source "$ZDOTDIR/.zshenv"
fi
```

### Optional Features (`ZSH_FEATURES`)

Some modules are disabled by default (not sourced).
Enable them by setting `ZSH_FEATURES` in your **home** `~/.zshenv` **before** sourcing this repo:

```bash
export ZSH_FEATURES="docker,opencode"
```

Current features:

- `opencode`: enables `opencode-tools` (plus `opencode-tools` completion)
- `docker`: enables `docker-tools` + `docker-aliases` (plus `docker-tools` + `docker` completion)

Why the extra `source`? `.zshenv` is the first startup file, so setting `ZDOTDIR` inside `~/.zshenv`
does not automatically make Zsh restart and load `$ZDOTDIR/.zshenv`.

Zsh will now load:

- `$ZDOTDIR/.zshenv` for all shells
- `$ZDOTDIR/.zprofile` for login shells
- `$ZDOTDIR/.zshrc` for interactive shells

For more details, see: [docs/guides/startup-files.md](docs/guides/startup-files.md).

Make sure that `.zshrc` sources the bootstrap loader:

```bash
source "$ZDOTDIR/bootstrap/bootstrap.zsh"
```

This will initialize all scripts in proper order via the `load_script_group_ordered()` / `load_script_group()` loader helpers.

Machine-local environment defaults belong in ignored private files. The tracked
`.zshenv` sources `.private/zshenv.zsh` when present, so personal paths, company
hosts, tokens, and agent runtime overrides do not ship to other machines.

## Philosophy

No magic. Fully reproducible.  
Modular by design, manual by default.

## 🧑‍💻 Why I Made This

This setup is the result of many hours spent refining my shell environment.  
It includes several tools I built myself—some small, some extensive.  
Among them, [git-magic](scripts/git/git-magic.zsh) remains my favorite and most-used.  

If there’s something you use every day, it’s worth taking the time to make it yours.

## 🪪 License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This project is licensed under the MIT License. See [LICENSE](LICENSE).
Third-party plugins are fetched separately (see `config/plugins.list`) and remain under their respective upstream licenses.
