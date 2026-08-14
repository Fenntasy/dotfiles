---
name: ship
description: >
  End-to-end delivery ritual: verify, commit, roborev review, push, and open
  or update the MR/PR — one command instead of driving each step manually.
  Covers: verification gates, conventional commits, the roborev review loop,
  rebase/push safety, template-aware MR/PR bodies, post-merge cleanup.
  Use when: the work is done and the user says "ship", "commit and review",
  "push and MR", or "the usual routine".
version: 1.0.0
date: 2026-07-06
user-invocable: true
argument-hint: "optional: 'no-mr' to stop after push, 'merge' to include merge + cleanup"
---

# Ship

Drive a finished change from working tree to reviewed, pushed, MR'd state.
This skill orchestrates; the non-negotiable constraints live in
`claude/rules/git-conventions.md` (branching, pushing, merge gates) and
`claude/rules/roborev-review-handling.md` (findings are the user's decisions).
Where this skill and those rules disagree, the rules win.

## 1. Preflight

1. **Branch state.** Never ship from `main`/`master` — create a
   `type/short-description` branch first. If already on a feature branch,
   check its MR/PR state (`gh pr view --json state,headRefOid` /
   `glab mr view --output json`, field `diff_refs.head_sha`).
   Merged and the local branch tip equals the merged head SHA → all
   local work landed: switch to main, pull, delete the stale branch
   (`git branch -D` — safe because the SHA check just proved the work
   landed; after a squash merge `-d` refuses), branch fresh. Closed
   without merging, or tips differ → local state may not match what
   merged: stop and report both SHAs — never delete; the user picks
   the recovery.
2. **Working tree survey.** `git status` + `git diff` — know what will be
   staged. Untracked scratch files (plans, notes) stay out unless the user
   says otherwise. Never `git add -f`.
3. **Host detection.** `git remote get-url origin` → GitLab repos use `glab`,
   GitHub repos use `gh`. All later steps follow this choice.

## 2. Verify

Run the project's verification gates before committing — find them in the
project's CLAUDE.md (test/lint/typecheck commands and their gotchas). If the
project defines none, run the obvious equivalents for its toolchain. A
failing gate stops the ritual: report the failure, do not commit around it.

## 3. Commit

- Conventional format `type(scope): description`. First line under 72
  characters; wrap body lines at 80.
- Body explains the why when the diff alone doesn't.
- No AI/assistant mentions, no `Co-Authored-By` bot lines, no literal
  `[skip ci]` anywhere in the message.
- If a pre-commit hook rejects (typos, gitleaks, lint), fix the cause and
  commit again — never `--no-verify`.

## 4. Review (roborev)

1. `roborev review --branch --agent claude-code`.
2. Load the `/roborev` skill and follow its interactive protocol: wait with
   `roborev wait`, show the raw findings, let the user decide each one, one
   `fix:` commit per round, then stop — the user decides whether to re-review.

## 5. Push

1. `git fetch origin`, then `git merge-base --is-ancestor origin/main HEAD`.
2. Not an ancestor → rebase onto `origin/main`. A dirty working tree
   blocks rebase — use `git rebase --autostash` (atomic stash-and-reapply,
   sanctioned by the working-tree rule; a bare `git stash` is not).
   Conflicts → abort the rebase, list the conflicting files and what each
   conflict is about, and stop for the user's go-ahead before resolving.
3. After any rebase, re-run the verification gates (step 2) — a clean rebase
   can still break the build.
4. Push with `--force-with-lease` (add `-u` when no upstream) — the lease
   is the safety net, don't add redundant pulls before it. A lease
   rejection means the remote moved unexpectedly: stop and report. If the
   push fails because the remote branch was deleted, re-check the PR/MR
   state (`gh pr view --json state,headRefOid` / `glab mr view --output
   json`). If a merged/closed PR explains the deletion, apply the
   Preflight branch-state logic: tip equals the merged head SHA → all
   work landed, clean up per Preflight; otherwise stop and report both
   SHAs — never delete the branch, the user picks the recovery
   (typically: fresh branch from updated main, cherry-pick the local
   commits). Re-push with `-u` only when no merged/closed PR explains
   the deletion.

## 6. MR / PR

1. If none exists, create one; if one exists, update title and body to
   reflect **all** commits on the branch vs main.
2. **Template first.** GitLab: fetch the repo's default description template
   through the API —
   `glab api "projects/:id/templates/merge_requests/default" | jq -r .content`
   — and follow its structure. GitHub: read
   `.github/pull_request_template.md`. Don't reconstruct a template from
   memory.
3. Body is plain markdown, directly copyable: concise motivation, what
   changed, how it was tested. Only claim verification that actually
   happened; list still-pending manual checks explicitly.
4. No checkbox items that can only be checked after merge.
5. Reference tickets/issues per the project's tracker conventions (some
   projects track in Jira and don't link repo issues — when unsure, ask).
6. Pass long bodies via heredoc directly to `glab`/`gh` — no temp-file
   round-trips.

## 7. Merge + cleanup (only on explicit ask)

Never merge on your own initiative. When the user says merge:

1. Check every merge gate from `claude/rules/git-conventions.md`: reviews
   done, threads resolved, CI green, test plan complete, PR body current.
2. Squash merge. Then: switch to main, pull, delete the remote branch and
   the local one (`git branch -D` — after a squash merge `-d` refuses even
   though the work landed).

## 8. Anti-patterns

| Anti-pattern | Instead |
| --- | --- |
| Rewriting the MR body from memory | Fetch the template + full branch diff |
| `--no-verify`, `git add -f`, merge without gates | Fix the cause or stop |
| Shipping with a failing or skipped verification gate | Report and stop |
