# Shell

Bash tool hygiene. Applies globally — no path scoping, because shell commands run in every session.

## Rules

- Never prefix Bash commands with `cd <repo>` — the working directory persists between calls. Reserve `cd` for when the target genuinely changes.
- Never write file content through the shell (heredocs, `echo`/`printf` redirects) — use the Write/Edit tools. Shell-written files are where zsh corruption creeps in.

## zsh corruption

zsh treats `!` as history expansion. When file content passes through the shell, the escaping workaround leaves literal `\!` sequences in the written file (e.g. `[\!NOTE]`, `if (\!ok)`).

- After generating or bulk-editing files via shell commands, check for damage: `grep -rn '\\!' <files>`
- If found, fix the file — every `\!` should be `!`; the backslash is never intentional in Markdown or code
