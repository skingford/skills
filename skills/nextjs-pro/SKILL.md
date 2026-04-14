---
name: nextjs-pro
description: "Next.js architecture patterns with bun and Turborepo monorepo conventions. Use when building, reviewing, or refactoring Next.js applications. Covers monorepo structure, App Router, server/client components, data fetching, state management, styling, TypeScript, performance, testing, and deployment. Triggers on tasks involving Next.js files, React Server Components, App Router setup, or bun workspace configuration."
agents: [claude, codex, cursor]
---

# Next.js Pro

Opinionated Next.js architecture patterns for bun + Turborepo monorepos with App Router.

## When to Use

Use this skill when:

- Setting up a new Next.js project or monorepo
- Building features with the App Router
- Deciding server vs client component boundaries
- Implementing data fetching or server actions
- Reviewing Next.js application architecture

Do NOT use this skill when:

- Working on non-Next.js React applications (plain Vite/CRA)
- The project uses Pages Router by explicit decision
- Building a static site with no server-side rendering needs

## Monorepo Project Structure

Use bun workspaces with Turborepo for build orchestration.

```
monorepo/
├── apps/
│   ├── web/                    # Main Next.js app
│   │   ├── app/                # App Router
│   │   ├── next.config.ts
│   │   └── package.json
│   └── docs/                   # Docs site (Next.js / Starlight / etc.)
├── packages/
│   ├── ui/                     # Shared React component library
│   │   ├── src/
│   │   └── package.json
│   ├── db/                     # Database schema + client (Drizzle / Prisma)
│   ├── config-typescript/      # Shared tsconfig
│   ├── config-eslint/          # Shared ESLint config
│   ├── config-tailwind/        # Shared Tailwind config
│   └── utils/                  # Shared utilities
├── turbo.json
├── bun.lock
├── package.json                # Root workspace config
└── tsconfig.json
```

- `apps/` for deployable applications, `packages/` for shared libraries
- NEVER put shared code in an app — extract to a package under `packages/`
- Use internal packages (no build step, transpiled by the consuming app) for monorepo-only code
- Reference packages via workspace protocol: `"@repo/ui": "workspace:*"`

Root `package.json`:

```json
{
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "devDependencies": {
    "turbo": "latest"
  }
}
```

`turbo.json`:

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "check-types": {
      "dependsOn": ["^build"]
    }
  }
}
```

## App Router Architecture

| File | Purpose |
|------|---------|
| `page.tsx` | Route UI (required for route to be accessible) |
| `layout.tsx` | Shared UI wrapping children (persists across navigation) |
| `loading.tsx` | Suspense fallback for the route segment |
| `error.tsx` | Error boundary (must be `'use client'`) |
| `not-found.tsx` | 404 UI |
| `route.ts` | API endpoint (GET, POST, etc.) |
| `template.tsx` | Like layout but re-mounts on every navigation |

- Use route groups `(marketing)`, `(dashboard)` for distinct layouts without affecting URL
- Dynamic routes: `[slug]`, `[...catchAll]`, `[[...optional]]`
- Parallel routes with `@slot` for rendering multiple pages simultaneously in one layout
- Colocate components, hooks, and utilities alongside the route that uses them
- NEVER mix `route.ts` and `page.tsx` in the same directory

```
app/
├── (marketing)/
│   ├── layout.tsx              # Hero header + footer
│   ├── page.tsx                # Landing page
│   └── pricing/page.tsx
├── (dashboard)/
│   ├── layout.tsx              # Sidebar + topbar
│   ├── page.tsx                # Dashboard home
│   ├── settings/page.tsx
│   └── @modal/                 # Parallel route for modals
│       └── (.)edit/page.tsx
├── api/
│   └── webhooks/route.ts
└── layout.tsx                  # Root layout (html, body, providers)
```

## Server and Client Components

Server components are the DEFAULT — no directive needed.

Add `'use client'` ONLY when the component needs:
- `useState`, `useReducer`, `useEffect`, `useRef`
- Event handlers (`onClick`, `onChange`, `onSubmit`)
- Browser APIs (`window`, `document`, `localStorage`)
- Third-party client-only libraries (charts, maps, editors)

Push the `'use client'` boundary as LOW as possible — to leaf/interactive components.

| Server Component | Client Component |
|-----------------|-----------------|
| Data fetching | Event handlers |
| Database / secret access | useState, useEffect |
| Heavy deps (markdown, syntax highlight) | Browser APIs |
| Static content rendering | Interactive libraries (charts, maps) |

```tsx
// Good — server component passes children to client wrapper
// LikeButton.tsx
'use client';
export function LikeButton({ postId }: { postId: string }) {
  const [liked, setLiked] = useState(false);
  return <button onClick={() => setLiked(!liked)}>♥</button>;
}

// page.tsx (server component)
export default async function PostPage({ params }: { params: { id: string } }) {
  const post = await db.query.posts.findFirst({ where: eq(posts.id, params.id) });
  return (
    <article>
      <h1>{post.title}</h1>
      <p>{post.content}</p>
      <LikeButton postId={post.id} />
    </article>
  );
}

// Bad — marking the entire page as client
'use client';
export default function PostPage() { /* now everything is client-rendered */ }
```

- NEVER import server-only modules (database, fs, secrets) in a client component
- Use the `server-only` package to guard server-exclusive modules:

```ts
import 'server-only';
import { db } from '@repo/db';
export function getSecretData() { /* safe — build error if imported in client */ }
```

## Data Fetching

| Pattern | When to Use |
|---------|-------------|
| Server component `fetch` / DB query | Reading data for page render |
| Server Actions (`'use server'`) | Mutations (create, update, delete) |
| Route Handlers (`route.ts`) | Webhooks, external API proxy, non-UI endpoints |

- NEVER use `useEffect` + `fetch` for data that can be fetched on the server
- Use `revalidatePath()` or `revalidateTag()` after mutations

```tsx
// Good — server component data fetching
export default async function UsersPage() {
  const users = await db.query.users.findMany();
  return <UserList users={users} />;
}

// Bad — client-side fetch for server-available data
'use client';
export default function UsersPage() {
  const [users, setUsers] = useState([]);
  useEffect(() => {
    fetch('/api/users').then(r => r.json()).then(setUsers);
  }, []);
  return <UserList users={users} />;
}
```

Server Actions for mutations:

```tsx
// actions.ts
'use server';

export async function createUser(formData: FormData) {
  const name = formData.get('name') as string;
  await db.insert(users).values({ name });
  revalidatePath('/users');
}

// form.tsx ('use client')
import { createUser } from './actions';
export function CreateUserForm() {
  return (
    <form action={createUser}>
      <input name="name" required />
      <button type="submit">Create</button>
    </form>
  );
}
```

## State Management

- URL state (searchParams) for filters, sort, pagination, tabs — shareable and bookmarkable
- Use `nuqs` for type-safe searchParams management
- Server data is NOT client state — fetch it on the server, no caching stores needed
- Client state only for ephemeral UI: modal open/closed, form input, hover/focus
- NEVER use Redux/Zustand for data available on the server
- If client state is needed, scope React context to the nearest subtree, not global providers

```tsx
// Good — URL state for filters
import { useQueryState } from 'nuqs';

export function SearchFilter() {
  const [query, setQuery] = useQueryState('q');
  return <input value={query ?? ''} onChange={e => setQuery(e.target.value)} />;
}

// Bad — local state for something that should be in the URL
const [query, setQuery] = useState('');
// Lost on page refresh, not shareable, not bookmarkable
```

## Styling

- Tailwind CSS as the default — use built-in Next.js + Tailwind integration
- Create a shared `cn()` utility with `clsx` + `tailwind-merge`:

```ts
// packages/ui/src/lib/utils.ts
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

- Use `class-variance-authority` (cva) for component variants
- Configure Tailwind in `packages/config-tailwind` and share across the monorepo
- CSS Modules as fallback for complex animations or third-party style isolation
- NEVER use runtime CSS-in-JS (styled-components, emotion) — conflicts with server components

```tsx
// Good — Tailwind with cva for variants
import { cva } from 'class-variance-authority';

const button = cva('rounded-lg px-4 py-2 font-medium transition-colors', {
  variants: {
    variant: {
      primary: 'bg-blue-600 text-white hover:bg-blue-700',
      secondary: 'bg-gray-100 text-gray-900 hover:bg-gray-200',
    },
  },
  defaultVariants: { variant: 'primary' },
});

export function Button({ variant, className, ...props }) {
  return <button className={cn(button({ variant }), className)} {...props} />;
}

// Bad — runtime CSS-in-JS
import styled from 'styled-components';
const Button = styled.button`background: ${p => p.primary ? 'blue' : 'gray'};`;
```

## TypeScript Configuration

- ALWAYS enable `"strict": true` in all tsconfig files
- Create a shared base config in `packages/config-typescript`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "compilerOptions": {
    "strict": true,
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "ES2022"],
    "jsx": "preserve",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "incremental": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "esModuleInterop": true
  }
}
```

- Path aliases: `@/` for app-local imports, `@repo/` for monorepo packages
- Share types via `packages/db` exports or a dedicated `packages/types`
- NEVER use `any` — use `unknown` with type guards or Zod validation
- NEVER disable strict mode to "fix" type errors

## Performance

- Use `next/image` for ALL images — never raw `<img>` tags
- Use `next/font` for font loading — no external stylesheet links for fonts
- Use `<Suspense>` boundaries to enable streaming and avoid data waterfalls
- Dynamic imports (`next/dynamic`) for heavy client components (charts, editors, maps)
- Use `@next/bundle-analyzer` to audit bundle size
- NEVER block the entire page on a single slow data fetch

```tsx
// Good — streaming with Suspense
export default function DashboardPage() {
  return (
    <div>
      <h1>Dashboard</h1>
      <Suspense fallback={<StatsSkeleton />}>
        <Stats />
      </Suspense>
      <Suspense fallback={<ChartSkeleton />}>
        <RevenueChart />
      </Suspense>
    </div>
  );
}

// Bad — sequential blocking
export default async function DashboardPage() {
  const stats = await getStats();           // blocks
  const chart = await getRevenueChart();    // waits for stats
  return <div>...</div>;                    // nothing renders until both resolve
}
```

```tsx
// Good — dynamic import for heavy component
import dynamic from 'next/dynamic';
const Chart = dynamic(() => import('./Chart'), {
  loading: () => <ChartSkeleton />,
  ssr: false,
});
```

## Testing

- Vitest for unit and integration tests (faster than Jest, native ESM support)
- React Testing Library for component interaction tests
- Playwright for E2E tests
- Test server actions by testing the underlying data logic directly
- Use `bun run test` as the test runner alias

```ts
// Good — testing server action logic
import { createUser } from './actions';

test('creates user with valid data', async () => {
  const formData = new FormData();
  formData.set('name', 'Alice');
  await createUser(formData);
  const user = await db.query.users.findFirst({
    where: eq(users.name, 'Alice'),
  });
  expect(user).toBeDefined();
});
```

```ts
// vitest.config.ts (per-app)
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./tests/setup.ts'],
  },
  resolve: {
    alias: { '@': './src' },
  },
});
```

## Deployment

- Vercel as the primary deployment target (zero-config for Next.js)
- For self-hosted: use `output: 'standalone'` in `next.config.ts` with Docker
- Environment variables: `NEXT_PUBLIC_` prefix ONLY for values safe to expose in the client bundle
- NEVER put secrets in `NEXT_PUBLIC_` variables
- Use `.env.local` for local development, never commit it
- For monorepo on Vercel: set root directory to the specific app (`apps/web`)

```ts
// next.config.ts — standalone for Docker
import type { NextConfig } from 'next';

const config: NextConfig = {
  output: 'standalone',
  transpilePackages: ['@repo/ui', '@repo/utils'],
};

export default config;
```

```dockerfile
FROM oven/bun:1 AS base
WORKDIR /app

FROM base AS deps
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN bun run build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder /app/apps/web/public ./apps/web/public
EXPOSE 3000
CMD ["bun", "apps/web/server.js"]
```

```bash
# Good — server-only secret
DATABASE_URL=postgresql://...

# Bad — secret exposed to client bundle
NEXT_PUBLIC_DATABASE_URL=postgresql://...
```

## Recommended Scope

- **Scope**: Both (Global for Next.js-heavy developers, Project-level for mixed-stack teams)
- **Global**: `npx skills add skingford/skills --skill nextjs-pro -g -y`
- **Project**: `npx skills add skingford/skills --skill nextjs-pro -y`
