# Dotfiles

Personal dotfiles for macOS, managed by [RCM](https://github.com/thoughtbot/rcm).

## Installation

```shell
rcup          # Symlink all dotfiles into $HOME (re-run after adding files)
first_setup_machine   # One-time machine bootstrap
```

## Dependencies

- [Starship](https://starship.rs/) — cross-shell prompt
- [mise](https://mise.jdx.dev/) — runtime version manager
- [1Password](https://1password.com/) — SSH key agent and Git commit signing

## Secrets

Machine-specific secrets live in `~/.zshrc.secrets` (never committed). This file is sourced at the end of `zshrc` and should contain:

- `CDPATH` — workspace directory shortcuts (e.g. `export CDPATH=~:~/Workspace:~/Workspace/myorg`)
- API tokens, credentials, and other sensitive env vars

Create it manually on each machine. RCM excludes it via `rcrc`.
