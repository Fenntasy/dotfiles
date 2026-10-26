# Claude Config System

Two-tier model for organizing Claude instructions. Authoring methodology (structure, naming, path scoping, hygiene) lives in `/claude-authoring`.

## Rules

- **Rule** (`.claude/rules/` project, `claude/rules/` global; auto-loaded, optionally `paths:`-scoped) — "Must this hold even if nobody remembers to invoke it?"
- **Skill** (`claude/skills/<name>/SKILL.md`; on demand via `/name`) — "Is this a methodology I apply deliberately to a specific task?"
- Placement: "Would this rule make sense in a completely different repo?" Yes → global `claude/rules/`; no → project-local `.claude/rules/`
- One concern per rule file, 80-line limit, path-scope when possible
- **Global skills and rules must never reference project-local files** — use generic language like "check the project's `CLAUDE.md`"
- Load `/claude-authoring` before creating or editing any rule, skill, `CLAUDE.md`, or memory file
