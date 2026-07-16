# Verification Against Reality

A fix that passes a synthetic check but fails on the user's real setup is not
done — it's a regression waiting for the user to find it.

## Rules

- **Verify against the real thing before declaring done.** A fix to a shell
  function, config, template, or UI must be exercised through the user's
  actual invocation, file, or app — not only a scratch example you wrote for
  the occasion. If the real input isn't accessible (secrets, private data),
  say so explicitly and hand the user the exact command to verify themselves.
- **Tests live in the repo, not the scratchpad.** When verification deserves
  a test, write a committed test file the project can re-run, not a
  throwaway check in a temp directory.
- **Never regress a deliberate choice while "improving" code.** Before
  removing, restricting, or hardening existing behavior, check `git log`/
  `git blame` on the lines and project memory: if the behavior looks
  intentional, ask before changing it. This applies doubly to review
  findings — a reviewer flagging intentional code gets a question, not a fix.
- **Visual changes need visual confirmation.** For UI/CSS/styling work,
  don't claim an effect from code reading alone — verify in the running
  app/preview, or state plainly that the change is unverified and what to
  look for.
- **Report honestly.** "Implemented but unverified" is an acceptable status;
  "done" when only a synthetic case passed is not.

## Why

Recurring failure mode: a hardening pass silently broke a working setup
because it was validated only against a fresh example; styling iterations
declared done that changed nothing visible; cleanups that undid choices the
user had made on purpose.
