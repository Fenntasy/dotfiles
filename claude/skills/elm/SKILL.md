---
name: elm
description: >
  Elm application and package design skill for production single-page apps.
  Covers: The Elm Architecture and Msg design, making impossible states impossible,
  opaque types and parse-don't-validate, module growth ("life of a file", build
  modules around a type, no MVC/component split), nested TEA and when to avoid it,
  effects (Cmd/Sub/Task), JSON decoders as the boundary, JS interop (flags, ports,
  custom elements), Browser.application routing and URL parsing, Html.Lazy/Keyed and
  asset-size optimization, package API design and documentation format, tooling
  (elm-format, elm-review, elm-test).
  Use when: writing or reviewing Elm code, designing a Model or Msg type, deciding
  whether to split a module, wiring JS interop, structuring a multi-page app,
  publishing a package, or optimizing rendering or bundle size.
  Sources: guide.elm-lang.org, package.elm-lang.org design/documentation guidelines,
  Evan Czaplicki "The Life of a File", Richard Feldman "Scaling Elm Apps" and
  "Make Impossible States Impossible", rtfeldman/elm-spa-example, sporto/elm-patterns,
  jfmengels/elm-review.
version: 1.0.0
date: 2026-09-09
user-invocable: true
---

# Elm

Design guidance for Elm apps and packages. The through-line: **the compiler is the
architecture**. Encode intent in types so invalid programs don't compile, keep
modules built around a type rather than around a screen or a layer, and let the
refactoring safety net replace the defensive habits carried over from JavaScript.

> **Scope boundary:** this skill covers Elm language, architecture, and packaging.
>
> - **The HTML/CSS side** (layout, responsive, design system) → `/css-responsive`,
>   `/ux-design`, `/frontend-design`.
> - **The JS host** (bundlers, TypeScript around ports) → `/typescript`.
> - **API contracts** the decoders consume → `/api-design`.

---

## 1. The Elm Architecture

Every program is `Model` (state), `view : Model -> Html Msg` (render), and
`update : Msg -> Model -> ( Model, Cmd Msg )` (transition). Pick the smallest
`Browser` entry point that fits:

| Program               | Gives you                                       | Use when                          |
| --------------------- | ----------------------------------------------- | --------------------------------- |
| `Browser.sandbox`     | Model, view, update; no effects                 | Pure widgets, exercises           |
| `Browser.element`     | + `Cmd`, `Sub`, flags                           | Embedding Elm in an existing page |
| `Browser.document`    | + control of `<title>` and `<body>`             | Elm owns the whole page           |
| `Browser.application` | + URL ownership (`onUrlRequest`, `onUrlChange`) | Single-page apps with routing     |

### 1.1 Msg design

`Msg` describes **what happened**, in the domain's vocabulary, not what to do.

```elm
-- WRONG: imperative, leaks the update logic into the name, invites reuse for
-- unrelated purposes.
type Msg
    = SetName String
    | SetLoading Bool
    | UpdateModel (Model -> Model)

-- CORRECT: past-tense facts the update function decides how to interpret.
type Msg
    = NameChanged String
    | SaveClicked
    | GotProfile (Result Http.Error Profile)
```

- One variant per user intent or external event. A `SetField String String`
  catch-all makes `update` a string dispatcher the compiler can't check.
- Never put functions in `Msg` or `Model` (`UpdateModel (Model -> Model)`). It kills
  the debugger, equality, and readability.
- Prefix results of effects with `Got`/`Received`; they carry a `Result`.
- `NoOp` is a smell. Almost always a `Maybe`, a filtered subscription, or a
  variant you haven't named yet.

### 1.2 Update discipline

- `update` is the only place state changes. Views are pure functions of `Model`.
- Keep each branch small. When a branch must do several things, pipe through a
  return helper rather than hand-batching:

```elm
SeeReport report ->
    ( model, Cmd.none )
        |> andThen (showReport report)
        |> andThen loadMoreDataIfNeeded
        |> andThen trackSeeReportEvent

andThen : (Model -> ( Model, Cmd Msg )) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
andThen fn ( model, cmd ) =
    let
        ( nextModel, nextCmd ) =
            fn model
    in
    ( nextModel, Cmd.batch [ cmd, nextCmd ] )
```

- Never use `_` wildcards in a `case` over your own `Msg` or state type; you lose
  the exhaustiveness check that makes adding a variant safe.

---

## 2. Types: make impossible states impossible

The core Elm discipline (Feldman, elm-conf 2016). Any `Model` where two fields can
disagree is a bug waiting for a code path.

```elm
-- WRONG: isLoading = False && data = Nothing means... what?
type alias Model =
    { isLoading : Bool
    , data : Maybe Data
    , error : Maybe String
    }

-- CORRECT: one field, every state nameable, none contradictory.
type RemoteData
    = NotAsked
    | Loading
    | Failure Http.Error
    | Success Data

type alias Model =
    { data : RemoteData }
```

Checklist when designing a type:

- Enumerate the states the UI actually has. Each becomes a variant, with exactly
  the data that state needs.
- A `Bool` next to a `Maybe` is almost always two variants in disguise.
- A `List` that "must have at least one" is `( a, List a )` or a `NonEmpty` type.
- Two fields that "must be kept in sync" are one field.

### 2.1 Minimize booleans

- **Boolean arguments** hide intent: `bookFlight "ELM" True`. Use a custom type:
  `bookFlight "ELM" Premium`.
- **Boolean returns** cause boolean blindness: `if isValid form then submit form`
  still passes unvalidated `form`. Return `Result Error ValidForm` so `submit` can
  only receive proven-valid data.

### 2.2 Type blindness and wrap early, unwrap late

Two `String`s or two `Float`s of different meaning get swapped silently. Wrap them
(`type Dollar = Dollar Float`, `type Email = Email String`) **at the boundary**
(decoders, flags, form parsing) and unwrap **as late as possible** (rendering,
encoding). Same for `Maybe`/`Result`: unwrap once at the top of a view and pass
plain values down; don't thread `Maybe User` into five sub-views.

### 2.3 Opaque types

Export the type, not its constructors: `module Lib exposing (Config, new, withSize)`
with `type Config = Config { size : Int }`. Only the module can construct or
inspect it, so:

- invariants hold by construction (a `SortedList` only the module can `add` to);
- the representation can change without a major version;
- callers use `fromXY`/`withSize` instead of positional constructors that break
  when a field is added.

Use opaque types even with one variant. Package authors: **keep tags and record
constructors secret** (official design guideline). Named-argument records
(`isBefore { subject : Date, comparedTo : Date }`) are the fix for ambiguous
same-typed positional arguments.

### 2.4 Parse, don't validate

Validation returns `Bool` and leaves you holding the unvalidated value. Parsing
returns a **new type** that can only exist if the checks passed:

```elm
type alias UserInput = { name : Maybe String, age : Maybe Int }
type alias ValidUser = { name : String, age : Int }

parseUser : UserInput -> Result String ValidUser
```

Apply at every boundary: JSON, flags, ports, form input, URL parsing. Downstream
code takes `ValidUser` and needs no re-checks.

### 2.5 Phantom types

A type variable unused by constructors (`type Users a = Users (List User)`) lets
functions demand a state: `usersView : Users Active -> Html msg`. Use for state
machines and multi-step flows (`start : Order -> Step Start`,
`setTotal : Int -> Step Start -> Step WithTotal`, `done : Step Done -> Order`)
instead of an explosion of intermediate record aliases. Reach for it only when the
invariant is worth the ceremony.

### 2.6 Keep variant lists in sync

`all : List Color` drifts when a variant is added. Either build the list from a
`case` with no wildcard (the compiler flags the missing variant) or use the
`NoMissingTypeConstructor` elm-review rule.

---

## 3. Module growth: the life of a file

Evan's guidance (guide.elm-lang.org/webapps/structure, "The Life of a File"):

- **Build every module around a central type.** `Post` module: `Post` type,
  `estimatedReadTime`, `encode`, `decoder`. `Page.Home`: its `Model`, `init`,
  `update`, `view`, and helpers.
- **Start with `Main` and `Page.*`.** Do not plan shared modules ahead. Grow each
  page file long. Extract a `Post` module only when helper functions around that
  type pile up, and revert if it didn't make things clearer.
- **400 to 1000 lines is normal.** Length is safe in Elm: no hidden mutation, and
  refactoring across 20 files is cheap. Use `-- COMMENT HEADERS` to section a file.
- **Unique / similar / the same heuristic.** Assume similar code is unique and
  write it twice. Only extract when logic is _exactly_ the same. When "the same"
  later diverges, copy it back into two places rather than growing a Frankenstein
  function with more arguments.
- **No MVC split.** Never `Model.elm` / `Update.elm` / `View.elm`. Placement
  becomes an ontological argument (`estimatedReadTime` is used by both).
- **No components.** A sidebar is `viewSidebar : Args -> Html Msg`, not a module
  with its own `Model`/`update`. Components are objects; Elm has none. A view
  helper does not need matching state.
- **Imports:** `exposing` on zero or one import (`Html exposing (..)` at most).
  Qualified access (`Post.decoder`) keeps provenance visible. Never `exposing (..)`
  from your own modules.

### 3.1 Scaling to many pages (elm-spa-example)

Feldman's reference layout for a real SPA:

| Module                               | Role                                                                                         |
| ------------------------------------ | -------------------------------------------------------------------------------------------- | ------------ | ------------------------------------- |
| `Main`                               | `Browser.application`; a `Model` that is a custom type of page states; routes `Msg` to pages |
| `Page.Home`, `Page.Article`, ...     | Each page's own TEA triple; `toSession : Model -> Session`                                   |
| `Session`                            | What every page needs: `Nav.Key`, current `Viewer` (or guest)                                |
| `Route`                              | `type Route = Home                                                                           | Article Slug | ...`, `fromUrl`, `href`, `replaceUrl` |
| `Api`                                | `Cred`, endpoints, decoding, auth header injection                                           |
| `Username`, `Slug`, `Cred`, `Viewer` | Opaque domain types                                                                          |

- `Main.Model` is a **custom type**, one variant per page holding that page's model,
  not a record with a `Maybe` per page.
- Pages talk to `Main` only through their return value. `Main` maps page `Msg`s
  with `Cmd.map`/`Html.map` at the boundary, once.
- Extract by **type**, not by page. A `Cred` module exists because many pages need
  credentials, not because "auth is a feature".

### 3.2 Nested TEA and child-to-parent communication

Nesting `Model`/`Msg`/`update` inside a parent adds boilerplate and makes child →
parent messaging awkward. Use sparingly, only for genuinely stateful, reused
subsystems (pages, a rich editor). Patterns when you do:

- **Outcome value:** child `update` returns `( Model, Cmd Msg, Outcome )`; parent
  pattern-matches the outcome.
- **Translator:** child view takes `{ toSelf : Msg -> msg, onSave : msg }` instead
  of returning `Html Msg`, so it can emit parent messages directly.
- **Global actions:** child returns `List Action`; root interprets them.

For stateless reuse, prefer a plain view function that takes message constructors
(`onOpen : msg`, `onSelect : Date -> msg`), optionally via a builder:
`Button.new "Save" SaveClicked |> Button.withIcon Icon.Save |> Button.view`.

---

## 4. Effects

- `Cmd` asks the runtime to do something; `Sub` asks to be told when something
  happens. Both are data. `update` never performs I/O.
- `Task` chains sequential effects (`Task.andThen`) and converts to `Cmd` once at
  the end with `Task.attempt` / `Task.perform`. Use it for "fetch then fetch" flows;
  batching independent commands is `Cmd.batch`.
- Subscriptions derive from `Model`: `subscriptions model` returns `Sub.none` when
  the feature isn't active, so timers and listeners stop themselves.
- **Effects pattern for testability:** `update` returns `( Model, List Effect )`
  with `type Effect = SaveUser User | LoadData | ...`, and a single `perform :
Effect -> Cmd Msg` at the root turns them into real commands. Tests then assert
  on `Effect` values (this is how `elm-program-test` works).

### 4.1 JSON decoders are the boundary

- One `decoder : Decoder Post` and `encode : Post -> Value` per domain type, living
  in that type's module.
- Build decoders with `map2..map8` or the `NoRedInk/elm-json-decode-pipeline`
  `required`/`optional` style. Argument order must match the constructor field
  order; same-typed fields (`name`, `email`) can swap silently, so test decoders
  with a fixture.
- Decode into the **final** type (wrapped ids, custom types), not a mirror of the
  JSON. `Decode.andThen` + `Decode.fail` turns unknown string tags into decode
  errors instead of a catch-all variant.
- Handle failure as data: `Result Decode.Error a` surfaces to `update` as a `Msg`
  variant; never `Maybe.withDefault` your way past a decoder error.

---

## 5. JavaScript interop

Ports and flags are for **strong boundaries**, not per-function bridges. Ask "who
owns this state?" and cross the border with one or two rich messages.

### 5.1 Flags

`Elm.Main.init({ node, flags })` → `init : Flags -> ( Model, Cmd Msg )`. Declare
flags as `Json.Decode.Value` and decode inside `init`; a typed flag that doesn't
match throws **on the JS side** before Elm runs. With a `Value` you choose the
fallback. Use flags for API base URLs, environment, cached `localStorage`, initial
user.

### 5.2 Ports

```elm
port module Ports exposing (toJs, fromJs)

port toJs : Json.Encode.Value -> Cmd msg
port fromJs : (Json.Decode.Value -> msg) -> Sub msg
```

- Keep every `port` declaration in one `port module` so the whole interface is in
  one file.
- Prefer one outgoing and one incoming port carrying a tagged `Value`
  (`{ tag: "active-users-changed", list: [...] }`) decoded into a custom type over
  a port per function.
- Encode with `Json.Encode`, decode with a `Decoder`. Typed port payloads exist
  from before decoders and fail loudly on mismatch.
- Ports are application-only; packages can't declare them. Unused ports are
  dead-code-eliminated, so wire the Elm side first.
- Typical uses: WebSockets, `localStorage`, analytics, third-party widgets.

### 5.3 Custom elements

For DOM-level integration (an `Intl` date formatter, a map widget, a React
component) register a custom element and render it from Elm with
`node "intl-date" [ attribute "lang" lang ] []`. Implement `observedAttributes` +
`attributeChangedCallback` so Elm's attribute diffs propagate. Choose this over
ports when the JS is about _rendering_, ports when it's about _state or I/O_.

---

## 6. Web apps: navigation and URLs

- `Browser.application` receives `onUrlRequest : UrlRequest -> Msg` and
  `onUrlChange : Url -> Msg`, plus a `Nav.Key` in `init` that every
  `Nav.pushUrl`/`replaceUrl` needs. Store the key in `Session`.
- `LinkClicked (Browser.Internal url)` → `Nav.pushUrl key (Url.toString url)`;
  `Browser.External href` → `Nav.load href`.
- `UrlChanged url` → `Route.fromUrl url` → `changeRouteTo` initializes the matching
  page. Routing is data: `type Route = Home | Author String | Post Int`.
- Parse with `Url.Parser`: `oneOf [ map Home top, map Author (s "author" </> string), map Post (s "post" </> int) ]`.
  Add `<?> Query.string "q"` for query params and `fragment identity` for `#anchor`.
- `Route.href : Route -> Attribute msg` and `Route.toString` keep URLs in one place.
  No string-concatenated links in views.

---

## 7. Rendering performance and asset size

- **`Html.Lazy` at the root** and around regions that change independently
  (`lazy viewInput model.field`, `lazy2 viewEntries model.visibility model.entries`).
  Also on repeated items that change rarely. `lazy` compares by **reference**, so
  pass model fields or stable values, never a freshly built record or lambda.
- **`Html.Keyed`** for lists that insert, remove, or reorder: `Keyed.node "ul" []
(List.map (\p -> ( p.id, lazy viewItem p )) items)`. Keys must be stable ids, not
  indices.
- Touching the DOM dominates everything else; data-structure micro-optimizations
  matter far less than getting `lazy` right.
- **Asset size:** `elm make --optimize` (dead code elimination, record field
  renaming) then two `uglifyjs` passes:

```sh
elm make src/Main.elm --optimize --output=elm.js
uglifyjs elm.js --compress 'pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe' \
  | uglifyjs --mangle --output elm.min.js
```

Two passes are required: `--mangle` first would hide `pure_funcs`. `--optimize`
forbids `Debug.*`, which doubles as a guard. Ship one JS file; gzip does the rest.

---

## 8. Packages

From the official [design guidelines](https://package.elm-lang.org/help/design-guidelines):

- **Design for a concrete use case.** Have example code and a tentative API before
  implementing. Know who has the problem and what they need.
- **Avoid gratuitous abstraction.** If you can't demonstrate the benefit, the
  abstraction is a cost.
- **The data structure is always the last argument**, so pipelines and folds
  compose: `remove : String -> Dict String a -> Dict String a`.
- **Keep tags and record constructors secret** (§2.3). Expose `fromXY`, not `Point`.
- **Human-readable names**, no abbreviations. **Module names don't reappear in
  function names**: `State.run`, not `State.runState`; the latter encourages
  `exposing (..)`.
- Semver is enforced by the compiler from the exposed API; opaque types are what
  let you change internals in a minor release.

### 8.1 Documentation format

- Module doc comment sits between `module ... exposing (...)` and the imports:
  a prose intro, then `# Section` headings with `@docs a, b, c` lines. Order for
  linear reading: the central type first, then the most important functions.
- Every exposed value has a type annotation and a `{-| ... -}` comment starting
  after one space, with a four-space-indented example, closed on its own line.
- `elm.json` `exposed-modules` decides what the compiler checks; undocumented
  exposed modules cannot be published.

---

## 9. Tooling

| Tool                   | Role                                                                                                                                                                                                                          |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `elm-format`           | Non-negotiable formatting; run on save, no style debates                                                                                                                                                                      |
| `elm-review`           | Static analysis. Start from `jfmengels/elm-review-unused`, `elm-review-common`, `elm-review-simplify`, `elm-review-debug`; add `NoMissingTypeConstructor`. Prefer fixing an API over adding a rule; agree rules with the team |
| `elm-test`             | Unit + fuzz tests; test decoders, parsers, `update` via the effects pattern                                                                                                                                                   |
| `elm-program-test`     | Whole-program tests driving `update`/`view` with simulated effects                                                                                                                                                            |
| `elm-json`             | Dependency management CLI                                                                                                                                                                                                     |
| `elm-optimize-level-2` | Extra JS-level optimizations beyond `--optimize` when bundle size matters                                                                                                                                                     |

Run `elm-format --validate`, `elm-review`, and `elm-test` in CI. Unused exports
and imports are noise the compiler won't flag; `elm-review-unused` does.

---

## 10. Checklist

- [ ] `Msg` variants are past-tense facts; no `NoOp`, no functions in `Msg`/`Model`
- [ ] No `Bool` + `Maybe` pairs; loading/error/success is one custom type
- [ ] Ids, emails, money, and other same-typed values are wrapped at the boundary
- [ ] Boundaries parse into validated types; no `Bool`-returning validators
- [ ] Domain types are opaque; packages expose no constructors or record aliases
- [ ] Modules are built around a type; no `Model/Update/View` split, no components
- [ ] Pages nest at most one level; child → parent via outcome or translator
- [ ] `update` returns effects as data where tests need to inspect them
- [ ] One `port module`; tagged `Value` payloads; flags decoded from `Value`
- [ ] Routes are a custom type with `fromUrl`/`href`; no string URLs in views
- [ ] `lazy` at the root and on stable repeated items; `Keyed` on reorderable lists
- [ ] Production build: `--optimize` + double `uglifyjs`
- [ ] `elm-format`, `elm-review`, `elm-test` pass in CI
- [ ] No `case` wildcard over own custom types
- [ ] `exposing` on at most one import

## 11. Anti-patterns

| Anti-pattern                                              | Fix                                                         |
| --------------------------------------------------------- | ----------------------------------------------------------- | --------------------------------------------------------------- |
| `SetField String String` / `UpdateModel (Model -> Model)` | One named variant per intent                                |
| `{ isLoading : Bool, data : Maybe a, error : Maybe e }`   | `RemoteData` custom type                                    |
| `isValid : Form -> Bool` then using `form`                | `parse : Form -> Result Error ValidForm`                    |
| `type alias Config = { .. }` exported from a package      | Opaque `type Config = Config { .. }` + `new`/`with*`        |
| `Model.elm`, `Update.elm`, `View.elm`                     | One module per central type / page                          |
| `Sidebar` module with its own `Model` and `update`        | `viewSidebar : Args -> Html Msg`                            |
| Extracting a shared `Post` module on day one              | Grow pages; extract when helpers around `Post` pile up      |
| Frankenstein helper with six config arguments             | Copy into two unique versions; extract only what's the same |
| A port per JS function                                    | One tagged `Value` port each way                            |
| `init : { apiUrl : String, user : User } -> ..` flags     | `init : Value -> ..` with a decoder and fallback            |
| `href ("/post/" ++ String.fromInt id)` in a view          | `Route.href (Route.Post id)`                                |
| `lazy viewItem { item                                     | selected = True }`                                          | Pass stable values; the fresh record defeats reference equality |
| `List.map viewRow rows` inside a sortable table           | `Keyed.node` with stable id keys                            |
| `case msg of ... _ -> ( model, Cmd.none )`                | Handle every variant explicitly                             |
| `import Post exposing (..)`                               | Qualified `Post.decoder`                                    |
| `Debug.log` left in `update`                              | Remove; `--optimize` refuses to compile it anyway           |
| `Maybe.withDefault` to skip a decode error                | Surface the `Err` as a `Msg` and a UI state                 |
