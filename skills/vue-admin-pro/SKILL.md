---
name: vue-admin-pro
description: "Vue admin dashboard architecture patterns for Vue 3, Vite, Bun workspaces monorepos, TypeScript, Pinia, Element Plus, alova, SCSS styling, unplugin auto imports, OpenAPI contracts, mock/proxy workflows, permissions, testing, performance, and observability. Use when building, reviewing, or refactoring admin systems, dashboard layouts, RBAC/permission routing, API clients, data tables/forms, state management, SCSS architecture, Vite auto-import setup, or workspace structure in Vue/Vite admin projects. Triggers on tasks involving Vue SFCs, Vite config, Bun monorepos, Pinia stores, Element Plus components, alova request modules, SCSS files, unplugin-auto-import/unplugin-vue-components, OpenAPI type generation, MSW/proxy setup, Vitest/Playwright, bundle analysis, or Sentry-style telemetry."
---

# Vue Admin Pro

Opinionated architecture guidance for production Vue admin dashboards built with Vue 3, Vite, Bun, TypeScript, Pinia, Element Plus, alova, SCSS, and unplugin auto imports.

## Architecture Goals

- Optimize for dense operational workflows: fast scanning, stable tables, predictable forms, and low-friction navigation.
- Use Vue 3 Composition API with `<script setup lang="ts">` by default.
- Keep server data in alova request methods and hooks; keep durable client UI/session state in Pinia.
- Use SCSS for global style tokens, layout styles, Element Plus overrides, and component-local `<style scoped lang="scss">`. Configure Vite to inject global SCSS variables/mixins by default.
- Use Vite with `unplugin-auto-import` as the default for Vue/Vue Router/Pinia common APIs, and `unplugin-vue-components` as the default for Element Plus on-demand components.
- Split by deployable apps and reusable packages in the monorepo; do not hide shared code inside `apps/admin`.
- Prefer typed contracts, route meta, and explicit feature modules over implicit globals.

## Monorepo Structure

Use Bun workspaces. Put deployable applications in `apps/` and shared libraries in `packages/`.

```
monorepo/
|-- apps/
|   `-- admin/
|       |-- index.html
|       |-- package.json
|       |-- tsconfig.json
|       |-- vite.config.ts
|       `-- src/
|           |-- app/                 # app bootstrap and providers
|           |-- assets/
|           |-- features/            # domain modules
|           |-- layouts/             # admin shell layouts
|           |-- pages/               # route-level views
|           |-- router/              # routes, guards, permissions
|           |-- shared/              # app-local shared code
|           |-- stores/              # global Pinia stores
|           `-- styles/
|-- packages/
|   |-- api-contracts/               # OpenAPI/generated DTOs or shared API types
|   |-- shared/                      # pure utilities and domain helpers
|   |-- ui/                          # optional shared Vue components
|   |-- config-eslint/
|   `-- config-typescript/
|-- bun.lock
|-- package.json
`-- tsconfig.json
```

- Keep the root `package.json` private and dependency-light. Each workspace should declare its own dependencies.
- Reference internal packages with `"workspace:*"`.
- Use `packages/ui` only for reusable components that are useful outside the admin app. Keep feature-specific UI under `apps/admin/src/features/<feature>/`.

Root `package.json`:

```json
{
  "name": "admin-monorepo",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "dev": "bun --filter @repo/admin dev",
    "build": "bun run --workspaces build",
    "typecheck": "bun run --workspaces typecheck",
    "lint": "bun run --workspaces lint"
  }
}
```

`apps/admin/package.json`:

```json
{
  "name": "@repo/admin",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0 --mode development",
    "build:dev": "vue-tsc -b && vite build --mode development",
    "build:test": "vue-tsc -b && vite build --mode test",
    "build:staging": "vue-tsc -b && vite build --mode staging",
    "build:prod": "vue-tsc -b && vite build --mode production",
    "build": "vue-tsc -b && vite build",
    "preview": "vite preview",
    "typecheck": "vue-tsc -b --noEmit",
    "lint": "eslint ."
  },
  "dependencies": {
    "@repo/api-contracts": "workspace:*",
    "@repo/shared": "workspace:*",
    "alova": "latest",
    "element-plus": "latest",
    "pinia": "latest",
    "vue": "latest",
    "vue-router": "latest"
  },
  "devDependencies": {
    "@iconify-json/ep": "latest",
    "@vitejs/plugin-vue": "latest",
    "sass-embedded": "latest",
    "sharp": "latest",
    "svgo": "latest",
    "typescript": "latest",
    "unplugin-auto-import": "latest",
    "unplugin-icons": "latest",
    "unplugin-vue-components": "latest",
    "vite": "latest",
    "vite-plugin-checker": "latest",
    "vite-plugin-compression": "latest",
    "vite-plugin-image-optimizer": "latest",
    "vite-plugin-vue-devtools": "latest",
    "vue-tsc": "latest"
  }
}
```

Pin real dependency and Bun versions according to the team release policy. Do not leave `"latest"` in committed production scaffolds unless the repository intentionally tracks latest releases.

## Vite Configuration

Use Vite as the app bundler and keep admin-specific aliases local to `apps/admin`. Auto-import Vue, Vue Router, Pinia, and app composables by default. Load Element Plus on demand through unplugin resolvers; do not globally register all of Element Plus. Use Vite `mode` to distinguish local development, test/staging builds, and production builds.

```ts
import { fileURLToPath, URL } from 'node:url';
import vue from '@vitejs/plugin-vue';
import AutoImport from 'unplugin-auto-import/vite';
import IconsResolver from 'unplugin-icons/resolver';
import Icons from 'unplugin-icons/vite';
import Components from 'unplugin-vue-components/vite';
import { ElementPlusResolver } from 'unplugin-vue-components/resolvers';
import { defineConfig } from 'vite';
import checker from 'vite-plugin-checker';
import viteCompression from 'vite-plugin-compression';
import { ViteImageOptimizer } from 'vite-plugin-image-optimizer';
import VueDevTools from 'vite-plugin-vue-devtools';

const elementPlusResolver = ElementPlusResolver({
  importStyle: 'sass'
});
const scssGlobalData = '@use "@/styles/globals.scss" as *;\n';

export default defineConfig(({ command, mode }) => {
  const isServe = command === 'serve';
  const isBuild = command === 'build';
  const isTest = mode === 'test' || mode === 'staging';
  const isProd = mode === 'production';
  const enableDevTools = isServe && !isProd;
  const enableChecker = isServe || isTest;
  const enableBuildOptimization = isBuild && isProd;

  return {
    plugins: [
      vue(),
      enableDevTools && VueDevTools(),
      enableChecker && checker({
        vueTsc: true,
        eslint: {
          lintCommand: 'eslint "./src/**/*.{vue,ts,tsx}"'
        }
      }),
      AutoImport({
        imports: [
          'vue',
          'vue-router',
          'pinia'
        ],
        dirs: [
          'src/shared/composables',
          'src/stores'
        ],
        vueTemplate: true,
        resolvers: [elementPlusResolver],
        dts: 'src/auto-imports.d.ts'
      }),
      Components({
        dirs: ['src/shared/components'],
        resolvers: [
          elementPlusResolver,
          IconsResolver({
            prefix: 'Icon',
            enabledCollections: ['ep']
          })
        ],
        dts: 'src/components.d.ts'
      }),
      Icons({
        compiler: 'vue3',
        autoInstall: false
      }),
      enableBuildOptimization && ViteImageOptimizer({
        logStats: true,
        includePublic: true,
        png: { quality: 85 },
        jpeg: { quality: 82 },
        jpg: { quality: 82 },
        webp: { quality: 82 }
      }),
      enableBuildOptimization && viteCompression({
        algorithm: 'gzip',
        ext: '.gz',
        threshold: 10240,
        deleteOriginFile: false
      }),
      enableBuildOptimization && viteCompression({
        algorithm: 'brotliCompress',
        ext: '.br',
        threshold: 10240,
        deleteOriginFile: false
      })
    ].filter(Boolean),
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
        '@repo/shared': fileURLToPath(new URL('../../packages/shared/src', import.meta.url))
      }
    },
    css: {
      preprocessorOptions: {
        scss: {
          additionalData: scssGlobalData
        }
      }
    },
    server: {
      port: 5173
    }
  };
});
```

- Use `unplugin-auto-import` for Vue APIs, Vue Router APIs, Pinia APIs, app composables/stores, and Element Plus composables/messages.
- Use `unplugin-vue-components` for shared app components and Element Plus component on-demand imports.
- Keep Element Plus as on-demand by default. Do not call `app.use(ElementPlus)` or import `element-plus/dist/index.css` unless the project explicitly chooses full import.
- Add `unplugin-element-plus` only when manually importing Element Plus components and needing automatic style imports.
- Use `vite-plugin-vue-devtools` only for local `serve` mode, never for production builds.
- Use `vite-plugin-checker` for local development and test/staging builds. Keep `vue-tsc -b` in build scripts as the final CI gate.
- Use `unplugin-icons` through `Icons()` plus `IconsResolver()`; install only the icon collections the project uses, such as `@iconify-json/ep`.
- Use compression and image optimization only for production builds unless a test environment explicitly validates CDN/server compression behavior.
- Prefer `vite-plugin-compression` for generated gzip/brotli side files when the deployment server is configured to serve them. Prefer CDN/server compression instead if the platform already handles this reliably.
- Use `vite-plugin-image-optimizer` only when static image assets justify build-time processing; install `sharp` and `svgo` explicitly because they are peer/runtime optimizer dependencies.
- Import feature-local components explicitly unless the project has a clear auto-import convention for `src/features/**/components`.
- Install one Sass implementation. Prefer `sass-embedded` for current Vite projects; use `sass` only when the repository standard requires it.
- Configure `css.preprocessorOptions.scss.additionalData` so global SCSS variables and mixins are available in every `.scss` file and Vue SFC `<style lang="scss">` block.
- Commit generated `auto-imports.d.ts` and `components.d.ts` only if the project convention does so; otherwise ensure they are included by TypeScript locally.

Environment policy:

| Mode | Command | Env File | Plugin Policy |
|------|---------|----------|---------------|
| Development | `bun run dev` or `bun run build:dev` | `.env.development` | Enable Vue DevTools, checker overlay, auto imports, icons, SCSS globals. Disable compression/image optimization. |
| Test | `bun run build:test` | `.env.test` | Enable checker, auto imports, icons, SCSS globals. Disable Vue DevTools. Usually disable compression/image optimization unless deployment parity requires them. |
| Staging | `bun run build:staging` | `.env.staging` | Same as test unless staging validates production CDN/compression behavior. |
| Production | `bun run build:prod` | `.env.production` | Enable auto imports, icons, SCSS globals, image optimization, gzip/brotli generation. Disable Vue DevTools and checker overlay. |

## Environment Variables

Use Vite mode-specific env files for multi-environment builds.

```
apps/admin/
|-- .env                    # shared defaults, committed
|-- .env.development        # local development defaults, committed if safe
|-- .env.test               # test environment build values
|-- .env.staging            # staging/pre-production build values
|-- .env.production         # production build values
|-- .env.local              # local overrides, gitignored
`-- .env.production.local   # production-only local override, gitignored
```

Vite env loading rules:

- `.env` and `.env.local` are loaded for every mode.
- `.env.[mode]` and `.env.[mode].local` are loaded only for that mode.
- Mode-specific files override generic `.env` values.
- Existing shell environment variables have the highest priority.
- With Bun, variables already preloaded into the process can override Vite mode files; do not put mode-specific `VITE_*` values in a shared shell/root environment.
- Only variables prefixed with `VITE_` are exposed to client code through `import.meta.env`.
- Do not put secrets, API keys, database URLs, or private tokens in `VITE_` variables.
- Add `*.local` to `.gitignore`.

Example `.env.production`:

```bash
VITE_APP_ENV=production
VITE_APP_TITLE=Admin Console
VITE_API_BASE_URL=https://api.example.com
VITE_PUBLIC_PATH=/
```

Type env variables in `src/vite-env.d.ts`:

```ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_APP_ENV: 'development' | 'test' | 'staging' | 'production';
  readonly VITE_APP_TITLE: string;
  readonly VITE_API_BASE_URL: string;
  readonly VITE_PUBLIC_PATH?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

Use `import.meta.env.MODE` for mode checks and `import.meta.env.VITE_*` for public build-time values. Do not confuse Vite mode with `NODE_ENV`; `vite build --mode development` still runs a build command unless `NODE_ENV` is explicitly changed.

## Expert Extensions

Read [Expert Patterns](references/expert-patterns.md) when the task involves generated API contracts, mock/proxy workflows, action-level permissions, error/empty states, reusable table/form abstractions, testing strategy, bundle performance, or production observability.

Default expert rules:

- Generate API contracts from OpenAPI into `packages/api-contracts`; do not hand-maintain DTOs that the backend contract owns.
- Use Vite proxy for normal local backend integration and MSW for offline/demo/component-test mocks.
- Enforce permissions at route, menu, page action, and API layers. Frontend checks improve UX only; backend authorization is mandatory.
- Standardize loading, empty, forbidden, validation-error, network-error, and retry states for every table/form workflow.
- Add shared table/form abstractions only after repeated real pages prove the shape.
- Use Vitest for stores/composables/utilities, Vue Test Utils for complex components, and Playwright for critical admin flows.
- Analyze production bundles before adding large chart/editor/map dependencies.
- Capture production frontend errors with release, route, environment, and sanitized user context.

## App Bootstrap

Keep bootstrap code boring and explicit.

```
src/app/
|-- main.ts
|-- providers.ts
`-- App.vue
```

```ts
import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import { router } from '@/router';
import '@/styles/index.scss';

const app = createApp(App);

app.use(createPinia());
app.use(router);
app.mount('#app');
```

- Register only application-wide providers in `main.ts`.
- Put Element Plus defaults in `ElConfigProvider` near the root layout when using on-demand imports.
- Do not register feature services globally. Import feature API methods where they are used.

## SCSS Styling

Use SCSS as the default CSS authoring format. Keep global style concerns in `src/styles` and component-specific styles inside Vue SFCs with `<style scoped lang="scss">`.

```
src/styles/
|-- index.scss              # reset, base, layout, and Element Plus overrides
|-- globals.scss            # forwarded variables, mixins, and functions for Vite injection
|-- variables.scss          # colors, spacing, z-index, breakpoints
|-- mixins.scss
|-- reset.scss
`-- element-plus.scss       # admin theme overrides
```

`globals.scss` should expose Sass symbols only and should not emit CSS, because Vite injects it into every SCSS file through `additionalData`.

```scss
@forward './variables';
@forward './mixins';
```

`index.scss` is the only global stylesheet imported by `main.ts`.

```scss
@use './reset';
@use './element-plus';

html,
body,
#app {
  min-width: 1024px;
  min-height: 100%;
}
```

Vue SFC styles:

```vue
<style scoped lang="scss">
.user-table {
  padding: $space-4;
}
</style>
```

- Do not repeat `@use '@/styles/globals.scss' as *;` in each component. Vite injects it by default.
- Put reusable design tokens in `variables.scss` and `mixins.scss`.
- Put actual global CSS output in `index.scss`, `reset.scss`, or `element-plus.scss`, not in files injected through `additionalData`.
- Prefer CSS variables for runtime theme switching and Sass variables/mixins for build-time constants.
- Use `:deep()` only for targeted third-party overrides; keep Element Plus-wide overrides in `element-plus.scss`.

## Routing and Permissions

Use Vue Router with typed route meta. Keep permission logic in route guards and permission stores, not scattered through pages.

```ts
declare module 'vue-router' {
  interface RouteMeta {
    title: string;
    requiresAuth?: boolean;
    icon?: string;
    roles?: string[];
    permissions?: string[];
    hidden?: boolean;
    keepAlive?: boolean;
    activeMenu?: string;
  }
}
```

Recommended route split:

```
src/router/
|-- guards.ts
|-- index.ts
|-- static-routes.ts
`-- async-routes.ts
```

- Static routes: login, 403, 404, redirect, and the main layout shell.
- Async routes: business modules gated by backend permissions or role policy.
- Route `name` values must be stable and unique because keep-alive, tabs, breadcrumbs, and dynamic route removal depend on them.
- Use `meta.permissions` for action/resource checks and `meta.roles` only for coarse-grained navigation.
- Generate side menus from route records after permission filtering. Do not maintain a separate menu tree unless the backend owns menus.
- When routes are fetched after login, add them once, then redirect to the original URL so the newly added route can match.

## Pinia State Boundaries

Use Pinia for global client state that must outlive a component.

Good global stores:

- `auth`: token, current user, login/logout, token refresh state.
- `permission`: routes, menus, permission codes, dynamic route registration status.
- `app`: sidebar collapse, device mode, locale, theme, Element Plus size.
- `tabs`: visited views and cached route names if the product uses tab navigation.

Do not put server lists, table rows, search results, or form payloads in Pinia by default. Keep those in alova hooks or page-local composables.

```ts
import { defineStore } from 'pinia';
import { computed, ref } from 'vue';

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(null);
  const user = ref<UserProfile | null>(null);

  const isAuthenticated = computed(() => Boolean(token.value));

  function setSession(nextToken: string, nextUser: UserProfile) {
    token.value = nextToken;
    user.value = nextUser;
  }

  function reset() {
    token.value = null;
    user.value = null;
  }

  return { token, user, isAuthenticated, setSession, reset };
});
```

- Prefer setup stores for TypeScript-heavy admin apps.
- Persist only token/session preferences, not full server responses.
- Keep cross-store dependencies acyclic. If a store needs another store, import it inside actions or setup functions carefully.

## API Layer With Alova

Create one alova instance per backend concern when base URLs, auth, or response envelopes differ.

```
src/shared/api/
|-- http.ts
|-- errors.ts
|-- pagination.ts
`-- methods/
    |-- auth.ts
    `-- users.ts
```

```ts
import { createAlova } from 'alova';
import adapterFetch from 'alova/fetch';
import VueHook from 'alova/vue';
import { useAuthStore } from '@/stores/auth';

export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

export const http = createAlova({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  statesHook: VueHook,
  requestAdapter: adapterFetch(),
  timeout: 30000,
  beforeRequest(method) {
    const auth = useAuthStore();
    method.config.headers = {
      ...method.config.headers,
      ...(auth.token ? { Authorization: `Bearer ${auth.token}` } : {})
    };
  },
  responded: {
    async onSuccess(response) {
      if (response.status === 401) {
        useAuthStore().reset();
        throw new Error('Unauthorized');
      }

      const body = (await response.json()) as ApiResponse<unknown>;
      if (body.code !== 0) {
        throw new Error(body.message || 'Request failed');
      }

      return body.data;
    }
  }
});
```

Define method factories instead of scattering raw URLs through components.

```ts
import type { PageResult, User, UserQuery } from '@repo/api-contracts';
import { http } from '@/shared/api/http';

export function getUsers(params: UserQuery) {
  return http.Get<PageResult<User>>('/users', { params });
}

export function createUser(payload: CreateUserInput) {
  return http.Post<User>('/users', payload);
}
```

Use `useRequest`, `useWatcher`, and related alova client hooks at the top level of `<script setup>`.

```ts
import { useWatcher } from 'alova/client';
import { getUsers } from '@/shared/api/methods/users';

const query = ref<UserQuery>({ page: 1, pageSize: 20, keyword: '' });

const { data, loading, error, send } = useWatcher(
  () => getUsers(query.value),
  [query],
  {
    immediate: true,
    initialData: { total: 0, items: [] }
  }
);
```

- For click-triggered mutations, use `useRequest(() => method(args), { immediate: false })` and call `send`.
- Never call alova hooks inside loops, conditionals, callbacks, or nested functions.
- Use method-level `transform` for one-off response shaping; use the global `responded` interceptor only for envelope/auth/error policy.
- Invalidate or refresh list methods after mutations instead of mutating table rows in place unless the UX requires optimistic updates.

## Feature Modules

Each feature owns its pages, API methods, local components, and domain-specific composables.

```
src/features/users/
|-- api.ts
|-- components/
|   |-- UserEditor.vue
|   `-- UserStatusTag.vue
|-- composables/
|   `-- useUserTable.ts
|-- routes.ts
|-- types.ts
`-- pages/
    |-- UserListPage.vue
    `-- UserDetailPage.vue
```

- Keep route-level pages thin: compose table/form/detail components and wire data hooks.
- Put repeated query/table behavior in `composables/`.
- Put reusable display widgets under `components/`.
- Promote code to `src/shared` or `packages/*` only after it is reused by more than one feature.

## Element Plus Admin Patterns

Use Element Plus as the default component system for forms, tables, layout controls, dialogs, and feedback.

- Use `el-table` for operational data grids until virtualization or advanced column control is required.
- Use `el-form` with typed form models and explicit validation rules for create/edit flows.
- Use `el-dialog` or route-driven drawer/detail pages based on workflow depth. Use dialogs for short edits, routes for work that needs linking, reload survival, or multi-step context.
- Use `ElMessage` for transient operation results and `ElMessageBox` for destructive confirmations.
- Use `ElConfigProvider` for global size, locale, and z-index.

Table page baseline:

```vue
<template>
  <section class="page">
    <el-form :model="query" inline>
      <el-form-item label="Keyword">
        <el-input v-model="query.keyword" clearable />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" @click="send">Search</el-button>
      </el-form-item>
    </el-form>

    <el-table v-loading="loading" :data="data.items" row-key="id">
      <el-table-column prop="name" label="Name" min-width="160" />
      <el-table-column prop="email" label="Email" min-width="220" />
    </el-table>
  </section>
</template>
```

- Keep table columns stable with `min-width`, `row-key`, and explicit formatter components.
- Store pagination and filters in URL query when users need shareable or restorable pages.
- Avoid building a heavy table abstraction until at least three real pages need the same behavior.

## TypeScript Rules

- Define API DTOs in `packages/api-contracts` or generate them from OpenAPI.
- Keep UI form types separate from API payload types when validation, labels, or temporary fields differ.
- Use `unknown` at API boundaries and parse/validate if the backend contract is not trustworthy.
- Avoid `any` in stores, route meta, and API methods.
- Use `import type` for DTOs and Vue Router types.

Common shared types:

```ts
export interface PageResult<T> {
  total: number;
  items: T[];
}

export interface PageQuery {
  page: number;
  pageSize: number;
}
```

## Auth and Security

- Keep access tokens out of route query strings and logs.
- Store tokens in the narrowest viable place for the product's threat model. If local storage is required, centralize persistence in the auth store.
- Normalize 401 handling in the alova response interceptor.
- Do not trust frontend route filtering as authorization. Backend APIs must enforce permissions.
- Read public build-time values only from `VITE_` environment variables. Never expose secrets through Vite env.

## Quality Gates

Use these checks before considering an admin change complete:

- `bun run typecheck`
- `bun run lint`
- `bun run build:dev` when a deployable development build is required.
- `bun run build:test` for test/staging environment parity.
- `bun run build:staging` before staging deployment.
- `bun run build:prod` before release, including image optimization and gzip/brotli artifact checks.
- Unit tests for pure utilities, permission filtering, and stores.
- Component tests for complex forms, table actions, and permission-gated UI.
- Playwright or equivalent smoke tests for login, navigation, list search, create/edit, and logout.
- API contract generation and generated-type diff checks when OpenAPI is part of the workflow.
- Bundle analysis when adding charts, editors, maps, large icon sets, or other heavy dependencies.

## Deployment

- Build `apps/admin` as static assets with Vite.
- Configure SPA fallback on the web server or CDN so deep links resolve to `index.html`.
- Keep API base URL and feature flags environment-specific through `VITE_` variables.
- Use `.env.development`, `.env.test`, `.env.staging`, and `.env.production` for separate build targets. Do not point non-production builds at production APIs unless explicitly required.
- Version static assets with Vite output hashing and set long cache headers for immutable assets.
- If `vite-plugin-compression` emits `.gz` or `.br` files, configure Nginx/CDN/object storage to serve them with the correct `Content-Encoding`.

## Review Checklist

- Workspace dependencies live in the workspace that uses them.
- Shared code is in `packages/*` only when it is genuinely shared.
- Route meta is typed and permission logic is centralized.
- Pinia stores do not duplicate alova-managed server data.
- alova method factories are typed and reusable.
- Vue, Vue Router, Pinia, app composables, and stores use the default auto-import setup consistently.
- Element Plus is loaded on demand through unplugin resolvers unless full import is an explicit project decision.
- Element Plus components use stable keys, widths, validation rules, and loading/error states.
- Vite plugins are gated by `mode`: devtools only in dev, checker in dev/test, compression and image optimization in production.
- Development, test, staging, and production builds use separate modes, env files, API bases, and deployment checks.
- Generated API contracts, mock/proxy behavior, action permissions, error states, tests, bundle budgets, and observability follow `references/expert-patterns.md`.
- Pages remain feature-oriented instead of becoming catch-all utility folders.
