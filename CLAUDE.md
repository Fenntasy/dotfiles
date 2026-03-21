# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles for macOS managed by [RCM](https://github.com/thoughtbot/rcm). Files in this repo are symlinked into `$HOME` via `rcup`.

## Key commands

```sh
rcup                   # Symlink all dotfiles into $HOME (re-run after adding files)
first_setup_machine    # One-time machine bootstrap (ASDF, tpm, macOS defaults)
bin/upgrade_all        # Bulk upgrade: brew, mise plugins, App Store, tldr
```

## How symlinks work

RCM maps this repo to `$HOME` by stripping the dotfiles directory prefix and prepending a dot. Example: `zshrc` → `~/.zshrc`, `config/nvim/` → `~/.config/nvim/`.

`rcrc` controls behavior:
- `EXCLUDES="README.md utils"` — these are never symlinked
- Files in `hooks/` run as RCM lifecycle hooks (`post-up` sets zsh as default shell)

When adding a new config file, place it here and run `rcup` to activate it.

## Directory structure

| Path | Purpose |
|---|---|
| `zsh/` | Shell aliases (`zaliases`), completions (`zcompletion`), shell functions |
| `zshrc` | Main zsh entry point — PATH, env vars, sources `zsh/*` |
| `gitconfig` | Git identity, aliases, SSH signing via 1Password (`op-ssh-sign`) |
| `config/nvim/` | Neovim (Lua, lazy.nvim plugin manager) |
| `config/alacritty/` | Alacritty terminal config |
| `bin/` | Executable scripts symlinked to `~/bin/` |
| `claude/` | Claude Code rules and skills (see below) |
| `Brewfile` | Homebrew packages, casks, VS Code extensions, Mac App Store apps |
| `utils/` | Static resources (iTerm colors, icons) — not symlinked |

## Claude configuration

Rules in `claude/rules/` are global instructions loaded automatically for all projects. Skills in `claude/skills/` are loaded on demand (by file pattern or task intent) per the routing table in `claude/rules/skill-triggers.md`.

When editing any file under `claude/` or `memory/`, load the `/claude-authoring` skill first.
