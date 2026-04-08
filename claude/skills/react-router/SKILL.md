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
export async function loader({ request, params }: LoaderFunctionArgs) {
  const id = params.id;
  if (!id) throw new Response("Not Found", { status: 404 });
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
- Throw `Response` on error to trigger the route's `ErrorBoundary`:
  ```ts
  throw new Response("Not Found", { status: 404 });
  ```
- Use URL search params for data variations (filters, sort, pagination) — loaders re-run when the URL changes

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

## 8. Anti-Patterns

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
| `Response.json()` in actions            | Breaks `useActionData` inference when action also redirects (collapses to `never`) | `data()` from `react-router`                   |
| Copying `useLoaderData` into `useState` | Two sources of truth, stale data                                                   | Use `useLoaderData` directly                   |
| `useState` for filters/pagination       | Not shareable, lost on navigation                                                  | `useSearchParams`                              |

---

## Cross-references

- `/react` — React component patterns, hooks, error boundaries, `use()`, memoization
- `/typescript` — TypeScript strictness, testing (Vitest/Playwright), build tooling, linting
- `/api-design` — REST API design, HTTP semantics, status codes
- `/ux-design` — Component API design, form UX, accessibility
