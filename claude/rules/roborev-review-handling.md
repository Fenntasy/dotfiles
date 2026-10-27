# Roborev review handling

How to act on roborev findings. Always-loaded because the constraint must hold
even when `/roborev` is never invoked — the methodology lives in the `/roborev`
skill; this rule is the non-negotiable behavior. For the push/merge gate and
branching, see `claude/rules/git-conventions.md`.

## Rules

- **Default to interactive.** When a roborev review exists or completes, present
  *every* finding to the user — severity, location, the reviewer's problem, and
  your recommendation with rationale — then let the user decide each one
  (Fix / Dismiss / Discuss / Skip) on the decision surface set by the next
  rule. Reflect and recommend; the user decides.
- **Prefer the pane when it's loaded.** Before you handle a review, check for
  the `mcp__roborev-pane__explain` tool; a tool that is listed but deferred
  counts as loaded — load its schema with `ToolSearch` first. When it is
  present, decisions go through the roborev pane: call `explain` with your
  per-finding analysis, then let the user decide with the pane's buttons. Fall
  back to `AskUserQuestion` only when the tool is absent, or when `explain`
  reports the pane could not parse the findings. Never pick `AskUserQuestion`
  because you have not yet loaded the deferred tool. The pane follows the job
  by itself, so not seeing it is never a reason to fall back.
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
  into a summary with your verdicts already applied. At decision time the
  reviewer's complete text, untrimmed and unreworded, must be reachable on the
  decision surface itself: inside the decision prompt (the `AskUserQuestion`
  question text), or one action away on a surface built for it (the roborev
  pane's "Show roborev text" toggle). Only in the second case may your
  explanation lead in place of the verbatim text. Tool results and read files
  are not visible to the user, and message text written before a tool call in
  the same turn may not render — neither counts as reachable.

## Why

Roborev output is input for a shared decision, not a checklist to clear alone.
Silently deciding fix-vs-defer and looping reviews removes the user from their
own review process. Invoke the `/roborev` skill for the full interactive flow.
