---
name: tauri
description: >
  Tauri v2 core concepts for desktop apps built with a Rust core and a system
  webview frontend, distilled from the official Concept docs (v2.tauri.app/concept).
  Covers: crate architecture (tauri, tauri-runtime, WRY, TAO, tauri-build,
  tauri-codegen), the multi-process model (Core vs WebView), where state and
  business logic belong, IPC via Events and Commands, the Brownfield and Isolation
  security patterns, and binary-size configuration (Cargo profiles,
  removeUnusedCommands).
  Use when: starting or structuring a Tauri app, deciding what runs in Rust vs the
  frontend, designing frontend-to-core communication, choosing an IPC security
  pattern, or shrinking the shipped binary.
  Sources: v2.tauri.app/concept (architecture, process-model,
  inter-process-communication, size).
version: 1.0.0
date: 2026-09-09
user-invocable: true
---

# Tauri

Core concepts for [Tauri v2](https://v2.tauri.app/concept/): a toolkit that builds
desktop (and mobile) apps from a Rust core plus HTML/CSS/JS rendered in the
operating system's webview. Tauri ships no runtime and no bundled browser, so
binaries stay small and reversing them is non-trivial.

> **Scope boundary:** this skill covers the *concepts* that shape a Tauri app's
> architecture. It does not restate the API reference.
> - **Rust code quality** (errors, builders, unsafe, workspace layout) → **`/rust`**.
> - **Frontend code** → `/react`, `/typescript`, `/css-responsive` as applicable.
> - **Command signatures, capability/ACL files, plugin authoring, updater, tray,
>   mobile targets** live in the Tauri `develop/`, `security/`, and `reference/`
>   docs. Fetch those pages when implementing; the principles here tell you *where*
>   a piece belongs, not the exact API.

**What Tauri is not:** not a lightweight kernel wrapper (it drives WRY and TAO
directly for OS calls) and not a VM or virtualized environment.

---

## 1. Architecture

### 1.1 Core crates

| Crate                | Role                                                                                                   |
| -------------------- | ------------------------------------------------------------------------------------------------------ |
| `tauri`              | Holds everything together: runtimes, macros, utilities, API. Reads `tauri.conf.json` **at compile time**, injects scripts and polyfills, hosts the system-interaction API, manages updates. |
| `tauri-runtime`      | Glue between Tauri and the lower-level webview libraries.                                              |
| `tauri-macros`       | Macros for context, handler, and commands, built on `tauri-codegen`.                                   |
| `tauri-utils`        | Shared code: config parsing, platform-triple detection, CSP injection, asset management.               |
| `tauri-build`        | Applies macros at build time to wire the special features `cargo` needs.                               |
| `tauri-codegen`      | Embeds, hashes, and compresses assets and icons; parses `tauri.conf.json` and generates the `Config` struct. |
| `tauri-runtime-wry`  | Direct system-level interactions for WRY: printing, monitor detection, windowing tasks.                |

### 1.2 Upstream crates

- **TAO**: cross-platform window creation (Windows, macOS, Linux, iOS, Android). A
  fork of `winit` extended with menu bar and system tray.
- **WRY**: cross-platform webview rendering. Tauri uses it as the abstraction that
  decides which webview is used and how interactions happen.

### 1.3 Tooling

- **`@tauri-apps/api`** (TypeScript): `cjs`/`esm` endpoints the frontend imports to
  call and listen to the backend over webview message passing.
- **Bundler** (Rust): builds the app for macOS, Windows, Linux; usable outside Tauri.
- **`tauri-cli`** (`cli.rs`) with an npm wrapper (`cli.js`, via `napi-rs`).
- **`create-tauri-app`**: scaffolds a project with the chosen frontend framework.
- **`tauri-action`**: GitHub workflow building binaries for all platforms.
- **`tauri-vscode`**: editor integration.

### 1.4 Plugins

Plugins are mostly third party (some official). A plugin does three things:

1. Enables Rust code to do "something".
2. Provides interface glue for easy integration into an app.
3. Provides a JavaScript API for the Rust code.

Examples: `tauri-plugin-fs`, `tauri-plugin-sql`, `tauri-plugin-stronghold`. Reach
for a plugin before writing raw platform code; write one when the same Rust
capability plus JS glue would be reused across apps.

### 1.5 License

Tauri is MIT or Apache-2.0. If you repackage and modify it, verifying compliance
with all upstream licenses is your responsibility. A Software Bill of Materials is
published on FOSSA.

---

## 2. Process model

Tauri is multi-process, like Electron and modern browsers. Isolating components
into processes uses multi-core CPUs better, contains crashes, allows restarting a
process that reaches an invalid state, and, most importantly, lets each process get
**only the permissions it needs** (Principle of Least Privilege: the gardener gets
the garden key, not the house key).

### 2.1 The Core process

The Rust entry point and the **only** component with full OS access. It:

- creates and orchestrates windows, tray menus, and notifications through Tauri's
  cross-platform abstractions;
- routes **all** IPC, so messages can be intercepted, filtered, and manipulated in
  one central place;
- owns **global state** such as settings and database connections, which keeps
  state synchronized across windows and keeps business-sensitive data away from
  the frontend.

Rust was chosen because ownership guarantees memory safety at native performance.

### 2.2 The WebView process

Core does not render UI. It spawns WebView processes using the OS webview library:
Microsoft Edge WebView2 on Windows, WKWebView on macOS, webkitgtk on Linux. The
webview runs your HTML, CSS, and JS, so standard web tooling (e.g. Svelte + Vite)
applies.

The webview libraries are **dynamically linked at runtime, not bundled**. That's
why binaries are tiny, and why platform differences must be handled like in
traditional web development.

### 2.3 Where things belong

| Concern                                 | Put it in            | Why                                                    |
| --------------------------------------- | -------------------- | ------------------------------------------------------ |
| Secrets, credentials, tokens            | Core (Rust)          | Never handle secrets in the frontend                   |
| Business logic                          | Core, as much as possible | Smaller attack surface                            |
| Settings, DB connections, shared state  | Core                 | One source of truth across windows                     |
| Rendering, user interaction             | WebView              | It's the only thing the webview should do              |
| User input                              | Sanitize it, always  | Standard web security applies                          |
| Anything platform-specific in the UI    | Feature-detect       | The webview engine differs per OS                      |

---

## 3. Inter-Process Communication

Tauri IPC is **asynchronous message passing**: processes exchange serialized
requests and responses, like client-server on the web. Message passing beats shared
memory or direct function access because the recipient can reject or discard any
request. If Core judges a request malicious, it drops it and the function never runs.

Two primitives: **Events** and **Commands**.

### 3.1 Events

Fire-and-forget, one-way messages. Best for lifecycle events and state changes.
Unlike commands, events can be emitted by **both** the frontend and Core. Under the
hood events still use commands, and access to the events API is governed by the
Event permissions in the ACL.

Use an event when the sender doesn't need a reply: "settings changed", "download
progressed", "window ready".

### 3.2 Commands

An FFI-like abstraction over IPC messages. The primary API, `invoke`, resembles the
browser's `fetch`: the frontend calls a Rust function, passes arguments, and receives
data. The protocol is JSON-RPC-like, so **all arguments and return values must be
JSON-serializable**.

Because commands are still message passing, they don't inherit the security pitfalls
of real FFI.

Use a command when the frontend needs a result: "read config", "run query",
"save file".

### 3.3 Design rules that follow

- Model request/response as a command; model notification as an event.
- Keep command payloads plain data (`serde`-serializable structs), never handles or
  closures.
- Validate every command argument in Rust as untrusted input. The frontend is a
  webview that may run compromised dependencies.
- Return errors as data the frontend can act on; don't panic on bad input (see
  `/rust` §9.3 for panic vs `Result`).
- Only allow the commands you actually use in the capability/ACL files. This is
  both a security boundary and a size lever (§5.2).

---

## 4. Security patterns

Set via `app > security > pattern` in `tauri.conf.json`. Two patterns exist.

### 4.1 Brownfield (default)

The simplest pattern: be as compatible as possible with an existing web frontend,
requiring nothing beyond what a browser app would. Not *everything* that works in a
browser works out of the box, but most does. No additional options.

```json
{
  "app": {
    "security": {
      "pattern": { "use": "brownfield" }
    }
  }
}
```

### 4.2 Isolation

Injects a small, trusted JavaScript app (the **Isolation application**) between the
frontend and Core, in a sandboxed iframe, to **intercept and modify every IPC
message** before it reaches Core. It exists to protect against unwanted or malicious
frontend calls, above all **Development Threats**: the dozens-to-hundreds of nested
build-time and bundled dependencies a modern frontend carries.

**When:** Tauri highly recommends it whenever it can be used, which is always, since
it sees all messages including always-on APIs like Events. Use it to verify IPC
inputs are within expected bounds: a file read/write stays inside your app's
directories; an HTTP fetch only sets the `Origin` header you expect.

**How** a message travels:

1. Tauri's IPC handler receives a message.
2. IPC handler → Isolation application.
3. `[sandbox]` The hook runs and may modify the message.
4. `[sandbox]` Message is encrypted with AES-GCM using a key generated at each app
   start (so keys can't be extracted from a shipped version and reused).
5. `[encrypted]` Isolation application → IPC handler.
6. `[encrypted]` IPC handler → Core, which decrypts and proceeds normally.

**Cost:** encryption adds overhead versus Brownfield even with an empty hook, but
AES-GCM is fast and messages are small; only performance-sensitive apps will notice.
Key generation needs entropy, trivial on desktops. For headless WebDriver testing,
install an entropy service such as `haveged` if the OS lacks one (Linux ≥ 5.6 has
built-in generation).

**Limitations:** external files don't load correctly inside sandboxed iframes on
Windows, so Tauri inlines scripts relative to the isolation app at build time.
Plain `<script src>` includes work; **ES Modules do not**.

**Recommendation:** keep the Isolation application as simple as possible: minimal
dependencies, minimal build steps. Otherwise you've reintroduced the supply-chain
risk it exists to block.

Minimal isolation app, output to `../dist-isolation` next to the main frontend's
`../dist`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>Isolation Secure Script</title>
  </head>
  <body>
    <script src="index.js"></script>
  </body>
</html>
```

```js
window.__TAURI_ISOLATION_HOOK__ = (payload) => {
  // Validate or rewrite the payload here. This example only logs it.
  console.log('hook', payload);
  return payload;
};
```

```json
{
  "build": { "frontendDist": "../dist" },
  "app": {
    "security": {
      "pattern": {
        "use": "isolation",
        "options": { "dir": "../dist-isolation" }
      }
    }
  }
}
```

### 4.3 Choosing

| Situation                                                     | Pattern    |
| ------------------------------------------------------------- | ---------- |
| Prototype, tiny dependency tree, no sensitive APIs            | Brownfield |
| Any app exposing fs, http, shell, or custom commands with side effects | Isolation |
| Large frontend dependency graph                               | Isolation  |
| Extremely latency-sensitive IPC with a tightly audited frontend | Brownfield, deliberately |

---

## 5. App size

Tauri binaries are already small; these push further.

### 5.1 Cargo profile (`src-tauri/Cargo.toml`)

Stick to stable unless you're an advanced user.

```toml
[profile.dev]
incremental = true # Compile in smaller steps.

[profile.release]
codegen-units = 1 # Lets LLVM optimize better.
lto = true        # Link-time optimization.
opt-level = "s"   # Small binary. Use "3" for speed, "z" for smallest.
panic = "abort"   # Drops unwinding machinery.
strip = true      # Removes debug symbols.
```

Nightly additionally allows `trim-paths = "all"` (removes potentially privileged
paths from the binary) and profile `rustflags = ["-Cdebuginfo=0", "-Zthreads=8"]`
for faster compiles.

| Option          | Effect                                                                 |
| --------------- | ---------------------------------------------------------------------- |
| `incremental`   | Smaller compile steps (dev)                                            |
| `codegen-units` | Fewer units = slower compile, better optimization                      |
| `lto`           | Link-time optimization                                                 |
| `opt-level`     | `3` speed, `z` size, `s` in between                                    |
| `panic`         | `abort` removes unwinding                                              |
| `strip`         | Strip symbols/debuginfo                                                |
| `rpath`         | Hardcodes dynamic-library lookup info                                  |
| `trim-paths`    | Removes privileged path info (nightly)                                 |
| `rustflags`     | Per-profile compiler flags (nightly)                                   |

Note `panic = "abort"` interacts with `/rust` §9.3: any library panic now aborts the
whole app, so the "panic means stop" discipline matters doubly in a Tauri core.

### 5.2 Remove unused commands (`tauri.conf.json`)

```json
{
  "build": { "removeUnusedCommands": true }
}
```

Strips commands never allowed in your capability (ACL) files, so you don't pay for
what you don't use. To maximize it, list only the commands you use in the ACL rather
than relying on `default` permission sets.

- Requires `tauri@2.4`, `tauri-build@2.1`, `tauri-plugin@2.1`, `tauri-cli@2.4`.
- Does **not** account for ACLs added dynamically at runtime; verify those still work.
- Mechanism: `tauri-cli` sets the `REMOVE_UNUSED_COMMANDS` env var (to the
  `src-tauri` dir) so the build scripts of `tauri` and `tauri-plugin` derive the
  allowed list from the capability files, and `generate_handler` drops the rest.
  This variable is an implementation detail with no stability guarantee.

---

## 6. Checklist for a new Tauri app

- [ ] Secrets, DB connections, and settings live in the Rust core, never in the webview
- [ ] Business logic is in Rust; the frontend renders and collects input
- [ ] Every command validates its arguments as untrusted input and returns data errors
- [ ] Request/response uses commands; notifications use events
- [ ] Command payloads are plain JSON-serializable structs
- [ ] Capability files allow only the commands and events actually used
- [ ] Isolation pattern enabled unless there's a documented reason not to
- [ ] Isolation app has no dependencies and no build step beyond inlining
- [ ] Release profile sets `lto`, `codegen-units = 1`, `opt-level = "s"`, `panic = "abort"`, `strip`
- [ ] `removeUnusedCommands` enabled and dynamic ACLs re-tested
- [ ] Platform-specific webview behavior feature-detected, not assumed

## 7. Anti-patterns

| Anti-pattern                                         | Fix                                                        |
| ---------------------------------------------------- | ---------------------------------------------------------- |
| API key stored in frontend state or env at build     | Keep it in the core; expose a command that uses it         |
| Frontend does the work, Rust is a thin file proxy    | Move logic into the core; commands return results          |
| Command that takes an arbitrary path and reads it    | Validate against app directories (in Rust, and in the isolation hook) |
| Using an event where the caller awaits a result      | Use a command                                              |
| Polling a command for state changes                  | Emit an event from the core                                |
| `default` permission sets in capabilities             | Enumerate the used commands                                |
| Bundling a webview or runtime "for consistency"      | Tauri's model is the OS webview; handle differences instead |
| Isolation app built with a full bundler and deps     | Keep it a single plain script                              |
| ES Module in the isolation app                       | Classic `<script src>`; inlined at build time              |
| Treating IPC as trusted because it's "our frontend"  | Frontend deps are a supply chain; validate in Rust         |
