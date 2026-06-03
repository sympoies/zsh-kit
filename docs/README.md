# 📚 Documentation Index

This folder contains the living documentation for this Zsh environment.

Use this page as the entry point, then jump into either the **guides** (how the system is designed)
or the **CLI docs** (how to use shipped commands).

---

## 🧭 Structure

```text
docs/
├── README.md                 # This index
├── guides/                   # Concepts and system behavior
└── cli/                      # User-facing commands
```

---

## 🧠 Guides

- [`guides/startup-files.md`](guides/startup-files.md) — Zsh startup file roles (`.zshenv` / `.zprofile` / `.zshrc`) + `ZDOTDIR`
- [`guides/plugin-system.md`](guides/plugin-system.md) — Declarative plugin loader + Git-based fetcher
- [`guides/login-banner.md`](guides/login-banner.md) — Quote + emoji + optional weather banner
- [`guides/fzf-def-docs.md`](guides/fzf-def-docs.md) — Docblock guidelines for `fzf-cli def` / `fzf-cli function` / `fzf-cli alias`

---

## 🛠 CLI Docs

- [`cli/opencode-cli-helpers.md`](cli/opencode-cli-helpers.md) — Opt-in prompt helpers for OpenCode (feature: `opencode`)
- [`cli/docker-tools.md`](cli/docker-tools.md) — Docker helper router + aliases (feature: `docker`)
- [`cli/open-changed-files.md`](cli/open-changed-files.md) — Open changed files in VS Code (`open-changed-files`)

---

## 🗃 Retired Tools

The legacy in-repo CLI tools (`fzf-tools`, `git-open`, `git-lock`, `git-scope`, `git-summary`,
`git-tools`, `codex-tools` / `codex-starship`) were replaced by native
[`nils-cli`](https://github.com/sympoies/nils-cli) binaries (`fzf-cli`, `git-cli`, `git-lock`,
`git-scope`, `git-summary`, `codex-cli`). Their archived implementations and docs live under
[`archive/legacy-zsh-cli-tools/`](../archive/legacy-zsh-cli-tools/README.md).
