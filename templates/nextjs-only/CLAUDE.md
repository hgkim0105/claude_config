# Project Rules

## Stack
- **Frontend**: Next.js 14 (App Router) + shadcn/ui + Tailwind CSS
- **Auth**: Supabase Auth (`@supabase/ssr`)
- **Server State**: TanStack Query
- **Type safety**: openapi-ts (백엔드 OpenAPI → TS 타입 자동 생성)

---

## Project Structure

```
src/
├── app/
│   ├── (public)/          # 인증 불필요 페이지
│   ├── (dashboard)/       # 인증 필요 페이지
│   ├── api/               # Route handlers (프록시 용도만)
│   ├── layout.tsx          # Providers 포함
│   └── providers.tsx       # TanStack Query Provider
├── components/
│   └── {feature}/         # 기능별 컴포넌트
├── lib/
│   ├── api.ts             # JWT 주입 + fetch 래퍼
│   └── utils.ts
├── utils/supabase/
│   ├── client.ts          # 브라우저용
│   └── server.ts          # 서버 컴포넌트용
└── types/                 # openapi-ts 자동 생성 — 수정 금지
middleware.ts
```

---

## Auth — `@supabase/ssr`

```typescript
// src/utils/supabase/client.ts
import { createBrowserClient } from '@supabase/ssr'
export const createClient = () =>
  createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  )

// src/utils/supabase/server.ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
export const createClient = () => {
  const cookieStore = cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll() } },
  )
}
```

```typescript
// middleware.ts
import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request })
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          )
        },
      },
    },
  )
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.redirect(new URL('/login', request.url))
  return response
}

export const config = { matcher: ['/dashboard/:path*'] }
```

---

## API 클라이언트 (`src/lib/api.ts`)

모든 백엔드 호출은 이 클라이언트 사용 — JWT 자동 주입.

```typescript
import { createClient } from '@/utils/supabase/client'

const API_URL = process.env.NEXT_PUBLIC_API_URL

async function getAuthHeaders(): Promise<Record<string, string>> {
  const supabase = createClient()
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return {}
  return { Authorization: `Bearer ${session.access_token}` }
}

export async function apiClient<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const authHeaders = await getAuthHeaders()
  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...authHeaders,
      ...options.headers,
    },
  })
  if (!res.ok) {
    const error = await res.json().catch(() => ({}))
    throw new Error(error.detail ?? `API Error ${res.status}`)
  }
  return res.json()
}
```

---

## TanStack Query 설정

```typescript
// src/app/providers.tsx
'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient())
  return (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  )
}

// src/app/layout.tsx
import { Providers } from './providers'
export default function RootLayout({ children }) {
  return <html><body><Providers>{children}</Providers></body></html>
}
```

---

## Conventions

### Next.js App Router
- Server Component 기본, 인터랙션 있는 것만 `"use client"`
- `app/(public)/` — 인증 불필요
- `app/(dashboard)/` — 인증 필요 (middleware 보호)
- `app/api/` — 프록시 용도만

### API 호출
- 클라이언트 컴포넌트: TanStack Query + `apiClient()`
- 서버 컴포넌트: `createClient()` (server.ts)로 세션 가져온 후 직접 fetch
- `src/types/` 직접 수정 금지 (openapi-ts 자동 생성)

### Components
- shadcn/ui 우선 사용 (`npx shadcn-ui@latest add {component}`)
- 커스텀 컴포넌트는 `components/{feature}/` 하위

---

## openapi-ts 설정

```typescript
// openapi-ts.config.ts
import { defineConfig } from '@hey-api/openapi-ts'
export default defineConfig({
  client: '@hey-api/client-fetch',
  input: 'http://localhost:8000/openapi.json',
  output: { path: 'src/types', format: 'prettier' },
})
```

```bash
# 백엔드 실행 중일 때
npx @hey-api/openapi-ts
```

---

## 환경변수 (`.env.local`)
```
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
NEXT_PUBLIC_API_URL=http://localhost:8000
```

## 패키지 설치
```bash
npm install @supabase/ssr @supabase/supabase-js
npm install @tanstack/react-query
npm install @hey-api/openapi-ts @hey-api/client-fetch
npx shadcn-ui@latest init
```

## 개발 서버
```bash
npm run dev
# → http://localhost:3000
```

---

## Code Style
- TypeScript strict mode, `any` 사용 금지
- 주석: 로직이 자명하지 않을 때만
- 함수/변수명: 의미 있는 이름, 축약 금지
