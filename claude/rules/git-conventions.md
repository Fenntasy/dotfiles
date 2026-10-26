# Git Conventions

## Branching

- Never commit directly to `main` or `master` — always create a feature branch first
- If on `main` or `master` with uncommitted changes, create a branch before committing
- Branch naming: `type/short-description` (lowercase, hyphens, no spaces)
- Derive the branch name from the changes (e.g. `feat/add-libpq`, `fix/shell-startup`)
- Never commit on top of a branch whose PR was merged or closed — PRs can be merged outside your control; check first (`gh pr view --json state` / `glab mr view --output json` / Forgejo `tea api 'repos/{owner}/{repo}/pulls/<base>/<branch>'`; no PR/MR yet is a normal outcome for a fresh branch), recover per `/ship` preflight

## Commit conventions

- Never mention Claude, AI, or LLM anywhere in git output — commit messages, PR titles/bodies, branch names — including `Co-Authored-By` lines and "Generated with" footers
- Use conventional commit format: `type(scope): description`
  - `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`
- Keep the first line under 72 characters; wrap body lines at 80
- Only commit when explicitly asked

## Pushing

- Never push directly to `main` or `master`
- **Every push requires a roborev review** (`roborev review --branch --agent claude-code`). Before `git push` or merging a PR, check `roborev list`; do not proceed when no reviews exist for the branch, reviews are still running/queued, or no `claude-code` review is `done`. Findings are handled per `claude/rules/roborev-review-handling.md` — the gate is not an authorization to auto-resolve
- Stop and report on rebase conflicts, lease rejections, or failing checks — never auto-resolve or retry blindly
- Push mechanics, MR/PR bodies, issue linking, and the Norauto MR template live in `/ship`

## Merging

- Always squash merge, and only on explicit ask
- Never merge — or report a PR as mergeable — until every merge gate in `/ship` §7 holds

## Dangerous flags

- **Never use `git add -f` / `git add --force`** without explicit user approval — it bypasses `.gitignore` and silently commits generated files, secrets, or build artifacts. If `git add` rejects a file, the file is gitignored for a reason. Stop and ask
- **Stage explicit paths you edited, never `git add -A` / `git add .`** — a repo-wide formatter or a test suite touches files you did not write. Never "clean up" a dirty tree to make a commit succeed
- **Never use `--no-verify`** — pre-commit hooks are non-negotiable
- **Never use `git reset --hard`** without explicit user approval — destroys uncommitted work
- **Never discard a working-tree change you did not make** — no `git checkout <path>`, `git restore`, `git stash`, or overwriting a dirty file (atomic stash-and-reapply like `git rebase --autostash` is fine; a bare `git stash` is not). Uncommitted is not disposable: an unstaged change is often the only copy of human work, and the user may be editing the repo while you work. If `git status` shows a modification you cannot trace to your own edit, stop and ask — even when it looks like test residue or generated output
