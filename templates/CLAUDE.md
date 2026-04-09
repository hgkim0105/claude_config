# Project Rules

## Stack
- **Backend**: FastAPI + SQLAlchemy 2.0 + Supabase PostgreSQL
- **Frontend**: Next.js 14 (App Router) + shadcn/ui + Tailwind CSS
- **Type sharing**: openapi-ts로 FastAPI OpenAPI 스펙 → TS 타입 자동 생성
- **Auth**: Supabase Auth (JWT) + RBAC
- **Architecture**: Clean Architecture
- **Deploy**: Vercel (frontend) + Railway (backend)

---

## Architecture: Clean Architecture

의존성 방향: `Presentation → Application → Domain ← Infrastructure`

```
backend/app/
├── domain/
│   ├── entities/          # 순수 Python 도메인 모델 (프레임워크 의존 없음)
│   ├── repositories/      # 추상 인터페이스 (ABC)
│   └── exceptions.py      # 도메인 커스텀 예외
├── application/
│   └── use_cases/         # 비즈니스 로직, domain 조합
├── infrastructure/
│   ├── database/
│   │   ├── models/
│   │   │   ├── __init__.py  # Base + 모든 모델 import (Alembic용)
│   │   │   └── base.py      # declarative_base()
│   │   └── repositories/  # domain/repositories/ 구체 구현
│   └── external/          # Supabase, 외부 API
└── presentation/
    ├── routers/           # FastAPI 라우터 (얇게 — use_case 호출만)
    └── schemas/           # Pydantic request/response 스키마
```

### 레이어 규칙
- **domain**: 외부 의존 없음. SQLAlchemy, FastAPI import 금지
- **application/use_cases**: domain만 의존. 1 use case = 1 클래스 (`execute()` 메서드)
- **infrastructure**: domain 인터페이스 구현. ORM 모델은 여기서만
- **presentation**: use_case 호출 후 schema로 변환. 비즈니스 로직 작성 금지

### 예시 흐름
```
Router(schemas) → UseCase(entities) → Repository(ABC) ← RepositoryImpl(ORM)
```

---

## Project Structure

```
project/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── core/
│   │   │   ├── config.py        # Settings (pydantic-settings)
│   │   │   ├── database.py      # SQLAlchemy async engine & get_session
│   │   │   ├── auth.py          # JWT 검증, get_current_user
│   │   │   └── rbac.py          # Role 체크 dependencies
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── exceptions.py
│   │   ├── application/
│   │   │   └── use_cases/
│   │   ├── infrastructure/
│   │   │   ├── database/
│   │   │   │   ├── models/
│   │   │   │   └── repositories/
│   │   │   └── external/
│   │   └── presentation/
│   │       ├── routers/
│   │       └── schemas/
│   ├── tests/
│   │   ├── conftest.py
│   │   └── test_*.py
│   ├── alembic/
│   │   └── env.py               # async 설정 필수
│   ├── alembic.ini
│   ├── pyproject.toml           # pytest-asyncio 설정
│   ├── requirements.txt
│   └── .env.example
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   │   ├── (public)/        # 인증 불필요
│   │   │   ├── (dashboard)/     # 인증 필요
│   │   │   ├── layout.tsx       # Providers 포함
│   │   │   └── providers.tsx    # TanStack Query Provider
│   │   ├── components/
│   │   ├── lib/
│   │   │   ├── api.ts           # JWT 주입 + fetch 래퍼
│   │   │   └── utils.ts
│   │   ├── utils/supabase/
│   │   │   ├── client.ts        # 브라우저용 Supabase client
│   │   │   └── server.ts        # 서버 컴포넌트용 Supabase client
│   │   └── types/               # openapi-ts 자동 생성 — 수정 금지
│   ├── middleware.ts
│   ├── openapi-ts.config.ts
│   ├── package.json
│   └── .env.example
└── CLAUDE.md
```

---

## Backend Conventions

### `app/core/config.py`

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DATABASE_URL: str
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_JWT_SECRET: str
    FRONTEND_URL: str = "http://localhost:3000"

    model_config = {"env_file": ".env"}

settings = Settings()
```

### `app/core/database.py`

```python
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.core.config import settings

engine = create_async_engine(settings.DATABASE_URL, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session
```

### FastAPI (Presentation Layer)
- 라우터는 `presentation/routers/{resource}.py` — use_case 호출만
- 모든 엔드포인트에 `response_model` 명시
- HTTP 상태 코드: 생성=201, 없음=404, 검증오류=422
- 라우터에 비즈니스 로직 작성 금지

### Dependency Injection 패턴

```python
# presentation/routers/users.py
from typing import Annotated
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_session
from app.infrastructure.database.repositories.user_repository import UserRepositoryImpl
from app.application.use_cases.create_user import CreateUserUseCase

async def get_create_user_use_case(
    session: Annotated[AsyncSession, Depends(get_session)],
) -> CreateUserUseCase:
    return CreateUserUseCase(UserRepositoryImpl(session))

@router.post("/", status_code=201, response_model=UserResponse)
async def create_user(
    data: UserCreate,
    use_case: Annotated[CreateUserUseCase, Depends(get_create_user_use_case)],
):
    user = await use_case.execute(data)
    return UserResponse.model_validate(user.__dict__)
```

### Use Cases (Application Layer)

```python
# application/use_cases/create_user.py
class CreateUserUseCase:
    def __init__(self, user_repo: UserRepositoryABC):
        self.user_repo = user_repo

    async def execute(self, data: UserCreate) -> User:
        ...
```
- 1 use case = 1 파일, `execute()` 메서드
- domain entity 반환 (schema 아님)

### Domain Entities

```python
# domain/entities/user.py
from dataclasses import dataclass
from datetime import datetime

@dataclass
class User:
    id: str
    email: str
    role: str
    created_at: datetime
```
- 순수 Python dataclass. 프레임워크 import 없음

### Repository Pattern

```python
# domain/repositories/user_repository.py
from abc import ABC, abstractmethod

class UserRepositoryABC(ABC):
    @abstractmethod
    async def get_by_id(self, id: str) -> User | None: ...
    @abstractmethod
    async def create(self, user: User) -> User: ...
```

### ORM Model → Domain Entity 변환 패턴

infrastructure repository는 ORM 모델과 domain entity 사이를 `_to_entity()` 메서드로 변환. domain layer에 ORM 모델이 노출되지 않도록 반드시 변환.

```python
# infrastructure/database/repositories/user_repository.py
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.domain.entities.user import User
from app.domain.repositories.user_repository import UserRepositoryABC
from app.infrastructure.database.models.user import UserModel

class UserRepositoryImpl(UserRepositoryABC):
    def __init__(self, session: AsyncSession):
        self.session = session

    def _to_entity(self, model: UserModel) -> User:
        return User(
            id=str(model.id),
            email=model.email,
            role=model.role,
            created_at=model.created_at,
        )

    async def get_by_id(self, id: str) -> User | None:
        model = await self.session.get(UserModel, id)
        return self._to_entity(model) if model else None

    async def create(self, user: User) -> User:
        model = UserModel(id=user.id, email=user.email, role=user.role)
        self.session.add(model)
        await self.session.commit()
        await self.session.refresh(model)
        return self._to_entity(model)
```

### Error Handling 패턴

domain 예외를 정의하고 main.py에서 HTTP 응답으로 변환. 라우터에 try/except 작성 금지.

```python
# domain/exceptions.py
class DomainException(Exception): pass
class NotFoundError(DomainException): pass
class ConflictError(DomainException): pass
class ForbiddenError(DomainException): pass
```

```python
# app/main.py
from fastapi.responses import JSONResponse
from app.domain.exceptions import NotFoundError, ConflictError, ForbiddenError

@app.exception_handler(NotFoundError)
async def not_found_handler(request, exc):
    return JSONResponse(status_code=404, content={"detail": str(exc)})

@app.exception_handler(ConflictError)
async def conflict_handler(request, exc):
    return JSONResponse(status_code=409, content={"detail": str(exc)})

@app.exception_handler(ForbiddenError)
async def forbidden_handler(request, exc):
    return JSONResponse(status_code=403, content={"detail": str(exc)})
```

use case에서 사용:
```python
async def execute(self, id: str) -> User:
    user = await self.user_repo.get_by_id(id)
    if not user:
        raise NotFoundError(f"User {id} not found")
    return user
```

### SQLAlchemy 2.0 (Infrastructure Layer)
- `AsyncSession` 사용
- ORM 모델은 `infrastructure/database/models/`
- Concrete repository는 `infrastructure/database/repositories/`
- 마이그레이션: Alembic

### Pydantic Schemas (Presentation Layer)
- `{Resource}Create`, `{Resource}Update`, `{Resource}Response` 패턴
- `Response` 스키마는 항상 `id`, `created_at` 포함
- domain entity → response schema 변환은 라우터에서 (`model_validate`)

---

## Auth: Supabase Auth + FastAPI JWT

프론트에서 Supabase Auth로 로그인 → JWT 발급 → `Authorization: Bearer <token>` 헤더로 전송 → FastAPI에서 검증

```python
# app/core/auth.py
from jose import JWTError, jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer
from app.core.config import settings

security = HTTPBearer()

async def get_current_user(token = Depends(security)) -> dict:
    try:
        payload = jwt.decode(
            token.credentials,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

---

## RBAC (Role-Based Access Control)

역할은 Supabase Auth의 `app_metadata.role`에 저장.

**역할 정의:** `admin`, `manager`, `user` (기본값: `user`)

```python
# app/core/rbac.py
from fastapi import Depends, HTTPException
from app.core.auth import get_current_user

def require_role(*roles: str):
    async def dependency(user: dict = Depends(get_current_user)):
        user_role = user.get("app_metadata", {}).get("role", "user")
        if user_role not in roles:
            raise HTTPException(status_code=403, detail="Permission denied")
        return user
    return dependency

# 사용 예시
@router.delete("/{id}", dependencies=[Depends(require_role("admin"))])
async def delete_item(id: str): ...

@router.get("/")
async def list_items(user = Depends(require_role("admin", "manager"))): ...
```

**역할 부여:**
```python
# infrastructure/external/supabase_admin.py
supabase_admin.auth.admin.update_user_by_id(
    user_id, {"app_metadata": {"role": "admin"}}
)
```

---

## CORS 설정

```python
# app/main.py
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", settings.FRONTEND_URL],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

## Frontend Conventions

### Next.js App Router
- `app/(public)/` — 인증 불필요 페이지
- `app/(dashboard)/` — 인증 필요 페이지 (middleware로 보호)
- `app/api/` — Route handlers (백엔드 프록시 용도만)
- Server Component 기본, 인터랙션 있는 것만 `"use client"`

### Auth (Frontend) — `@supabase/ssr` 사용

```typescript
// src/utils/supabase/client.ts — 클라이언트 컴포넌트용
import { createBrowserClient } from '@supabase/ssr'
export const createClient = () =>
  createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  )

// src/utils/supabase/server.ts — 서버 컴포넌트용
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
// middleware.ts — 루트에 위치
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

### `src/lib/api.ts` — JWT 주입 패턴

모든 FastAPI 호출은 이 클라이언트를 통해 JWT를 자동 주입.

```typescript
// src/lib/api.ts
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

// 사용 예시
// const user = await apiClient<UserResponse>('/api/v1/users/me')
// const created = await apiClient<UserResponse>('/api/v1/users', {
//   method: 'POST',
//   body: JSON.stringify(data),
// })
```

### TanStack Query 설정

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
  return (
    <html><body><Providers>{children}</Providers></body></html>
  )
}
```

### API 호출 규칙
- `src/types/` — openapi-ts 자동 생성, 직접 수정 금지
- 모든 FastAPI 호출은 `apiClient()` 사용 (JWT 자동 주입)
- 클라이언트 컴포넌트: TanStack Query + `apiClient()`
- 서버 컴포넌트: `createClient()` (server.ts) 로 Supabase 세션 가져온 후 직접 fetch

### Components
- shadcn/ui 컴포넌트 우선 사용 (`npx shadcn-ui@latest add {component}`)
- 커스텀 컴포넌트는 `components/{feature}/` 하위에

---

## openapi-ts 설정

```typescript
// frontend/openapi-ts.config.ts
import { defineConfig } from '@hey-api/openapi-ts'

export default defineConfig({
  client: '@hey-api/client-fetch',
  input: 'http://localhost:8000/openapi.json',
  output: { path: 'src/types', format: 'prettier' },
})
```

```bash
# backend 실행 중일 때
cd frontend && npx @hey-api/openapi-ts
```

---

## 기본 패키지

**`backend/requirements.txt`:**
```
fastapi
uvicorn[standard]
sqlalchemy[asyncio]
asyncpg
alembic
pydantic-settings
python-jose[cryptography]
supabase
httpx
pytest
pytest-asyncio
```

**`frontend` 주요 의존성:**
```bash
npm install @supabase/ssr @supabase/supabase-js
npm install @tanstack/react-query
npm install @hey-api/openapi-ts @hey-api/client-fetch
npx shadcn-ui@latest init
```

---

## 개발 서버 실행

```bash
# Backend
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --port 8000
# → http://localhost:8000/docs

# Frontend
cd frontend && npm run dev
# → http://localhost:3000

# DB (로컬)
supabase start
# → PostgreSQL: localhost:54322
# → Studio: http://localhost:54323
```

---

## DB 환경

```bash
# 로컬 개발: Supabase CLI (Docker 필요)
brew install supabase/tap/supabase
supabase init && supabase start
supabase stop
```

**환경별 DB:**
- 로컬: `supabase start`
- 개발/운영: Supabase 프로젝트 별도 생성, `.env`의 URL만 교체

**`backend/.env`:**
```
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:54322/postgres
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=...
SUPABASE_JWT_SECRET=...
FRONTEND_URL=http://localhost:3000
```

**`frontend/.env.local`:**
```
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
NEXT_PUBLIC_API_URL=http://localhost:8000
```

---

## Alembic 마이그레이션

**`alembic.ini` 주의:** `sqlalchemy.url`은 비워두고 `env.py`에서 오버라이드.
```ini
# alembic.ini
sqlalchemy.url =
```

**`infrastructure/database/models/__init__.py` — 모든 모델 반드시 import:**

```python
# infrastructure/database/models/__init__.py
# Alembic autogenerate가 모델 변경을 감지하려면 여기서 모두 import해야 함
# 모델 추가 시 반드시 이 파일에도 추가
from app.infrastructure.database.models.base import Base
from app.infrastructure.database.models.user import UserModel
# from app.infrastructure.database.models.item import ItemModel  ← 추가 시
```

**`alembic/env.py` — async 설정 필수:**

```python
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from alembic import context
from app.core.config import settings
from app.infrastructure.database.models import Base  # __init__.py 통해 모든 모델 로드

config = context.config
target_metadata = Base.metadata

def run_migrations_online():
    connectable = create_async_engine(settings.DATABASE_URL)

    async def run():
        async with connectable.connect() as connection:
            await connection.run_sync(do_run_migrations)
        await connectable.dispose()

    asyncio.run(run())

def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()

run_migrations_online()
```

```bash
cd backend

# 마이그레이션 생성
alembic revision --autogenerate -m "add users table"

# 적용
alembic upgrade head

# 롤백
alembic downgrade -1

# 현재 상태
alembic current
```

---

## Python 환경

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

- 모든 Python 명령은 `backend/`에서 실행 (venv 활성화 상태)

---

## Testing

```bash
cd backend && pytest -v
cd backend && pytest tests/test_specific.py -v
```

### pytest-asyncio 설정 (필수)

`backend/pyproject.toml`:
```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
```
이 설정 없으면 async 테스트/fixture 전부 실패.

### conftest.py 기본 구조

```python
# tests/conftest.py
import pytest
from unittest.mock import AsyncMock
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.auth import get_current_user

# use case 단위 테스트 — mock repository 주입 (DB 불필요)
@pytest.fixture
def mock_user_repo():
    from app.domain.repositories.user_repository import UserRepositoryABC
    return AsyncMock(spec=UserRepositoryABC)

@pytest.fixture
def create_user_use_case(mock_user_repo):
    from app.application.use_cases.create_user import CreateUserUseCase
    return CreateUserUseCase(mock_user_repo)

# API 통합 테스트
@pytest.fixture
async def client():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c

# 인증 override — 통합 테스트에서 JWT 검증 우회
# get_current_user가 실제 JWT를 검증하므로 반드시 override해야 401을 피할 수 있음
@pytest.fixture
def mock_current_user():
    return {"sub": "test-user-id", "email": "test@example.com", "app_metadata": {"role": "user"}}

@pytest.fixture
def auth_client(client, mock_current_user):
    async def override_get_current_user():
        return mock_current_user
    app.dependency_overrides[get_current_user] = override_get_current_user
    yield client
    app.dependency_overrides.clear()

@pytest.fixture
def admin_client(client):
    async def override_get_admin_user():
        return {"sub": "admin-user-id", "email": "admin@example.com", "app_metadata": {"role": "admin"}}
    app.dependency_overrides[get_current_user] = override_get_admin_user
    yield client
    app.dependency_overrides.clear()
```

인증 필요한 엔드포인트는 `client` 대신 `auth_client` 또는 `admin_client` fixture 사용:
```python
async def test_get_item(auth_client):
    response = await auth_client.get("/api/v1/items/1")
    assert response.status_code == 200
```

### 테스트 규칙
- Use case 테스트: mock repository 주입 → DB 없이 비즈니스 로직만 검증
- API 통합 테스트: `AsyncClient` + `ASGITransport`
- 각 테스트는 독립적 (setup/teardown 철저히)
- 테스트 파일명: `test_{resource}.py`
- 테스트 함수명: `test_{method}_{scenario}`

### TDD 원칙
1. 실패하는 테스트 먼저 작성
2. 테스트 통과하는 최소 구현
3. 리팩터

---

## TDD Loop 규칙

- 구현 전 반드시 테스트 먼저 작성
- 구현 후 `pytest` 실행
- 실패 시: 에러 분석 → 수정 → 재실행 (최대 5회)
- 5회 초과 실패 시: 사용자에게 상황 보고 후 대기
- 전체 통과 시: 완료 보고

---

## Code Style
- Python: black 포맷, 타입 힌트 필수
- TypeScript: strict mode, `any` 사용 금지
- 주석: 로직이 자명하지 않을 때만
- 함수/변수명: 의미 있는 이름, 축약 금지
