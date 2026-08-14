---
name: roborev
description: |
  Interactive handling of roborev code reviews.
  Covers: the finding-by-finding walkthrough (interactive default), /roborev auto, and CLI commands for status, waiting, and manual reviews.
  Use when: a review completes or blocks a push, walking findings with the user, or triggering manual reviews.
version: 2.0.0
date: 2026-08-13
user-invocable: true
---

# Roborev — Automated Code Review

Roborev reviews commits via post-commit hooks and an on-machine daemon. This skill is the *methodology* for handling findings. The non-negotiable constraints live in `claude/rules/roborev-review-handling.md`; the push/merge gate lives in `claude/rules/git-conventions.md`.

## When to Use

- A review exists or just completed — post-commit, pre-push gate, or manual — and findings need handling
- The PreToolUse hook blocks a push or merge: satisfy the gate (`roborev review --branch --agent claude-code`), then treat the findings like any other review — the gate is not a license to silently fix

## Interactive mode (default)

Default for any review, however triggered. Auto mode is opt-in only.

1. Run `roborev show` and put a formatted overview into your message text — finding count, severity and location per finding, and the reviewer's summary verbatim. Tool results, Read output, and background task files are not visible to the user: content only counts as shown when it is in the message itself. Each finding's complete text follows at its decision point (step 3) — the overview orients, the decision message carries the evidence
2. No findings → report clean and stop
3. For each finding (blocker → medium → low):
   - Reflect first: read the relevant code, check project rules, verify the reviewer's claim, and check whether the flagged code was a deliberate choice (git blame, memory) — intentional code gets a question, not a recommended fix
   - Ask via `AskUserQuestion` with the finding's complete reviewer text inside the question field itself — severity, location, problem, suggested fix, verbatim — then, still inside the question field, your recommendation with rationale. The field renders plain text (no markdown): structure it with blank lines — severity/location header, problem, suggested fix, recommendation — never as one paragraph. Never a bare option list, never a paraphrase: message text written before a tool call in the same turn may not render, so the dialog must be self-contained; the user decides on what the reviewer wrote, not on your compression of it. Options: **Fix** / **Dismiss** / **Discuss** / **Skip**, recommended option marked
   - Fix → implement the change *and complete it*: sweep adjacent text/code for the same flaw and check that the fix's conditions are actually verifiable before moving on — a fix that feeds the next round is not a fix. Dismiss → record the user's reason, no code change. Discuss → investigate deeper, report back, re-ask. Skip → defer until after the remaining findings
4. After all findings: batch fixes into one `fix:` commit, wait for the re-review with `roborev wait`
5. Repeat until clean or the user says stop
6. Summarize what was fixed and what was dismissed, with reasons

High/blocker findings default to Fix — recommend Dismiss only when the claim is factually wrong.

## Auto mode (`/roborev auto` only)

1. Run `roborev show` and put the full review into your message text before fixing anything — formatted, never trimmed; auto mode has no per-finding decision messages, so the upfront display carries everything
2. Verify each claim before fixing — the reviewer can be wrong
3. Fix verified findings, one `fix:` commit, wait for the re-review with `roborev wait`, repeat until clean
4. Report wrong claims as dismissed, with rationale

## Commands

```sh
roborev list                                  # Reviews for current branch
roborev show [sha]                            # Review for HEAD (or a specific commit)
roborev review                                # Review HEAD
roborev review --branch --agent claude-code   # Branch review — satisfies the push gate
roborev review --dirty                        # Review uncommitted changes
roborev wait [job_id|sha ...]                 # Block until the review completes (default: HEAD's job)
roborev status                                # Daemon health — check when reviews sit queued
```

**Waiting:** always `roborev wait`, run via Bash in the background — never hand-rolled `while true; do roborev list…` polling, never sleep-and-check loops. Pass the job IDs the review command printed (`--job` forces IDs), or no args for HEAD. Exit 1 means FAIL verdict *or* error — not a broken command; read the output and proceed to `roborev show` either way.

**Never run `roborev fix` or `roborev refine`** — they are autonomous fix loops that bypass the interactive protocol.
