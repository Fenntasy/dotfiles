---
description: Apply when installing or adding any npm/yarn/pnpm package dependency
---

# Pinned dependencies

All projects use exact version pinning. Unpinned ranges (`^`, `~`) cause silent upgrades that break reproducible builds.

## Rules

- Always pass `--save-exact` (npm) or `--exact` (yarn/pnpm) when installing packages
- Never install without the exact flag, even for devDependencies
- Never manually add a dependency with a `^` or `~` prefix to `package.json`

## Examples

```sh
# CORRECT
npm install --save-exact mysql2
npm install --save-dev --save-exact tsx

# WRONG
npm install mysql2
npm install --save-dev tsx
```
