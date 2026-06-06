# 🐳 docker-tools: Docker Helper Router

`docker-tools` is an opt-in feature (`ZSH_FEATURES=docker`) that adds shell
wrappers around the native `nils-cli` `docker-tools` binary:

- `docker-tools`: grouped helper router
- `docker-container-sh`, `docker-container-zsh`, `docker-container-rm`
- `docker-compose-down`
- `docker-run-zsh`
- `docker-aliases`: enable/disable multiple alias sets (base/omz/long)
- cached completion for `docker` / `docker-compose` (loaded during `compinit`)

---

## Enable

In `~/.zshenv` (before sourcing this repo):

```bash
export ZSH_FEATURES="docker"
```

---

## Alias Sets

Default: `base,omz,long` (override with `ZSH_DOCKER_ALIASES`).

```bash
export ZSH_DOCKER_ALIASES="base,omz"   # or: all / none
```

Sets:

- `base`: `d` (docker), `dc` (compose), `dt` (docker-tools), `dsh` (container shell), `drz` (run image shell)
- `omz`: common `oh-my-zsh` style aliases (e.g. `dps`, `dxcit`, `dcup`, `dcdn`, `drm!`)
- `long`: verbose aliases (e.g. `docker-ps`, `docker-execit`, `docker-rmf`)

Runtime control:

```bash
docker-aliases status
docker-aliases enable omz
docker-aliases disable long
```

Compose command override (optional):

```bash
export ZSH_DOCKER_COMPOSE_CMD="docker compose"   # or: docker-compose
```

Delegated binary override (optional):

```bash
export ZSH_DOCKER_TOOLS_BIN="$HOME/.local/nils-cli/bin/docker-tools"
```

`container`, `compose`, and `run` behavior is owned by nils-cli. The zsh-kit
layer keeps only wrapper dispatch and the shell-mutating `alias` group.

---

## Commands

### `docker-tools container sh <container>`

Exec into a running container with the best available shell (`zsh` → `bash` → `sh`).

```bash
docker-tools container sh my-container
```

### `docker-tools container rm <container...>`

Remove container(s) (force by default).

```bash
docker-tools container rm my-container
docker-tools container rm --no-force my-container
docker-tools container rm -v my-container
```

### `docker-tools compose down [--all] [--yes]`

Wrapper for `docker compose down` with an optional “remove everything” mode.

```bash
docker-tools compose down
docker-tools compose down --all --yes
```

### `docker-tools run zsh <image>`

Run an interactive container and exec into `zsh` (fallback `bash`/`sh`).

```bash
docker-tools run zsh ubuntu:latest
docker-tools run zsh --no-mount alpine:latest
```

### `docker-tools alias <command>`

Alias management remains in zsh because it mutates the current shell.

```bash
docker-tools alias list
docker-tools alias enable omz
docker-tools alias disable long
docker-tools alias status
```
