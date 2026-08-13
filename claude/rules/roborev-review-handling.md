# Roborev review handling

How to act on roborev findings. Always-loaded because the constraint must hold
even when `/roborev` is never invoked — the methodology lives in the `/roborev`
skill; this rule is the non-negotiable behavior. For the push/merge gate and
branching, see `claude/rules/git-conventions.md`.

## Rules

- **Default to interactive.** When a roborev review exists or completes, present
  *every* finding to the user — severity, location, the reviewer's problem, and
  your recommendation with rationale — then let the user decide each one
  (Fix / Dismiss / Discuss / Skip) via `AskUserQuestion`. Reflect and recommend;
  the user decides.
- **Change no code until the user decides.** Never edit, fix, or "address" a
  finding before the user has chosen what to do with it.
- **Never batch-resolve unless told.** Only fix findings without per-finding
  approval when the user explicitly asks for auto mode (e.g. "/roborev auto").
- **Never loop autonomously.** Do not run review → fix → re-review on your own.
  Apply the agreed fixes, commit once (`fix:`), and stop. The user decides
  whether and when to re-review.
- **Never schedule or background review actions** that fire without a checkpoint
  (no cron/wakeup that auto-fixes or auto-pushes after a review).
- **Don't bury findings.** Surface them as findings for decision — not folded
  into a summary with your verdicts already applied. The reviewer's complete
  text must appear in your message text — tool results and read files are not
  visible to the user, and a paraphrase at decision time is a buried finding.
  Formatting for readability is fine; trimming or rewording is not.

## Why

Roborev output is input for a shared decision, not a checklist to clear alone.
Silently deciding fix-vs-defer and looping reviews removes the user from their
own review process. Invoke the `/roborev` skill for the full interactive flow.
