---
name: rust
description: >
  Pragmatic Rust design guidelines for libraries and applications, distilled from
  Microsoft's Rust Guidelines (version 2026.6) which build on the upstream Rust API
  Guidelines. Covers: static verification and lint sets, naming, structured logging,
  library interoperability (Send, AsRef, sans-IO), library UX (errors, builders,
  services, modules), resilience (mocking, strong types, statics), features,
  macros, application setup (mimalloc, anyhow, target-cpu), FFI, unsafe/soundness,
  panics, performance, workspace layout, rustdoc conventions, AI-friendly design.
  Use when: writing or reviewing Rust code, designing a crate's public API,
  structuring a workspace, handling errors, deciding panic vs Result, using unsafe,
  or optimizing a hot path.
  Sources: microsoft.github.io/rust-guidelines, rust-lang.github.io/api-guidelines.
version: 1.0.0
date: 2026-09-09
user-invocable: true
---

# Rust

Design guidelines for idiomatic Rust that scales, distilled from Microsoft's
[Pragmatic Rust Guidelines](https://microsoft.github.io/rust-guidelines/) (v2026.6).
Each item keeps its source id (`M-XXX`) so you can look up the full rationale.

**The golden rule:** each item exists for a reason, and it is the spirit that counts,
not the letter. Understand *why* a guideline exists before working around it, and
don't follow one blindly when doing so would violate its motivation. Items worded
*must* always hold; *should* items allow flexibility.

> **Scope boundary:** this skill covers Rust design and API conventions.
> - **Tauri desktop apps** (process model, IPC, commands, capabilities) → **`/tauri`**.
> - **Formatting** is `rustfmt`'s job, not covered here.
> - **Upstream guidelines are assumed** (M-UPSTREAM-GUIDELINES): the
>   [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/checklist.html),
>   [Style Guide](https://doc.rust-lang.org/nightly/style-guide/),
>   [Design Patterns](https://rust-unofficial.github.io/patterns/), and the
>   [Reference on UB](https://doc.rust-lang.org/reference/behavior-considered-undefined.html).
>   Frequently forgotten upstream items: `C-CONV` (`as_`/`to_`/`into_`), `C-GETTER`,
>   `C-COMMON-TRAITS` (eagerly derive `Copy, Clone, Eq, PartialEq, Ord, PartialOrd,
>   Hash, Default, Debug`), `C-CTOR` (have `Foo::new()` even with `Default`), `C-FEATURE`.

---

## 1. Universal

### 1.1 Static verification (M-STATIC-VERIFICATION)

Run these locally and in check-in gates: compiler lints, clippy, `rustfmt`,
`cargo-audit` (vulnerabilities), `cargo-hack` (feature combinations), `cargo-udeps`
(unused deps), `miri` (unsafe correctness).

Enable these compiler lints beyond the defaults:

```toml
[lints.rust]
ambiguous_negative_literals = "warn"
missing_debug_implementations = "warn"
redundant_imports = "warn"
redundant_lifetimes = "warn"
trivial_numeric_casts = "warn"
unsafe_op_in_unsafe_fn = "warn"
unused_lifetimes = "warn"
```

Enable all major clippy groups plus selected `restriction`/`nursery` lints, then opt
out case by case:

```toml
[lints.clippy]
cargo = { level = "warn", priority = -1 }
complexity = { level = "warn", priority = -1 }
correctness = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
perf = { level = "warn", priority = -1 }
style = { level = "warn", priority = -1 }
suspicious = { level = "warn", priority = -1 }
# nursery = { level = "warn", priority = -1 }  # optional, more false positives

allow_attributes_without_reason = "warn"
as_pointer_underscore = "warn"
assertions_on_result_states = "warn"
clone_on_ref_ptr = "warn"
deref_by_slicing = "warn"
disallowed_script_idents = "warn"
empty_drop = "warn"
empty_enum_variants_with_brackets = "warn"
empty_structs_with_brackets = "warn"
fn_to_numeric_cast_any = "warn"
if_then_some_else_none = "warn"
map_err_ignore = "warn"
redundant_type_annotations = "warn"
renamed_function_params = "warn"
semicolon_outside_block = "warn"
undocumented_unsafe_blocks = "warn"
unnecessary_safety_comment = "warn"
unnecessary_safety_doc = "warn"
unneeded_field_pattern = "warn"
unused_result_ok = "warn"
too_long_first_doc_paragraph = "warn"

# Conflicts with structured logging message templates otherwise.
literal_string_with_formatting_args = "allow"
```

### 1.2 Lint overrides use `#[expect]` (M-LINT-OVERRIDE-EXPECT)

Override project lints with `#[expect(..., reason = "...")]`, not `#[allow]`. An
expected lint warns when it no longer fires, so stale overrides can't accumulate.
`#[allow]` remains fine for generated code and inside macros.

```rust
#[expect(clippy::unused_async, reason = "API fixed, will use I/O later")]
pub async fn ping_server() {}
```

### 1.3 Public types are `Debug` and, when readable, `Display` (M-PUBLIC-DEBUG, M-PUBLIC-DISPLAY)

- Every public type implements `Debug`, usually via derive.
- Types holding sensitive data implement `Debug` by hand, redacting the payload,
  **and** have a unit test asserting the secret never appears in the rendered output.
- Types meant to be read (errors, string-like wrappers) implement `Display`, following
  Rust customs for newlines and escapes. The same redaction rule applies.

```rust
impl Debug for UserSecret {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        write!(f, "UserSecret(...)")
    }
}

#[test]
fn debug_does_not_leak() {
    let key = "552d3454-d0d5-445d-ab9f-ef2ae3a8896a";
    let rendered = format!("{:?}", UserSecret(key.to_string()));
    assert!(rendered.contains("UserSecret"));
    assert!(!rendered.contains(key));
}
```

### 1.4 If in doubt, split the crate (M-SMALLER-CRATES)

Err toward too many crates. If a submodule can be used independently, make it a
crate: compile times drop dramatically and cyclic dependencies become impossible.
Losing `pub(crate)` access in the split is usually a prompt to design a better
abstraction.

**Crates vs features:** crates are for things usable on their own; features unlock
extra functionality that can't stand alone. Prefer `web_server`, `web_client`,
`web_protocols` over one `web` crate with `server`/`client`/`protocols` modules.
Umbrella crates re-joining pieces are fine; always re-export pieces split for purely
technical reasons (e.g. `foo_proc`), otherwise re-export sparingly.

### 1.5 Naming (M-WEASEL-WORDS, M-SHORT-NAMES)

- No weasel words: `Service`, `Manager`, `Factory`. A thing handling bookings is
  `Bookings`; if it dispatches them, `BookingDispatcher`. Lifecycle is `Drop`'s job,
  not a manager's. The Rust name for a factory is `Builder`; to accept repeatable
  construction, take `impl Fn() -> Foo`, not a builder.
- Identifiers compound at most 2 short words (`AppConfig`, not
  `GlobalApplicationConfig`).
- Don't bake the module into the name (`foo::Id`, not `foo::FooId`); callers
  disambiguate with paths (`fn convert(foo::Id) -> bar::Id`).
- Prefer abbreviations (`CallbackFn` over `CallbackFunction`).

### 1.6 Prefer regular over associated functions (M-REGULAR-FN)

Associated functions are for instance creation. Computation with no clear receiver
is a free function, not `Type::helper(...)`. Trait associated functions (`Default::default`)
are of course idiomatic.

```rust
impl Database {
    fn new() -> Self {}        // ok: constructor
    fn query(&self) {}         // ok: method
    fn check_parameters(p: &str) {} // WRONG: unrelated to Database
}
fn check_parameters(p: &str) {}    // CORRECT
```

### 1.7 Magic values are documented (M-DOCUMENTED-MAGIC)

Hardcoded values get a comment covering why the value, non-obvious side effects of
changing it, and external systems that depend on it. Prefer a named `const` with a
doc comment over an inline literal.

```rust
/// How long we wait for the server.
///
/// Large enough for the server to finish. Too low and we abort valid
/// requests. Based on `api.foo.com` timeout policies.
const UPSTREAM_SERVER_TIMEOUT: Duration = Duration::from_secs(60 * 60 * 24);
```

### 1.8 Structured logging with message templates (M-LOG-STRUCTURED)

- No `format!` in log calls; use named properties and a message template with
  `{{property}}` placeholders so formatting is deferred to view time.
- Name events hierarchically: `<component>.<operation>.<state>`.
- Use [OpenTelemetry semantic conventions](https://opentelemetry.io/docs/specs/semconv/)
  for common attributes (`http.request.method`, `file.path`, `db.operation.name`,
  `error.type`, ...).
- Redact sensitive data (emails, identifying paths, tokens, PII) before logging.

```rust
// WRONG
tracing::info!("file opened: {}", path);

// CORRECT
event!(
    name: "file.open.success",
    Level::INFO,
    file.path = path.display(),
    "file opened: {{file.path}}",
);
```

---

## 2. Libraries: interoperability

### 2.1 Types are `Send` (M-TYPES-SEND)

All futures your crate produces must be `Send`; most other public types should be.
A `!Send` type held across an `.await` infects the future. Assert it at compile time
for explicit futures and main entry points:

```rust
const fn assert_send<T: Send>() {}
const _: () = assert_send::<MyFuture>();
```

A type may be `!Send` if its default use is instantaneous and never held across
`.await`. The cost of atomics is negligible unless touched more often than every
~64 words, so `Send` buys ecosystem compatibility for nearly free.

### 2.2 Native escape hatches (M-ESCAPE-HATCHES)

Types wrapping native handles provide `unsafe fn from_native(h)` (with documented
safety requirements) plus `into_native(self)` / `to_native(&self)`, so users can
interop with handles obtained elsewhere or pass yours over FFI.

### 2.3 Don't leak external types; items come from their original crate (M-DONT-LEAK-TYPES, M-FOREIGN-REEXPORTS)

Prefer `std` types in public APIs. Leaking a third-party type makes it part of your
contract. Heuristic:

- Avoid if you can.
- Umbrella crate siblings may freely leak each other's types.
- Behind a feature flag, leaking is acceptable (e.g. `serde`).
- Without a feature, only for substantial ecosystem interoperability.

Don't `pub use bar::Url` from `foo`; users depend on `bar` directly. Exceptions:
umbrella crates, technical splits (`foo_core::Url` from `foo`), and hidden
`_private` macro paths.

### 2.4 Accept `impl AsRef<T>`, `impl RangeBounds<T>`, `impl Read` (M-IMPL-ASREF, M-IMPL-RANGEBOUNDS, M-IMPL-IO)

In **function** signatures, where ownership isn't needed or construction is cheap:

| Instead of         | accept             |
| ------------------ | ------------------ |
| `&str`, `String`   | `impl AsRef<str>`  |
| `&Path`, `PathBuf` | `impl AsRef<Path>` |
| `&[u8]`, `Vec<u8>` | `impl AsRef<[u8]>` |

If the function wants ownership on a hot path, take `String`/`Vec<u8>` directly.
**Types** should not carry these bounds (`struct User { name: String }`, not
`struct User<T: AsRef<str>>`).

Ranges: never `(low, high)` parameters. Use `impl RangeBounds<T>` when any range
works (`select(1..3)`, `select(1..)`, `select(..)`), `Range<T>` only when required.

Sans-IO: one-shot I/O during initialization takes `impl std::io::Read`/`Write`
(sync) or `futures::io::AsyncRead` (async, runtime-agnostic), not a `File`. Types
doing continuous runtime-specific I/O follow the runtime-abstraction enum pattern
in §4.1.

---

## 3. Libraries: UX

### 3.1 Abstractions don't visibly nest; no wrappers in APIs (M-SIMPLE-ABSTRACTIONS, M-AVOID-WRAPPERS)

Service-like types users must name should not require nested type parameters:
`Service` great, `Service<Backend>` acceptable, `Service<Backend<Store>>` bad. If
`Foo<T>` users bring their own `A<B<C>>` as `T`, fine. Containers naturally expose
`T`, but limit count and nesting. Consider: will users name the type, does it compose
with non-user types, do the bounds get complex, do parameters affect inference?

Keep `Rc<T>`, `Arc<T>`, `Box<T>`, `RefCell<T>` out of public signatures; accept
`&T`, `&mut T`, or `T`. Acceptable only when the pointer *is* the API (a container
lib) or benchmarks justify it.

```rust
// CORRECT
pub fn process_data(data: &Data) -> State {}
// WRONG
pub fn process_shared(data: Arc<Mutex<Shared>>) -> Box<Processed> {}
```

### 3.2 Types over generics, generics over `dyn Trait` (M-DI-HIERARCHY)

Don't port `IDatabase` interfaces 1:1 into `Rc<dyn Database>`. Escalation ladder:

1. Only need a test double → make the type an enum (§4.1), no trait.
2. Users provide implementations → narrow traits (`StoreObject`, `LoadObject`)
   implemented *on top of* inherent fns; combine as subtrait `DataAccess: StoreObject + LoadObject`.
3. Accept traits as generics: `async fn read(x: impl LoadObject)`; `struct Svc<T: DataAccess>`
   is acceptable until nesting gets excessive.
4. Only when generics cause nesting problems, use `dyn Trait` behind your own wrapper
   (`struct DynamicDataAccess(Arc<dyn DataAccess>)`), optionally as an enum variant.

### 3.3 Errors are canonical structs (M-ERRORS-CANONICAL-STRUCTS)

Errors are situation-specific `struct`s holding a `Backtrace`, an optional upstream
cause, and helper methods. One `Error` for simple crates; `AccessError`,
`ConfigurationError`, ... for complex ones. Reuse where reasonable (`ParseError` for
both JSON and TOML), don't create one `GlobalEverythingErrorEnum`.

- If mixing operations, store a **private** `ErrorKind` and expose `is_io()`,
  `is_protocol()` predicates. Don't expose the enum: it commits you to every internal
  failure mode.
- Capture `Backtrace::capture()` in `Error::new` or `From<Upstream>` impls. Capture
  is nearly free unless `RUST_BACKTRACE` is set.
- `Display` prints a summary sentence, the backtrace, and upstream cause.
- Implement `std::error::Error`.
- Many errors? Add a private `bail!()` helper macro.

```rust
#[derive(Debug)]
pub(crate) enum ErrorKind { Io(std::io::Error), Protocol }

#[derive(Debug)]
pub struct HttpError { kind: ErrorKind, backtrace: Backtrace }

impl HttpError {
    pub fn is_io(&self) -> bool { matches!(self.kind, ErrorKind::Io(_)) }
    pub fn is_protocol(&self) -> bool { matches!(self.kind, ErrorKind::Protocol) }
}
```

### 3.4 Error conversion uses `From`, not `map_err` (M-FROM-ERROR)

For your own error types, `impl From<Upstream> for MyError` once and let `?` apply
it. `map_err` is only for foreign error types or when adding context.

```rust
// WRONG: repeated at every call site
let bytes = read("config.toml").map_err(|e| MyError::Io(e))?;
// CORRECT: impl From<std::io::Error> for MyError, then
let bytes = read("config.toml")?;
```

### 3.5 Builders and cascaded construction (M-INIT-BUILDER, M-INIT-CASCADED, M-BUILD-RESULT)

- Up to 2 optional parameters: inherent constructors (`new`, `with_a`, `with_a_b`).
- 4+ permutations: a builder named `FooBuilder`, reached via `Foo::builder()`, with
  no public `FooBuilder::new()`. Setters are chainable and named `x()`, not `set_x()`.
  Final method is `.build()`.
- Required parameters go into the builder constructor, ideally via a deps struct:
  `Foo::builder(deps: impl Into<FooDeps>)` accepting `logger`, `(logger, config)`,
  or `FooDeps { .. }`. Runtime-specific variants: `builder_tokio(deps)`, `builder_smol(deps)`.
- Setters never fail; validate in `.build() -> Result<Foo, _>` so cross-field checks
  live in one place.
- 4+ parameters on any constructor: group semantically into helper types
  (`Deposit::new(account: Account, amount: Currency)`), and check `C-NEWTYPE`.

```rust
// WRONG
Foo::builder().name("Foo")?.distance(42)?.build();
// CORRECT
Foo::builder().name("Foo").distance(42).build()?;
```

### 3.6 Services are `Clone` (M-SERVICES-CLONE)

Heavyweight services and thread singletons implement shared-ownership `Clone` via
the `Arc<Inner>` pattern, so dependents can take `&Service`, clone a handle, and
store it. `Clone` must never deep-copy the service.

```rust
struct ServiceCommonInner {}

#[derive(Clone)]
pub struct ServiceCommon { inner: Arc<ServiceCommonInner> }

impl ServiceCommon {
    pub fn foo(&self) { self.inner.foo() }
}
```

### 3.7 Essential functionality is inherent (M-ESSENTIAL-FN-INHERENT)

Core methods live in `impl Type`; trait impls forward to them. Users shouldn't hunt
for the trait to `use` before a type works.

### 3.8 Modules, preludes, re-exports (M-BALANCED-MODULES, M-NO-PRELUDE, M-NO-GLOB-REEXPORTS, M-SINGLE-ITEM-PATH)

- Menu-design your modules: a reasonable number of essential items in the crate root
  (a `foo_client` crate has `Client` at root), the rest grouped by use case
  (`account`, `network`, `status`), never `traits` or `errors` buckets. Avoid both
  flat roots with dozens of items and roots with nothing in them.
- Never define a `prelude` or anything meant for `use foo::*`. Multiple preludes
  collide (`Client is ambiguous`). Wanting one signals a module design problem.
- Never `pub use foo::*`; re-export items individually. The only accepted glob is
  platform HAL forwarding (`#[cfg(target_os = "windows")] pub use windows::*;`).
- Each public item is reachable through exactly one path. `crate::db::Connection`
  must not also be `crate::Connection` unless `db` is `pub(crate)`. Agents violate
  this constantly by keeping old paths alive during refactors: redesign instead.

### 3.9 Parameter ordering, collections, async fns (M-PARAMETER-CONSISTENCY, M-COLLECTION-TRAITS, M-ASYNC-FN)

- Same conceptual parameters appear in the same order everywhere: call-specific
  first, ubiquitous ones (`&logger`) last, closures last (at most one closure).
- A custom `Collection<T>` ships `IntoIter`, `Iter`, `IterMut` structs with
  `Iterator` impls; `iter()`/`iter_mut()`; `IntoIterator` for `C`, `&C`, `&mut C`;
  `FromIterator`; `Extend`; `DoubleEndedIterator`/`ExactSizeIterator` as applicable;
  truthful `size_hint()`.
- Write `async fn foo() -> Result<T, E>` over `fn foo() -> impl Future<...>`. The
  explicit form is only for traits or hot futures (§9.9).

---

## 4. Libraries: resilience

### 4.1 I/O and syscalls are mockable (M-MOCKABLE-SYSCALLS)

Anything non-deterministic, environment-dependent, or externally stateful (files,
network, clocks, entropy) must be mockable. Libraries therefore don't do ad-hoc
`read("foo.txt")`, don't build their own I/O core, and don't offer
`MyIoLibrary::default()`. Either accept a mockable core (`Library::new_runtime(io)`)
or provide inherent mocking that returns the controller as a tuple:

```rust
impl Library {
    pub fn new() -> Self {}
    pub fn new_mocked() -> (Self, MockCtrl) {}  // CORRECT: no shared-controller ambiguity
}

enum LibraryCore {
    Native,
    #[cfg(feature = "test-util")]
    Mocked(mock::MockCtrl),  // MockCtrl follows the Arc<Inner> Clone pattern
}
```

Runtime-aware libraries extend their `enum Runtime { Tokio(..), Smol(..), Mock(..) }`.
Allocations are considered deterministic and infallible; still, memory-hungry code
handling external input should offer bounded or chunked operations.

### 4.2 Test utilities are feature gated (M-TEST-UTIL, M-INTEGRATION-TESTS)

Mocking, sensitive-data inspection, safety-check bypasses, and fake data generation
sit behind one feature, `test-util`. Production builds can't reach them.

Tests touching only public API are integration tests and live in `tests/`, not
`mod tests {}`. Prefer an integration test whenever either would do; `src/` should
not be mostly test code.

### 4.3 Strong types guard invariants (M-STRONG-TYPES, M-STRONG-TYPES-GUARD)

Use the strongest `std` type as early as possible: OS paths are `Path`/`PathBuf`,
never `String`. Public numeric boundaries stay plain numbers, not `NonZero<usize>`.

A newtype encoding an invariant (non-empty string, port, percentage, month) enforces
it itself, once, at construction:

- at least one fallible constructor (`from_u8(v) -> Result<Self, _>`);
- panicking constructors (`new`) allowed, preferably `const` so
  `const { Month::new(14) }` fails at compile time;
- conversions from weaker types are `TryFrom`/`FromStr`, never infallible `From`;
- no `pub` inner field.

```rust
// WRONG: every caller re-checks 1..=12
pub struct Month(pub u8);
// CORRECT
pub struct Month(u8);
impl Month { pub fn from_u8(v: u8) -> Result<Self, DateError> {} }
```

### 4.4 Avoid statics (M-AVOID-STATICS)

No `static` or thread-local when a consistent view matters for correctness. Cargo
may link several versions of your crate (especially during `0.x`), each with its own
copy of the static, so a "global" counter can report 2, 3, and 5 simultaneously.
Statics purely for performance caches are fine.

### 4.5 Telemetry, not `println` (M-LOG-NOT-PRINT)

Production paths emit through the telemetry framework, never `println!`/`dbg!`.
Stdout is reserved for CLIs where it *is* the interface.

---

## 5. Libraries: building

### 5.1 Libraries work out of the box (M-OOBE, M-SYS-CRATES)

`cargo build` must succeed on all Tier 1 platforms with nothing beyond `cargo`
and `rustc` (a linker and `cc` are assumed present). No required env vars, no
external tools: run codegen (e.g. from `.proto`) at publish time and ship the
generated `.rs`. Platform-specific deps go behind `cfg` or opt-in features. You are
responsible for your dependencies' OOBE too. If a Tier 1 platform is unsupported
"for now", keep a HAL module with a `dummy` fallback so it can be added.

`-sys` crates: vendor or pre-generate everything, pre-generate `bindgen` glue,
support static and `libloading` dynamic linking. Downloaded sources need crates.io-grade
availability, pinned hashes, and an env-var override for hermetic builds.

### 5.2 Features are additive (M-FEATURES-ADDITIVE)

Any feature combination must compile. Therefore:

- a `std` feature, never a `no-std` feature;
- enabling a feature never removes or changes a public item (adding variants is fine
  on `#[non_exhaustive]` enums);
- no feature depends on another being enabled manually, or on a parent skip-enabling
  a child's feature.

---

## 6. Macros

- **Last resort** (M-MACRO-LAST-RESORT): "macros are for when you run out of
  language." They're opaque, slow compilation, and break at edition boundaries. The
  ideal macro makes users think "I know exactly what this generates, I just don't
  want to type it."
- **Macros by example over proc macros** (M-EXAMPLE-OVER-PROC): `make_new_id!(MyId)`
  beats `#[make_new_id] struct MyId;` when it suffices.
- **Don't lie about signatures** (M-MACROS-DONT-LIE): never turn structs into enums,
  change function signatures, add parameters, or flip `async`-ness.
- **Assume the main crate** (M-MACRO-MAIN-CRATE): emit `::foo::...` paths; don't
  support use through `foo_proc` directly or under a renamed import.
- **Third-party items via `_private`** (M-MACRO-HELPERS): `#[doc(hidden)] pub mod
  _private { pub use ::bar::Bar; }` and emit `::foo::_private::Bar`.
- **Separate impl crate** (M-PROC-IMPL): `foo_proc` is a thin `proc_macro` shim over
  `foo_proc_impl` (a normal crate with `proc_macro2` and `insta` snapshot tests);
  `foo` re-exports the macro and adds `trybuild` UI tests for error messages.
- **No implied or hidden items** (M-PROC-IMPLIED-ITEMS): don't emit extra public
  types; they clash with user names and are invisible at source level. The one
  acceptable trick is the Rocket-style same-name-different-namespace
  `fn foo` + `struct foo` inside root crates.

---

## 7. Applications

- **mimalloc** (M-MIMALLOC-APPS): up to 25% gains on allocating hot paths.

  ```rust
  use mimalloc::MiMalloc;
  #[global_allocator]
  static GLOBAL: MiMalloc = MiMalloc;
  ```

- **Application errors may use anyhow/eyre/ohno** (M-APP-ERROR): pick one, use it
  for every app-level error, never mix. Any crate used by more than one crate is a
  library and follows §3.3 instead.
- **Highest viable `target-cpu`** (M-TARGET-CPU): server apps set e.g.
  `rustflags = ["-C", "target-cpu=x86-64-v3"]` per target in `.cargo/config.toml`.
  Ignored for libraries.

---

## 8. FFI

- **Isolate DLL state** (M-ISOLATE-DLL-STATE): each Rust DLL has its own statics,
  its own `#[repr(Rust)]` layouts, and its own `TypeId`s. Only *portable* data
  crosses DLL boundaries: `#[repr(C)]`, no interaction with statics/thread-locals or
  `TypeId`, no pointers to non-portable data. `String`, `Vec`, `Box<Foo>`, anything
  relying on `tokio`/`log` statics, and any non-`repr(C)` struct are not portable.
  Watch for methods that *look* like they run in DLL2 but execute DLL1's code on
  DLL2's data.
- **Core crate holds logic, FFI only translates** (M-FFI-TRANSLATES): `foo` is
  idiomatic safe Rust; `foo-ffi` converts pointers and lengths to `foo` types and back.
  Never let `#[repr(C)]` or raw pointers into `foo`'s data model.
- **Naming** (M-FFI-NAMING): `-sys` imports an existing C library; `-ffi` exports
  C-style items for other applications.

---

## 9. Correctness: unsafe, soundness, panics

### 9.1 Unsafe needs a reason (M-UNSAFE, M-UNSAFE-IMPLIES-UB)

The only valid reasons: novel abstractions (a new smart pointer or allocator),
benchmarked performance (`get_unchecked`), and FFI/platform calls. Never ad-hoc
`unsafe` to shorten safe code (`transmute` enum casts), bypass `Send` (`unsafe impl
Send`), or dodge lifetimes.

Every use: plain-text safety reasoning, pass Miri, follow the
[Unsafe Code Guidelines](https://rust-lang.github.io/unsafe-code-guidelines/).
Novel abstractions must also be minimal, testable, and hardened against adversarial
code (closures that panic, misbehaving `Deref`/`Clone`/`Drop`). FFI should use an
established interop library and document permissible call patterns for bindings.

`unsafe` marks only functions and traits whose misuse risks **undefined behavior**.
`unsafe fn delete_database()` is wrong: dangerous is not unsafe.

### 9.2 All code must be sound. No exceptions. (M-UNSOUND)

A function is unsound if it is not marked `unsafe` but *any* calling mode, however
contrived, causes UB. If you can't encapsulate safely, expose `unsafe fn` and
document the contract. Soundness boundaries equal **module** boundaries: a safe
method may rely on invariants guaranteed elsewhere in the same module.

```rust
// WRONG: unsound "safe" functions
fn unsound_ref<T>(x: &T) -> &u128 { unsafe { std::mem::transmute(x) } }
struct AlwaysSend<T>(T);
unsafe impl<T> Send for AlwaysSend<T> {}
```

### 9.3 Panic means "stop the program" (M-PANIC-IS-STOP, M-PANIC-ON-BUG, M-PANIC-CONTINUATION, M-PANIC-MESSAGE)

Panics are not exceptions. The caller may have `panic = "abort"`. Never use panics
to communicate errors upstream, handle self-inflicted conditions, or assume they'll
be caught. Valid panic triggers: detected programming errors, const contexts, a
user-requested `unwrap()`, poisoned locks.

| Situation                                    | Do                                     |
| -------------------------------------------- | -------------------------------------- |
| Contract violation detected (`divide_by(x, 0)`) | `panic!` with values; no `Error` type  |
| Inherently fallible input (`parse_uri(&str)`) | return `Result`                        |
| Check too expensive                          | may skip it, return unspecified (never undefined) result |
| Otherwise-panicking user input               | prefer a type that makes it unrepresentable |

`catch_unwind` is a last resort followed by a controlled restart; a caught panic can
leave invariants half-updated. Per-request `catch_unwind` in servers is acceptable
to let in-flight requests finish, then restart.

Every intentional panic (`panic!`, `assert!`, `unreachable!`, `todo!`) carries a
message with the reason and relevant values:

```rust
// WRONG
assert!(buffer.len() >= HEADER_SIZE);
// CORRECT
assert!(buffer.len() >= HEADER_SIZE,
    "buffer too small for header: got {} bytes, need {HEADER_SIZE}", buffer.len());
```

---

## 10. Performance

- **Throughput over empty cycles** (M-THROUGHPUT): key metric is items per CPU cycle.
  Partition work ahead of time, let tasks own their slice, batch APIs, sleep when idle,
  exploit cache locality. Don't hot-spin, process single items when batching is
  possible, or work-steal individual items. Share state only when sharing is cheaper
  than recomputing.
- **Profile the hot path early** (M-HOTPATH): decide early if the crate is
  performance-relevant; benchmark with `criterion`/`divan`, profile CPU and
  allocations regularly, set `[profile.bench] debug = 1`, document hot spots.
  Common wins: fewer `String` re-allocations and clones, fewer short-lived
  allocations, less re-hashing, a non-default hasher.
- **Yield points** (M-YIELD-POINTS): CPU-bound async loops without I/O call
  `yield_now().await` every 10-100μs of work, or consult the runtime's budget API.
- **Reuse allocations** (M-MEM-REUSE): core APIs let callers own and reuse buffers
  (`db.get_in(id, &mut value)`, `.clear()`); allocation-per-call APIs are auxiliary.
  Deep libraries can thread an arena through the call stack.
- **Telemetry doesn't tank throughput** (M-LOG-OVERHEAD): keep hot inner loops free
  of emission; otherwise emit lightweight, allocation-free events, or log the batch
  and let users reconstruct offline.
- **Avoid needless indirection** (M-AVOID-INDIRECTION): don't reflexively
  `Arc` nested types; embed locally and lift hot cacheable fields
  (`enabled: bool` next to `payload`) instead of chasing `config.feature.is_enabled()`.
- **Boxed slices for immutable owned sequences** (M-BOX-DST): frequently
  instantiated, immutable, non-user-visible sequences are `Box<[T]>`/`Box<str>`/
  `Arc<str>`, dropping the capacity word (`Vec<Box<str>>` over `Vec<String>`).
- **`shrink_to_fit` long-lived growable collections** (M-SHRINK-TO-FIT) built
  without exact reservation; `into_boxed_*` already does this.
- **Fast hasher for trusted keys** (M-FAST-HASHER): `foldhash`/`FxHash` over the
  DoS-resistant default when keys can't be attacker-crafted.
- **Initial capacity** (M-INITIAL-CAPACITY): `with_capacity(n)` when size is known;
  better, `.collect()` which inherits `size_hint`.
- **Hot async fns reduce stack size** (M-ASYNC-STACK-SIZE): everything held across
  `.await` (and all parameters) becomes part of the future type. Track hot futures
  with `size_of_val` in a test; shrink by returning `impl Future`, processing args
  outside the `async` block, using `Either`, and chaining with future combinators.

---

## 11. Project layout

- **Workspace `Cargo.toml` owns shared settings** (M-CARGO-WORKSPACE): members
  inherit metadata, `[workspace.dependencies]`, `[workspace.lints]`. Define even
  crate-specific deps in the workspace, with `default-features = false` and only
  basic features like `["std"]`.
- **Workspace lists and versions all crates** (M-CRATES-IN-WORKSPACE):
  `sibling.workspace = true` in members; `sibling = { path = "crates/sibling", version = "0.5.2" }`
  in the root. Never `sibling.path = "../sibling"`.
- **All crates are siblings** (M-CRATES-FLAT-FOLDER): one workspace, all crates
  directly under `crates/` (or grouped `crates/server/`, `crates/client/` beyond
  1-2 dozen). Relationships via prefixes (`foo`, `foo_util`), never nesting a crate
  inside another's directory or `src/`.
- **Latest edition** (M-LATEST-EDITION): new crates use the newest stable edition
  (at least 2024); `resolver` is usually unnecessary. Old editions grant no
  compatibility benefit.
- **Conservative MSRV** (M-MSRV): set it at creation, keep it a few releases behind
  current, bump in a minor version when features require it.

---

## 12. Documentation

- **First sentence ≤ 15 words, one line** (M-FIRST-DOC-SENTENCE): it becomes the
  module-summary line; long ones wrap into widows.
- **Every public module has `//!` docs** (M-MODULE-DOCS): what it contains, when to
  use it (and not), examples, subsystem specs, observable side effects and
  guarantees, relevant implementation details. Model: `std::fmt`, `std::pin`,
  `std::option`.
- **Canonical sections** (M-CANONICAL-DOCS): summary, extended docs, `# Examples`,
  then `# Errors`, `# Panics`, `# Safety`, `# Abort` when applicable. Explain
  parameters in prose (`/// Copies a file from `src` to `dst`.`), never a
  `# Parameters` table.
- **`#[doc(inline)]` on `pub use` of your own items** (M-DOC-INLINE), so they render
  alongside siblings. Never inline `std` or third-party re-exports.
- **No meta design documentation** (M-NO-META-DESIGN-DOCUMENTATION): user docs
  describe the end state, not the journey. No "why we picked X over Y" essays, no
  guideline-compliance tables. A high-level *Design Principles* README section about
  enduring goals (allocation-free, `#[no_std]`) is fine.

---

## 13. Designing for AI agents (M-DESIGN-FOR-AI, M-TAUTOLOGICAL-TESTS, M-RUST-SHAPED)

Everything above also makes code easier for agents: idiomatic API shapes, thorough
docs and runnable examples, strong types over primitive obsession, testable APIs
(mocks behind `test-util`), and coverage over observable behavior.

Two agent-specific traps:

- **Tautological tests** restate the definition they test
  (`assert_eq!(CHECKPOINTS, [0, 90, 180, 270])`). Test a *property* instead (evenly
  spaced, monotonic). Skip a mutation-test mutant rather than write such a test.
- **Ported code shape**: when translating C#/Java/C++, keep the domain logic and
  discard the language mechanics. Error handling, task management, ownership,
  interfaces-vs-traits, and lifetimes must be re-solved the Rust way. Striking
  technical similarity to the source language is a design smell; a `throw_if_null()`
  never makes sense.

---

## 14. Review checklist

Run through when reviewing a crate. Ids link to the sections above.

- [ ] Lint sets enabled; overrides use `#[expect(.., reason)]` (§1.1, §1.2)
- [ ] Public types `Debug` (redacted + tested if sensitive); readable ones `Display` (§1.3)
- [ ] No `Service`/`Manager`/`Factory` names; ≤ 2-word identifiers (§1.5)
- [ ] Logging structured, named, redacted; no `println!` in libraries (§1.8, §4.5)
- [ ] Futures and public types `Send` (§2.1)
- [ ] No third-party types or re-exports in the public API without justification (§2.3)
- [ ] `impl AsRef`/`RangeBounds`/`Read` in fn params; no bounds on struct fields (§2.4)
- [ ] No `Arc<Mutex<..>>`/`Rc<RefCell<..>>` in signatures; ≤ 1 level of visible generics (§3.1)
- [ ] Errors are structs with backtrace, private kind, `is_*()`, `From` impls (§3.3, §3.4)
- [ ] Builders: `Foo::builder()`, chainable setters, validation in `.build()` (§3.5)
- [ ] Services `Clone` via `Arc<Inner>`; essentials inherent (§3.6, §3.7)
- [ ] No prelude, no glob re-exports, one path per item (§3.8)
- [ ] I/O mockable; test utils behind `test-util`; integration tests in `tests/` (§4.1, §4.2)
- [ ] Newtypes enforce invariants with fallible constructors (§4.3)
- [ ] No correctness-relevant statics (§4.4)
- [ ] Features additive; builds OOBE on Tier 1 (§5)
- [ ] `unsafe` justified, documented, Miri-clean; nothing unsound (§9.1, §9.2)
- [ ] Bugs panic with messages; fallible input returns `Result` (§9.3)
- [ ] Hot paths: capacity, reuse, fast hasher, yield points, future size tracked (§10)
- [ ] Workspace-inherited settings, flat `crates/`, latest edition (§11)
- [ ] Docs: ≤ 15-word summary, module docs, canonical sections, no design journals (§12)
- [ ] No tautological tests; no ported-language idioms (§13)

## 15. Anti-patterns

| Anti-pattern                                         | Fix                                                        |
| ---------------------------------------------------- | ---------------------------------------------------------- |
| `#[allow(clippy::x)]` with no reason                 | `#[expect(clippy::x, reason = "...")]`                     |
| `BookingService`, `ConfigManager`, `FooFactory`      | `Bookings`, `Config`, `FooBuilder`                         |
| `tracing::info!("opened {}", path)`                  | Named event with `file.path = ..` and `{{file.path}}`      |
| `Rc<dyn Database>` dependency injection              | Enum for test doubles, narrow traits as generics           |
| `pub enum Error { Io(..), Parse(..), .. }` exposed   | Struct error with private `ErrorKind` and `is_io()`        |
| `.map_err(MyError::Io)?` at every call site          | `impl From<io::Error> for MyError`                         |
| `Foo::builder().name(x)?`                            | Infallible setters, `.build()?`                            |
| `use foo::prelude::*`                                | Import items explicitly; fix module layout                 |
| `pub struct Port(pub u16)`                           | Private field + `from_u16() -> Result`                     |
| `static COUNTER: AtomicUsize` for correctness        | Pass state explicitly; statics only for perf caches        |
| `unsafe fn delete_all()`                             | Safe fn; `unsafe` is for UB risk only                      |
| `unsafe impl Send for Wrapper<T>`                    | Never; make the type genuinely `Send` or don't share it    |
| `Err(BugError)` for a contract violation             | `panic!("... got {value}")`                                |
| `assert!(x.len() > 4)` with no message               | Add reason and values                                      |
| `sibling.path = "../sibling"`                        | `sibling.workspace = true`                                 |
| `/// # Parameters` table                             | Explain params in prose                                    |
| `assert_eq!(CONST, [literal copy])`                  | Assert a property of the constant                          |
| `throw_if_null()`, `IFoo` trait mirroring C#         | Re-solve in Rust idioms                                    |
