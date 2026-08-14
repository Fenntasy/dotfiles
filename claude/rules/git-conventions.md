# Git Conventions

## Branching

- Never commit directly to `main` or `master` — always create a feature branch first
- If on `main` or `master` with uncommitted changes, create a branch before committing
- Branch naming: `type/short-description` (lowercase, hyphens, no spaces)
- Derive the branch name from the changes (e.g. `feat/add-libpq`, `fix/shell-startup`)
- Never commit on top of a branch whose PR was merged or closed — PRs can be merged outside your control; check first (`gh pr view --json state` / `glab mr view --output json`; no PR/MR yet is a normal outcome for a fresh branch), recover per `/ship` preflight

## Commit conventions

- Never mention Claude, AI, or LLM anywhere in git output — commit messages, PR titles/bodies, branch names — including `Co-Authored-By` lines and "Generated with" footers
- Use conventional commit format: `type(scope): description`
  - `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`
- Keep the first line under 72 characters; wrap body lines at 80
- Only commit when explicitly asked

## Pushing

- Never push directly to `main` or `master`
- **Every push requires a roborev review** — run `roborev review --branch --agent claude-code` before pushing; findings are handled per `/roborev` and `claude/rules/roborev-review-handling.md`. The gate is not an authorization to auto-resolve
- **Roborev gate** — enforced by a PreToolUse hook on `git push` and `gh pr merge`. The hook blocks when: no reviews exist for the branch, reviews are still running/queued, or no `claude-code` review is `done`. If blocked, check status with `roborev list`
- Push mechanics (fetch, rebase, `--force-with-lease`) live in `/ship` — stop and report on rebase conflicts, lease rejections, or failing checks; never auto-resolve or retry blindly
- After every push, ensure a PR exists and its title/body reflect all commits on the branch vs main (mechanics and body format per `/ship` and `/project-management`)

## Issue linking

Applies in repos that track work in GitHub issues — follow the repo's observed convention (check recent PRs) rather than forcing issues onto repos that don't use them.

- Reference at least one issue per PR
- Multi-concern PRs: each distinct fix or feature gets its own issue
- Use `Fixes #N` (auto-closes on merge) or `Addresses #N` (no auto-close) in the PR body
- If work addresses something not yet tracked, create the issue before or at PR time
- Branch names may include the issue number: `fix/42-shell-startup`

## MR description (Norauto repos only)

For projects under `~/Workspace/norauto/`, structure the MR body with these sections in order, each as a `##` heading: **Motivation and Context**, **Solution**, **Related Ticket** (Jira URL — create the ticket if none exists), **How Has This Been Tested?**, **Screenshots** (omit if not relevant), **Types of changes** (checkbox list: Chore / Bug fix / New feature / Breaking change).

## Merge strategy

- Always squash merge — never use merge or rebase strategies
- Merge only on explicit ask — mechanics and post-merge cleanup (back to main, pull, delete remote and local branch) per `/ship`

## Merge gates

Before merging any PR — and when assessing whether a PR is mergeable — **all** of these must be true:

- Zero unresolved review threads
- **Roborev reviews complete** — run `roborev list` and verify at least one `claude-code` review is `done` and no reviews are `running` or `queued`. If reviews are missing, trigger them. The PreToolUse hook enforces this at push/merge time, but also check proactively when reporting merge readiness
- **Test plan complete** — read the PR body and verify every test plan item is checked (`[x]`). If any item is unchecked, run the verification yourself or ask the user. Never merge with unchecked items
- CI passes — use `gh pr checks <number> --repo {owner}/{repo} --watch` to confirm
- PR is still in `OPEN` state
- All session todos completed — never merge with pending or in-progress task items
- PR body is up to date — check off verified test plan items (`[x]`), update summary/title if commits changed. Do this via `gh pr edit` before merging

## Dangerous flags

- **Never use `git add -f` / `git add --force`** without explicit user approval — it bypasses `.gitignore` and silently commits generated files, secrets, or build artifacts. If `git add` rejects a file, the file is gitignored for a reason. Stop and ask
- **Stage explicit paths you edited, never `git add -A` / `git add .`** — a repo-wide formatter or a test suite touches files you did not write. Never "clean up" a dirty tree to make a commit succeed
- **Never use `--no-verify`** — pre-commit hooks are non-negotiable
- **Never use `git reset --hard`** without explicit user approval — destroys uncommitted work
- **Never discard a working-tree change you did not make** — no `git checkout <path>`, `git restore`, `git stash`, or overwriting a dirty file (atomic stash-and-reapply like `git rebase --autostash` is fine; a bare `git stash` is not). Uncommitted is not disposable: an unstaged change is often the only copy of human work, and the user may be editing the repo while you work. If `git status` shows a modification you cannot trace to your own edit, stop and ask — even when it looks like test residue or generated output
