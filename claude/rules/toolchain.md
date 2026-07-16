# Toolchain via mise

Development tools are managed by [mise](https://mise.jdx.dev). Installing
them through other channels creates drift between machines and projects.

## Rules

- **Use mise for any tool it can provide** — languages (Node, Rust, Python,
  …), linters, formatters, CLIs. Check `mise ls` / `.mise.toml` before
  reaching for an installer.
- **Never install toolchain components with `brew`, `rustup`, `nvm`, or
  `pipx` directly** when mise covers them. Homebrew is for system
  applications and casks, not per-project toolchains.
- In a repo with a `mise.toml`/`.mise.toml`, run project commands through
  the mise-provided versions (`mise exec` when the shell isn't activated).
- When a task needs a tool that isn't installed, prefer adding it to the
  project's mise config over a global ad-hoc install, and say what you
  added.

## Secrets are out of scope

Provisioning secrets is never part of toolchain setup: don't read, load, or
manage secret stores. If a command needs a credential, tell the user which
environment variable to set and stop. (Full policy:
`claude/rules/secrets.md`.)
