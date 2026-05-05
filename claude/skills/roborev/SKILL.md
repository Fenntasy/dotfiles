---
name: roborev
description: |
  Automated code review management with roborev daemon and CLI.
  Covers: claude-code reviews, fixing findings, pre-push workflow, daemon management, per-project config.
  Use when: checking reviews, fixing findings, managing review status, or before pushing.
version: 1.0.0
date: 2026-04-02
user-invocable: true
---

# Roborev — Automated Code Review

Roborev is a daemon-based automated code review tool. It runs post-commit hooks that trigger AI-powered reviews via claude-code, and provides CLI commands to inspect, fix, and iterate on findings.

## When to Use

- After roborev flags issues — read findings, fix them, verify
- When the PreToolUse hook blocks a push or merge due to unaddressed findings
- For manual review commands (dirty review, branch review, specific commit)
- After the pre-push gate runs `roborev review --branch --agent claude-code` — the gate is **not** a silent loop; treat findings the same as any other roborev invocation

## Display protocol (applies to every invocation)

Before any analysis, recommendation, or fix, **show the user the raw output of `roborev show <job-id>`** for the latest completed review. Paste it verbatim — not a summary, not a paraphrase.

Only after the raw output is visible may you:

1. Add your own analysis below it (severity triage, claim verification, recommendations).
2. Ask the user how to proceed.

Rationale: the user must see what the reviewer actually said before any decisions are made. Summaries lose information, and starting to fix before the findings are on screen takes the decision away from the user.

## Review Modes

### Interactive mode (default)

This is the default for **any** roborev review you trigger or observe — including the pre-push gate, the PreToolUse hook unblock flow, and post-commit auto-reviews. Auto mode is opt-in only.

Invoked with `/roborev` or `/roborev interactive`, or implicitly anytime roborev produces findings without an explicit `/roborev auto` instruction.

1. Run `roborev show` to get the latest review and **show the raw output to the user** (see Display protocol above)
2. If no findings → report clean and stop
3. For each finding (severity order: blocker → medium → low):
   - **Reflect first** — before presenting options, reason about the finding against the project's architecture and design philosophy. Read the relevant code, check project rules, and determine which action best serves codebase coherence. Present your recommendation with rationale, not a bare option list
   - Present: severity, file, location, reviewer's description, **your recommendation and why**
   - Ask via `AskUserQuestion`: **Fix** / **Dismiss** / **Discuss** / **Skip** — with your recommended option clearly marked
   - **Fix** → implement the change, move to next finding
   - **Dismiss** → note the user's reason, no code change
   - **Discuss** → investigate deeper (read code, verify claims, check docs), report back, re-ask
   - **Skip** → defer, revisit after remaining findings
4. After all findings processed, commit fixes (if any), wait for re-review
5. Repeat until clean or user says stop
6. Summarize: what was fixed, what was dismissed (with reasons)

**Never auto-resolve.** Every finding requires the user's explicit decision, regardless of how roborev was triggered. Claude recommends — the user decides.

### Auto mode

Invoked **only** by an explicit `/roborev auto` from the user. Never assume auto mode for the pre-push gate, the PreToolUse unblock flow, or any other implicit trigger.

1. Run `roborev show` to get the latest review and **show the raw output to the user** (see Display protocol)
2. If no findings → report clean and stop
3. Verify each claim before fixing (reviewer can be wrong — check exit codes, API behavior, docs)
4. Fix all verified findings, commit, wait for re-review, repeat until clean
5. If a claim is wrong, report it as dismissed with rationale

### Behavioral rules (both modes)

- **Show before deciding** — the raw `roborev show` output goes to the user before any recommendation or fix
- **Reflect and recommend** — for every finding, reason about which action best fits the project's architecture before presenting options
- **Never auto-resolve unless explicitly in `/roborev auto`** — every finding requires the user's explicit decision via `AskUserQuestion` in interactive mode, and that mode is the default
- **Pre-push gate is interactive** — running `roborev review --branch --agent claude-code` to satisfy the push gate does not authorize silent fix loops; surface findings, ask, then fix
- **Never auto-dismiss** — only the user (interactive) or verified-wrong claims (auto) can dismiss
- **Verify before fixing** — check the reviewer's technical claims before implementing
- **Severity-first** — blockers before mediums before lows
- **High/blocker findings default to Fix** — never recommend Dismiss for high-severity findings unless the claim is factually wrong
- **One commit per review round** — batch all fixes into a single commit using `fix:` conventional commit format
- **User controls the review cycle** — never autonomously decide to stop reviewing

## Commands

### Setup

```sh
roborev init          # Initialize a new repo (creates .roborev.toml + installs hooks)
roborev install-hook  # Install hooks only (when .roborev.toml already exists)
```

### Check status

```sh
roborev list          # List reviews for current branch
roborev show          # Show review for HEAD commit
roborev show <sha>    # Show review for a specific commit
```

### Manual review

```sh
roborev review                  # Review HEAD commit
roborev review --branch         # Review all commits on current branch vs main
roborev review --dirty          # Review uncommitted changes
roborev review --agent claude-code  # Explicit agent override
```

### Fix findings

```sh
roborev fix     # One-shot fix for all unaddressed findings
roborev refine  # Iterative fix loop: fix → re-review → repeat until passing
```

### Interactive TUI

```sh
roborev tui --repo --branch   # TUI filtered to current repo + branch
roborev tui                   # Full TUI (all repos)
```

## Push and Merge Enforcement

A global PreToolUse hook blocks `git push` and `gh pr merge` when:

- No reviews exist for the branch (run `roborev review --branch` first)
- Any review is still `running` or `queued`
- No `claude-code` review with status `done` exists for the branch

When blocked: check status with `roborev list`, then `roborev review --branch --agent claude-code`.

## Daemon

```sh
roborev daemon start   # Start daemon
roborev daemon stop    # Stop daemon
roborev status         # Check daemon health + recent jobs
```

The post-commit hook sends jobs to the daemon. If the daemon is not running, reviews queue and process when it starts.

## Per-Project Config (`.roborev.toml`)

```toml
agent = "claude-code"
review_reasoning = "thorough"
excluded_branches = ["main"]

review_guidelines = '''
Project-specific hard invariants for the reviewer.
'''
```

## Anti-patterns

- Ignoring blocker-level findings
- Recommending Dismiss on high-severity findings because "it's mitigated by convention"
- Auto-resolving findings without an explicit `/roborev auto` from the user — every finding needs explicit user approval
- Treating the pre-push gate (or any non-`/roborev auto` invocation) as license to silently fix and re-review
- Summarizing findings without first showing the raw `roborev show` output — the user must see what the reviewer actually said before decisions are made
- Presenting bare option lists without reasoning — always reflect and recommend
- Running `roborev init` in a repo that already has `.roborev.toml` — use `install-hook` instead
