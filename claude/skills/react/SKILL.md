---
name: react
description: |
  React 19 development patterns for production web applications.
  Covers: React 19 features, hooks, state management, error handling, and component composition.
  Use when: writing React components, hooks, managing transient UI state, or implementing error boundaries.
version: 3.0.0
date: 2026-03-17
user-invocable: true
---

# React Development

React 19 component patterns for production applications. This skill covers the React layer — hooks, error handling, state, and component composition.

For React Router v7 patterns (loaders, actions, mutations, URL state, Form, useFetcher), see `/react-router`. For TypeScript strictness, testing, and build tooling, see `/typescript`. For component design, form UX, and accessibility, see `/ux-design`. For CSS and responsive patterns, see `/css-responsive`.

---

## 1. React 19 Patterns

### `use()` hook

Reads promises and context inside conditionals and loops (unlike other hooks):

```tsx
function ResourceDetail({ resourcePromise }: { resourcePromise: Promise<Resource> }) {
  const resource = use(resourcePromise); // suspends until resolved
  return <h1>{resource.name}</h1>;
}
```

### React Compiler

React Compiler (stable in React 19) automatically memoizes at build time:

- **Remove** `useMemo`, `useCallback`, and `React.memo` from new code
- Keep manual memoization only for identity-critical paths (e.g., callbacks passed to non-React libraries that use reference equality)

---

## 2. Error Handling

### Layered error boundaries

1. **Root boundary:** Catches catastrophic errors, shows a full-page error screen
2. **Route boundary:** Catches loader/action errors per route (framework-provided `ErrorBoundary` export from React Router)
3. **Feature boundary:** Wraps individual widgets so a single failure doesn't take down the page

```tsx
import { ErrorBoundary } from "react-error-boundary";

<ErrorBoundary
  FallbackComponent={ErrorFallback}
  onReset={() => { /* revalidate loaders or navigate to same route */ }}
  resetKeys={[resourceId]}
>
  <ResourceDetail />
</ErrorBoundary>
```

### What error boundaries do NOT catch

- Errors in event handlers (use try/catch)
- Async errors outside React rendering (handle in promise chains)
- Errors in the error boundary itself

### Retry pattern

Offer a "Try again" button that calls `resetErrorBoundary()`. For route-level errors, a page reload retriggers the loader.

### Toast notifications

Use for non-blocking errors (e.g., "Failed to save, retrying..."). Libraries: `sonner`, `react-hot-toast`. Never use toasts as the sole error indicator for form validation.

---

## 3. State Management

### Decision table

| State type | Tool | Example |
| --- | --- | --- |
| Server data | `useLoaderData` / `useActionData` | Fetched resources, lists, action results |
| URL state | `useSearchParams` | Filters, pagination, search, sort |
| Form data | Uncontrolled DOM inputs (`defaultValue`) | Input values in `<Form>` |
| Transient UI | `useState` | Sheet open/close, delete confirm, mount guard |

`useState` is for transient UI only: modal open/close, delete confirmation toggle, client-only-lib mount guards. For server data and URL state, see `/react-router`.

### Derive state during render

Use `useMemo` for derived state — never use `useEffect` to sync derived values:

```tsx
// CORRECT
const filtered = useMemo(() => items.filter(predicate), [items, predicate]);

// WRONG
const [filtered, setFiltered] = useState([]);
useEffect(() => { setFiltered(items.filter(predicate)); }, [items, predicate]);
```

---

## 4. Hooks & Composition

### When to extract a custom hook

Extract a hook when:
- Logic is shared between 2+ components
- A component has complex state management that obscures its rendering intent
- You need to test the logic independently from the UI

Don't extract when:
- The logic is used in only one component and is simple
- The "hook" would just be a thin wrapper around a single `useState`

### Naming conventions

- `use` prefix is mandatory (React enforces this)
- Name describes what the hook provides, not how: `useAssets()` not `useFetchAssets()`
- Return an object for 3+ values, a tuple for 1-2: `const [value, setValue] = useToggle()`

### Hook testing

Test hooks with `renderHook` from Testing Library:

```tsx
import { renderHook, act } from "@testing-library/react";

test("useToggle toggles value", () => {
  const { result } = renderHook(() => useToggle(false));
  expect(result.current[0]).toBe(false);
  act(() => result.current[1]());
  expect(result.current[0]).toBe(true);
});
```

Wrap hooks that need providers in a wrapper:

```tsx
const wrapper = ({ children }: { children: ReactNode }) => (
  <MemoryRouter>{children}</MemoryRouter>
);

const { result } = renderHook(() => useAssetFilters(), { wrapper });
```

---

## 5. Anti-Patterns

| Anti-pattern | Problem | Fix |
| --- | --- | --- |
| Prop drilling through 4+ levels | Fragile, hard to refactor | Context or composition |
| `useLayoutEffect` without SSR guard | Server warning, runs as `useEffect` on server | `useEffect` or `useIsomorphicLayoutEffect` |
| `useEffect` for derived state | Extra render cycle, stale values | Compute during render with `useMemo` |
| Manual `useMemo`/`useCallback` everywhere | Noise, premature optimization | React Compiler handles memoization |

For SPA-era anti-patterns that conflict with React Router v7 (useEffect for fetching, onClick + fetch, client-side caching libraries), see `/react-router` §8.

---

## Cross-references

- `/react-router` — Loaders, actions, Form, useFetcher, URL state, optimistic UI, route type safety
- `/typescript` — TypeScript strictness, route type safety, testing (Vitest/Playwright), modules, build tooling
- `/ux-design` — Component API design, server-validated form UX, accessibility
- `/css-responsive` — Responsive rendering, Tailwind CSS patterns
