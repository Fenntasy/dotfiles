---
name: react-router
description: |
  React Router v7 patterns for production server-first applications.
  Covers: loaders, actions, mutations, URL state, optimistic UI, route type safety,
  and API client integration. All patterns assume SSR mode with route loaders and actions.
  Use when: writing loaders/actions, using Form/useFetcher, managing URL state,
  typing loader/action data, or integrating an API client with React Router.
version: 1.0.0
date: 2026-03-17
user-invocable: true
---

# React Router v7

Server-first patterns for React Router v7 in SSR mode. The framework owns the data layer — loaders fetch, actions mutate, and the framework revalidates. All patterns in this skill assume this model.

For React component patterns, hooks, and error boundaries, see `/react`. For TypeScript strictness, testing, and build tooling, see `/typescript`. For CSS and responsive patterns, see `/css-responsive`.

---

## 1. Framework Model

React Router v7 in SSR mode is not a SPA framework. The core contract:

- **Loaders run on the server** before the page renders — data is available instantly, no loading spinners for initial data
- **Actions receive form submissions** and return results — no `onClick` + `fetch()`
- **Revalidation is automatic** — after a successful action, all loaders on the page re-run. No manual cache invalidation
- **Progressive enhancement** — `<Form>` and loaders work without JavaScript. Never use `fetch()` in components

The single most important mindset shift: **loaders are the cache**. There is no need for a client-side caching layer (TanStack Query, SWR, Zustand for server state). The framework handles it.

---

## 2. Data Fetching

### Route loaders

Loaders run on the server before render. Return plain objects — access via `useLoaderData`:

```tsx
import { data } from "react-router";

export async function loader({ request, params }: LoaderFunctionArgs) {
  const id = params.id;
  if (!id) throw data(null, { status: 404 });
  const resource = await api.getResource(id);
  return { resource };
}

export default function ResourcePage() {
  const { resource } = useLoaderData<typeof loader>();
  return <ResourceDetail resource={resource} />;
}
```

### Key rules

- **Loaders are the cache** — no client-side data layer on top
- **Never copy server data into `useState`** — `useLoaderData` is the source of truth
- Loaders auto-rerun after successful actions — never invalidate manually
- Throw `data(...)` to trigger `ErrorBoundary` — **not** `throw new Response(body, ...)`, which returns the body to the browser as a deliberate response (see "Triggering ErrorBoundary from a loader" below)
- Use URL search params for data variations (filters, sort, pagination) — loaders re-run when the URL changes

### Triggering `ErrorBoundary` from a loader

Surface-level "throw to trigger the error boundary" patterns look equivalent but behave very differently. Pick the right one or your 404 page renders as plain text.

| Pattern | Behavior | When to use |
|---|---|---|
| `throw data(null, { status: 404 })` | Triggers `ErrorBoundary`. `useRouteError()` receives an `ErrorResponse` matching `isRouteErrorResponse(error)`. | Almost always — "render a 404/403/500 page." |
| `throw new Response(body, { status })` | RR returns the Response **directly to the browser** as the HTTP response. The body is what the user sees — `ErrorBoundary` does NOT render. | Deliberate non-document responses (file downloads, custom JSON for an API consumer). Pass a body, not `null`. |
| `throw redirect(url)` | Returns a redirect Response directly. | Redirects from loaders/actions. |
| `throw new Error("...")` | Triggers `ErrorBoundary` with status 500. `useRouteError()` receives the `Error`. | Unexpected programming errors — usually network/parse failures that crash a loader. |

**Hidden requirement: a default component is mandatory.** Even with `throw data(...)`, if a route module exports only `loader` and no `default`, RR treats it as **data-only** and serializes the thrown value as JSON instead of rendering the `ErrorBoundary` document. This bites catch-all 404 routes hardest, where the loader always throws and the component "feels" pointless:

```ts
// WRONG — data-only route, browser receives `null` as JSON, not the
// rendered 404 page. No default export → no document render path.
import { data } from "react-router";

export async function loader() {
  throw data(null, { status: 404 });
}
```

```ts
// CORRECT — default component required, even when it never executes.
import { data } from "react-router";

export async function loader() {
  throw data(null, { status: 404 });
}

export default function NotFound() {
  return null; // never runs; loader always throws
}
```

**Catch-all routes for true 404s.** Without a `*` route, RR throws `"No route matches URL"` *before* any loader runs — meaning the root loader never executes, root data is missing from router state, and SSR-level concerns that depend on root loader data (e.g. CSP nonces, theme tokens, request-scoped values) are absent on the 404 page. Add an explicit catch-all so the loader chain always runs:

```ts
// app/routes.ts
route("*", "routes/not-found.ts"),
```

---

## 3. Mutations

### `<Form>` for all mutations

All mutations flow through route actions via `<Form method="post">`:

```tsx
<Form method="post">
  <input type="hidden" name="_intent" value="create" />
  <input name="name" required />
  <button type="submit">Create</button>
</Form>
```

`Form` is from `react-router`, not HTML. It handles serialization, triggers the action, and revalidates loaders on success. Never use `onClick` + `fetch()`.

### Actions

```typescript
export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  const intent = String(formData.get("_intent") ?? "create");

  if (intent === "delete") {
    const id = String(formData.get("id") ?? "");
    if (!id)
      return data({ error: "Missing id", intent: "delete" }, { status: 400 });
    try {
      await api.deleteResource(id);
      return data({ success: true, intent: "delete" });
    } catch (error) {
      return data(
        { error: "Failed to delete", intent: "delete" },
        { status: 500 },
      );
    }
  }
  // handle create, update...
}
```

### Intent pattern

Multi-action routes use a hidden `_intent` field to discriminate between actions. Always include `intent` in the return shape so the UI can scope error display to the correct form.

### Action return shape

```typescript
type ActionResult = { intent: string; error?: string; success?: boolean };
```

- Use `data()` from `react-router` for both success and error — **never throw for expected user errors** (throws trigger `ErrorBoundary` and lose form state)
- **Never use `Response.json()`** — it returns an opaque `Response` type that breaks `useActionData<typeof action>()` inference when the action also calls `redirect()`, causing the inferred type to collapse to `never`
- Use `satisfies ActionResult` on the payload to get compile-time checking without widening the type
- Access via `useActionData<typeof action>()` — validate with a type guard since it returns `unknown`

```typescript
// CORRECT — data() preserves type inference
return data({ intent: "error", error: "Not found" } satisfies ActionResult, {
  status: 404,
});

// WRONG — Response.json() breaks useActionData inference when action also redirects
return Response.json({ intent: "error", error: "Not found" }, { status: 404 });
```

### `useFetcher` for non-navigation mutations

Use `useFetcher` when the mutation should not trigger a full-page navigation:

```tsx
const fetcher = useFetcher();

<fetcher.Form method="post">
  <input type="hidden" name="_intent" value="toggle" />
  <button type="submit">Toggle</button>
</fetcher.Form>;
```

Use cases: inline toggles, background saves, actions in list items that should not scroll to top.

### Submission state

```tsx
const navigation = useNavigation();
const isSubmitting = navigation.state === "submitting";

<button type="submit" disabled={isSubmitting}>
  {isSubmitting ? "Saving..." : "Save"}
</button>;
```

For fetcher-driven mutations, use `fetcher.state` instead of `navigation.state`.

### Form inputs

- Use `defaultValue` for form fields (uncontrolled inputs) — the browser manages form state
- Never use `useState` + `value` for fields submitted via `<Form>`
- Extract `FormData` parsing into named functions to keep actions focused on business logic

---

## 4. Optimistic UI

Derive optimistic state from `fetcher.formData` — the pending submission data. No `useOptimistic` needed (that's React 19's primitive for React Actions, not for React Router's data layer).

Render pending items separately from the data list — the optimistic item is transient UI state, not data:

```tsx
const fetcher = useFetcher();

return (
  <>
    <ul>
      {items.map((item) => (
        <li key={item.id}>{item.name}</li>
      ))}
      {fetcher.formData && (
        <li className="opacity-50">
          {String(fetcher.formData.get("name") ?? "")}
        </li>
      )}
    </ul>
    <fetcher.Form method="post">
      <input type="hidden" name="_intent" value="create" />
      <input name="name" required />
      <button type="submit">Add</button>
    </fetcher.Form>
  </>
);
```

`fetcher.formData` is non-null while the submission is in flight. When the action completes, loaders revalidate, the real item (with its server-assigned ID) appears in `items`, and `fetcher.formData` resets to null — the optimistic element disappears automatically.

For multiple concurrent submissions, use `useFetchers()` to collect and render all pending items.

---

## 5. State Management

### Decision table

| State type   | Tool                                     | Example                                       |
| ------------ | ---------------------------------------- | --------------------------------------------- |
| Server data  | `useLoaderData` / `useActionData`        | Fetched resources, lists, action results      |
| URL state    | `useSearchParams`                        | Filters, pagination, search, sort             |
| Form data    | Uncontrolled DOM inputs (`defaultValue`) | Input values in `<Form>`                      |
| Transient UI | `useState`                               | Sheet open/close, delete confirm, mount guard |

### Key rules

- **No client-side data layer** — loaders and actions own all server data. SPA-era caching libraries (TanStack Query, SWR, Zustand for server state) fight the framework's revalidation model
- **Never copy server data into `useState`** — `useLoaderData` is the source of truth
- **URL state is the most underused location** — filters, sort order, and pagination belong in the URL via `useSearchParams`, not component state. The URL is shareable and bookmarkable; `useState` is not

```tsx
function useAssetFilters() {
  const [searchParams, setSearchParams] = useSearchParams();
  const filters = useMemo(() => parseFilters(searchParams), [searchParams]);
  const setFilter = useCallback(
    (key: string, value: string) => {
      setSearchParams((prev) => {
        prev.set(key, value);
        return prev;
      });
    },
    [setSearchParams],
  );
  return { filters, setFilter };
}
```

---

## 6. Route Type Safety

### Loader types

`useLoaderData<typeof loader>()` infers the return type — no manual type annotation needed:

```typescript
export async function loader({ request, params }: LoaderFunctionArgs) {
  const resources = await apiClient.getResources();
  return { resources }; // useLoaderData<typeof loader> infers { resources: Resource[] }
}
```

Never use `any` for loader data. Never manually annotate the return type — let TypeScript infer it.

### Action types

`useActionData<typeof action>()` returns `unknown` in React Router v7 — always validate with a type guard:

```typescript
type ActionResult = { intent: string; error?: string; success?: boolean };

function isActionResult(data: unknown): data is ActionResult {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  if (typeof d.intent !== "string") return false;
  if ("error" in d && typeof d.error !== "string") return false;
  if ("success" in d && typeof d.success !== "boolean") return false;
  return true;
}
```

### FormData extraction

Always extract `FormData` parsing into named functions. Never cast `formData.get()` with `as` — always use `String()` with a fallback:

```typescript
// CORRECT
function parseCreateForm(formData: FormData) {
  return {
    name: String(formData.get("name") ?? ""),
    kind: String(formData.get("kind") ?? ""),
  };
}

// WRONG — unsafe cast, no fallback
const name = formData.get("name") as string;
```

---

## 7. API Client Integration

### Where to call the API client

API calls belong exclusively in loaders and actions — never in components:

```typescript
// CORRECT — in a loader (server-side)
export async function loader({ request }: LoaderFunctionArgs) {
  const data = await apiClient.getResources();
  return { data };
}

// CORRECT — in an action (server-side)
export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  await apiClient.createResource(parseCreateForm(formData));
  return data({ success: true, intent: "create" });
}

// WRONG — direct API call in a component
export default function ResourceList() {
  const [data, setData] = useState(null);
  useEffect(() => {
    apiClient.getResources().then(setData);
  }, []); // never do this
}
```

Components read data exclusively from `useLoaderData` and `useActionData`.

### Error handling in actions

Catch API errors in the action and return a typed error response — never let them propagate to `ErrorBoundary`:

```typescript
try {
  await apiClient.deleteResource(id);
  return data({ success: true, intent: "delete" });
} catch (error) {
  const status = error instanceof ApiError ? error.status : 500;
  return data({ error: "Failed to delete", intent: "delete" }, { status });
}
```

---

## 8. Layout Routes for Tabbed Pages

When a page has distinct sections or tabs, use a layout route with `<Outlet />` and child routes — not query params or client-side tab state. Each section becomes its own route with its own loader, keeping data fetching isolated and giving you browser history, deep links, and independent loading for free.

### Route config

```ts
// routes.ts
layout("routes/orders.tsx", [
  route("/orders", "routes/orders._index.tsx"),           // default tab
  route("/orders/returns", "routes/orders.returns.tsx"),
  route("/orders/analytics", "routes/orders.analytics.tsx"),
]),
```

### Layout route — shared chrome + `<Outlet />`

The layout provides the heading, tab navigation, and renders the active child:

```tsx
// routes/orders.tsx
import { NavLink, Outlet } from "react-router";

export default function OrdersLayout() {
  const tabClass = (isActive: boolean) =>
    `px-3 py-1.5 rounded text-sm font-medium ${
      isActive ? "bg-primary text-white" : "bg-gray-100 text-gray-700"
    }`;

  return (
    <div>
      <h1>Orders</h1>
      <nav className="flex gap-2 mb-6">
        <NavLink to="/orders" end className={({ isActive }) => tabClass(isActive)}>
          All orders
        </NavLink>
        <NavLink to="/orders/returns" className={({ isActive }) => tabClass(isActive)}>
          Returns
        </NavLink>
        <NavLink to="/orders/analytics" className={({ isActive }) => tabClass(isActive)}>
          Analytics
        </NavLink>
      </nav>
      <Outlet />
    </div>
  );
}
```

### Child routes — isolated loaders

Each child route fetches only the data it needs:

```tsx
// routes/orders._index.tsx — paginated order list
export async function loader({ request }: LoaderFunctionArgs) {
  const url = new URL(request.url);
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const { rows, total } = await listOrders(page);
  return { rows, total, page };
}

// routes/orders.returns.tsx — return requests with action
export async function loader({ request }: LoaderFunctionArgs) {
  const { rows, total } = await listReturns();
  return { rows, total };
}

export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  // handle return approval/rejection
}

// routes/orders.analytics.tsx — stats only, no action
export async function loader() {
  const stats = await getOrderStats(30);
  return { stats };
}
```

### Why not query params or `useState`?

- **Query params** (`?tab=returns`) load all tab data in a single loader, wasting DB queries for invisible tabs
- **`useState`** loses the active tab on refresh, isn't bookmarkable, and forces conditional rendering in one large component
- **Subroutes** give each tab its own loader (fetches only what's visible), its own action, proper browser back/forward, and deep-linkable URLs

### When query params are still right

Use `useSearchParams` for variations *within* a single view — filters, sort order, pagination. These modify what the current loader returns, not which view is active. If switching between the options would require a fundamentally different loader or action, it should be a subroute.

---

## 9. Anti-Patterns

### SPA-era patterns — never use with React Router v7

These patterns belong to the SPA era where the client managed its own data. In a server-first architecture they add complexity, fight the framework, and break progressive enhancement.

| SPA anti-pattern                        | Problem                                                                            | React Router alternative                       |
| --------------------------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------- |
| `useEffect` for data fetching           | Waterfalls, race conditions, no SSR                                                | Route loaders                                  |
| `onClick` + `fetch` for mutations       | No progressive enhancement, no revalidation                                        | `<Form method="post">`                         |
| Client-side `fetch` in components       | Bypasses loader caching, invisible to framework                                    | Move to loader or action                       |
| TanStack Query / SWR for route data     | Duplicate cache layer, fights revalidation                                         | `useLoaderData` is the cache                   |
| `useState` for form fields              | Extra state, out of sync with DOM                                                  | `defaultValue` + uncontrolled inputs           |
| `useReducer` for form state             | Over-engineering what the DOM already does                                         | `<Form>` + `FormData`                          |
| Client-side form validation libraries   | Duplicates server logic, false sense of security                                   | HTML5 attributes + server validation in action |
| `useEffect` to sync action results      | Extra render cycle, stale values                                                   | `useActionData()` directly                     |
| Zustand/Redux for server data           | Wrong tool — these are for client-only state                                       | Loaders own server data                        |
| Throwing from actions for user errors   | Triggers ErrorBoundary, loses form state                                           | `data({ error })` from `react-router`          |
| `throw new Response("text", { status })` from a loader expecting ErrorBoundary | Body is returned directly to the browser; ErrorBoundary never renders | `throw data(null, { status })` (and ensure the route has a `default` export) |
| Loader-only route module without a `default` export | RR treats it as data-only and serializes thrown values as JSON | Add `export default function () { return null }` even when the loader always throws |
| `Response.json()` in actions            | Breaks `useActionData` inference when action also redirects (collapses to `never`) | `data()` from `react-router`                   |
| Copying `useLoaderData` into `useState` | Two sources of truth, stale data                                                   | Use `useLoaderData` directly                   |
| `useState` for filters/pagination       | Not shareable, lost on navigation                                                  | `useSearchParams`                              |

---

## Cross-references

- `/react` — React component patterns, hooks, error boundaries, `use()`, memoization
- `/typescript` — TypeScript strictness, testing (Vitest/Playwright), build tooling, linting
- `/api-design` — REST API design, HTTP semantics, status codes
- `/ux-design` — Component API design, form UX, accessibility
