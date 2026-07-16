---
paths:
  - "**/.gitlab-ci.yml"
  - "**/*.gitlab-ci.yml"
  - "**/templates/**/*.yml"
  - "**/templates/**/*.yaml"
  - "**/values.yaml"
  - "**/values.*.yaml"
---

# CI/GitOps Config: Diff First

Pipeline templates and GitOps values files have high blast radius (a bad
merge deploys, a bad rule silently skips CI) and the user regularly wants to
steer these edits before they land.

The `templates/` globs above overmatch (Helm charts, email templates): this
rule only applies when the file being edited is a pipeline definition or
GitOps values file — ignore it for unrelated templates.

## Rules

- **Show the proposed change as a diff in chat before applying it** to CI
  pipeline definitions (`.gitlab-ci.yml`, CI component `templates/*.yml`) or
  GitOps values files (`values.yaml` and variants). Apply after the user
  agrees, or after they've pre-approved the approach in this session.
- State in one sentence what the change does to pipeline/deploy behavior
  (which jobs/rules/environments it affects), not just what text changes.
- Trivial mechanical edits the user just dictated verbatim don't need a
  second confirmation — the rule targets edits where judgment was involved.
