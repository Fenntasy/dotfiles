# Skill Triggers

Routing table for skill selection. Always loaded — no path scoping, because intent-based routing must be available regardless of which files are open.

## File-pattern triggers

When editing files that match a pattern below, load the corresponding skill before making changes.

| File pattern                                           | Skill               | Why                                             |
| ------------------------------------------------------ | ------------------- | ----------------------------------------------- |
| `*.md`                                                 | `/markdown`         | Consistent formatting across all Markdown files |
| `docs/**`                                              | `/documentation`    | Doc structure, navigation, drift prevention     |
| `**/CLAUDE.md`, `.claude/**`, `claude/**`, `memory/**` | `/claude-authoring` | Config structure and authoring conventions      |
| `**/Dockerfile*`, `*.dockerfile`, `.dockerignore`      | `/dockerfile`       | Image security, build speed, and size decisions |
| `*.rs`, `**/Cargo.toml`                                | `/rust`             | API design, error handling, unsafe, perf idioms |
| `**/src-tauri/**`, `**/tauri.conf.json`                | `/tauri`            | Process model, IPC, security pattern, app size  |
| `*.elm`, `**/elm.json`                                 | `/elm`              | TEA, type design, module growth, interop        |

## Task-triggered skills

When the user's request matches an intent below, invoke the skill before starting work. Match on meaning, not exact keywords — examples are illustrative, not exhaustive.

| Skill               | Intent                                         | Example signals                                                                      |
| ------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------ |
| `/code-planning`    | Planning before implementation                 | "plan", "design the approach", "how should we"                                       |
| `/code-research`    | Evaluating approaches or sources               | "research", "compare options", "best practice"                                       |
| `/claude-authoring` | Writing or auditing Claude config              | "audit rules", "write a rule", "config hygiene"                                      |
| `/react`            | React components, hooks, error boundaries      | "add a component", "write a hook", "error boundary"                                  |
| `/react-router`     | Loaders, actions, mutations, URL state         | "add a loader", "write an action", "useFetcher", "URL state", "route data"           |
| `/typescript`       | Type safety, testing, build tooling            | "write a test", "fix type error", "bundle size"                                      |
| `/css-responsive`   | Responsive layout, Tailwind, touch             | "mobile layout", "responsive", "touch targets"                                       |
| `/ux-design`        | Design system, accessibility, form UX          | "design tokens", "a11y audit", "form validation UX"                                  |
| `/information-design` | Presenting one record's fields on a readable surface | "design this card", "present these fields", "too many labels", "make this detail view readable" |
| `/api-design`       | API contracts and HTTP semantics               | "design the endpoint", "status code", "pagination"                                   |
| `/domain-design`    | Domain modeling and schema changes             | "aggregate boundaries", "schema evolution"                                           |
| `/web-security`     | Security review or hardening                   | "security review", "add auth", "CORS", "harden"                                      |
| `/documentation`    | Doc audit, writing, or restructuring           | "audit docs", "update docs", "docs are stale", "revamp documentation"                |
| `/requirements`     | Clarifying what to build before implementation | "what should this do", "requirements", "acceptance criteria", "EARS", "user stories" |
| `/project-audit`    | Comprehensive project health audit             | "full audit", "audit the project", "check for drift", "are our rules still accurate" |
| `/frontend-design`  | Designing new pages, components, or visual UI  | "design this page", "make it look good", "style this", "new page UI", "visual direction" |
| `/roborev`          | Code review workflow, fixing findings, pre-push | "roborev", "review findings", "fix findings", "review before push"                   |
| `/ship`             | Deliver finished work: commit → review → push → MR/PR | "ship", "commit and review", "push and MR", "the usual routine", "let's commit" |
| `/nvim-config`      | Questions about the user's Neovim config        | "shortcut for", "how did I", "which LSP", "vim config", "neovim", "keymap for"       |
| `/dockerfile`       | Writing/reviewing Dockerfiles, image hardening  | "Dockerfile", "base image", "alpine vs slim", "shrink the image", "multi-stage", "containerize", "docker build is slow", "distroless" |
| `/rust`             | Writing/reviewing Rust, crate API design        | "Rust", "crate", "cargo", "unsafe", "panic or Result", "Rust builder", "clippy", "cargo workspace", "Rust error type" |
| `/tauri`            | Tauri desktop apps, Rust core + webview         | "Tauri", "invoke() from the frontend", "Tauri command", "IPC", "webview", "isolation pattern", "src-tauri", "Tauri binary size" |
| `/elm`              | Writing/reviewing Elm, Model/Msg design         | "Elm", "Msg", "Elm update function", "Elm ports", "Elm decoder", "opaque type", "split this Elm module", "elm-review" |

## Composite workflows

Most real tasks need multiple skills. When a task matches a pattern below, load all listed skills — primary first.

| Task shape                      | Primary               | Also load                          | Trigger signals                                            |
| ------------------------------- | --------------------- | ---------------------------------- | ---------------------------------------------------------- |
| Full-stack feature (API + page) | project feature skill | `/api-design`, `/react-router`, `/react` | "add X feature", "new endpoint with UI"                    |
| API endpoint (no frontend)      | `/api-design`         | -                                        | "add endpoint", "new handler"                              |
| Frontend page with data         | `/react-router`       | `/react`, `/css-responsive`, `/frontend-design` | "new page", "add a route with data"                 |
| Design system work              | `/ux-design`          | `/css-responsive`                        | "update tokens", "theme", "component variants"             |
| Security hardening              | `/web-security`       | `/react-router`, `/react`                | "security audit", "pen test findings"                      |
| Testing campaign                | `/typescript`         | `/react`, `/react-router`                | "add test coverage", "write E2E tests"                     |
| Performance optimization        | `/typescript`         | `/css-responsive`                  | "bundle analysis", "lighthouse", "CLS"                     |
| Complex domain feature          | `/requirements`       | `/domain-design`, `/code-planning` | "new entity", "new domain concept", "multi-entity feature" |
| Tauri desktop app               | `/tauri`              | `/rust`, frontend skill (`/react`, ...) | "Tauri app", "desktop app", "add a Tauri command", "src-tauri"   |

For full-stack features: check the project's `CLAUDE.md` for an end-to-end feature skill (e.g., `/new-feature`) that orchestrates the pipeline order.

## Disambiguation

When intent is ambiguous, prefer the more specific skill:

- "Fix a bug" → investigate first, then load the skill matching the root cause layer
- "Refactor" → load the skill matching the code layer being refactored
- "Write tests" → `/typescript` (testing methodology), plus the layer-specific skill for context
