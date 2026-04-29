# Expert Patterns

Read this reference when a Vue admin task touches generated API contracts, mock/proxy setup, permissions, error states, reusable table/form abstractions, testing, bundle performance, or observability.

## API Contracts

Prefer generated contracts over hand-written DTOs when the backend exposes OpenAPI.

Recommended structure:

```
packages/api-contracts/
|-- package.json
|-- openapi/
|   `-- admin.yaml
`-- src/
    |-- generated/
    `-- index.ts
```

Rules:

- Generate types or SDKs from the backend OpenAPI spec into `packages/api-contracts`.
- Keep app-specific alova methods in `apps/admin/src/shared/api` or feature modules; do not edit generated files by hand.
- Re-export only stable public types from `packages/api-contracts/src/index.ts`.
- Add a CI check that runs contract generation and fails if generated output is stale.
- Keep UI form models separate from generated API payload types when forms have temporary fields, labels, confirmation values, or client-only validation.

Example scripts:

```json
{
  "scripts": {
    "api:gen": "openapi-typescript ./openapi/admin.yaml -o ./src/generated/schema.ts",
    "api:check": "bun run api:gen && git diff --exit-code ./src/generated"
  }
}
```

Use one generator consistently. Good choices include `openapi-typescript` for type-only output, Orval for generated clients, or Hey API OpenAPI tooling when the team wants a generated SDK. If the generated client does not match alova conventions, generate types only and keep alova method factories handwritten.

## Mock And Proxy

Use Vite proxy for normal local integration with a real backend. Use MSW for offline demos, component tests, deterministic E2E setup, and backend-unavailable work.

Environment flags:

```bash
VITE_API_BASE_URL=/api
VITE_API_PROXY_TARGET=http://localhost:8080
VITE_USE_MOCK=false
```

Vite proxy pattern:

```ts
server: {
  proxy: {
    '/api': {
      target: process.env.VITE_API_PROXY_TARGET,
      changeOrigin: true,
      rewrite: path => path.replace(/^\/api/, '')
    }
  }
}
```

MSW structure:

```
src/mocks/
|-- browser.ts
|-- handlers.ts
`-- fixtures/
```

Rules:

- Do not allow mocks to silently diverge from generated API contracts.
- Keep fixtures small and domain-realistic.
- Enable MSW only through explicit env flags or test setup.
- Use proxy for integration debugging and MSW for deterministic tests.

## Permissions

Model permissions in four layers:

- Route access: route meta and dynamic route filtering.
- Menu visibility: filtered from permitted route records or backend menu data.
- Action visibility: buttons, table row actions, toolbar actions, and batch operations.
- Backend enforcement: every protected API must enforce authorization server-side.

Frontend helpers:

```
src/shared/permission/
|-- usePermission.ts
|-- vPermission.ts
`-- constants.ts
```

Rules:

- Use permission codes for fine-grained actions, such as `user:create` or `role:assign`.
- Use roles only for broad navigation or product tiers.
- Prefer hiding unavailable actions. Disable actions only when the user needs to see why they cannot act.
- Never rely on frontend permission checks for security.
- Test permission filtering for routes, menus, tabs, buttons, and direct URL entry.

## Error And Empty States

Every data workflow should define:

- Initial loading state.
- Empty state with the active filter context.
- Forbidden state for 403.
- Not found state for deleted or inaccessible resources.
- Validation error mapping for forms.
- Network/server error state with retry.
- Destructive action confirmation and failure recovery.

API error model:

```ts
export interface AppError {
  status?: number;
  code: string;
  message: string;
  fieldErrors?: Record<string, string>;
  requestId?: string;
}
```

Rules:

- Normalize errors in the alova response layer.
- Show field-level validation errors inside `el-form` when the API returns them.
- Include `requestId` or trace ID in support-facing error details when available.
- Keep empty states compact in dense admin pages; do not use marketing-style illustrations for operational tools.

## Table And Form Abstractions

Do not build a universal CRUD framework too early.

Create shared abstractions only when at least three real pages repeat the same behavior. Prefer composables before large wrapper components.

Good candidates:

- `useTableQuery` for query state, pagination, loading, refresh, and URL sync.
- `useSelection` for batch operations.
- `useSubmitLock` for form submit dedupe.
- `SearchForm` only after filter layouts repeat.

Rules:

- Keep route-level pages readable and feature-oriented.
- Allow feature pages to own unusual UI instead of forcing them into generic schemas.
- Keep table column definitions close to the feature unless reused.
- Sync filters and pagination to the URL when users need reload/share/back-button behavior.

## Testing

Use a layered testing strategy:

- Vitest: pure utilities, stores, permission filters, API transformers, and composables.
- Vue Test Utils: complex forms, permission-gated buttons, table row actions, dialogs, and error states.
- Playwright: login, route guard behavior, side menu navigation, list search, create/edit/delete, logout, and direct URL access.
- MSW: deterministic API responses for component tests and selected E2E tests.

Suggested scripts:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:e2e": "playwright test"
  }
}
```

Rules:

- Test permission denial and direct URL entry, not only happy paths.
- Test validation errors returned from the backend.
- Keep Playwright smoke tests short and critical-path focused.
- Use generated contract types in test fixtures where possible.

## Performance

Use measurement before adding optimization complexity.

Rules:

- Run bundle analysis when adding chart, editor, map, spreadsheet, PDF, or rich-text dependencies.
- Import chart libraries, editors, and maps lazily at route/component boundaries.
- Keep Element Plus and icons on demand.
- Use table virtualization only when real row counts justify it.
- Avoid large global utility imports; prefer per-function imports when the package requires it.
- Use manual chunks only after bundle analysis shows a stable split benefit.

Suggested tools:

- `rollup-plugin-visualizer` for bundle inspection.
- Vite build output and browser coverage for quick checks.
- Real browser profiling for slow table rendering and form-heavy pages.

## Observability

Production admin apps need actionable frontend telemetry.

Capture:

- Unhandled errors and rejected promises.
- Route name/path, app version, environment, and release.
- API failure metadata: status, endpoint pattern, request ID, and sanitized error code.
- User identity only as a non-sensitive ID when policy allows it.

Never capture:

- Access tokens or refresh tokens.
- Passwords, verification codes, or secrets.
- Full request bodies for sensitive forms.
- Raw PII unless the product policy explicitly allows it.

Rules:

- Enable observability only for non-local environments unless debugging requires otherwise.
- Sanitize events before sending them.
- Tie releases to commit SHA or CI build ID.
- Surface request IDs in user-facing support flows when available.
