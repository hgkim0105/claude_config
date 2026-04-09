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
│   └── repositories/      # 추상 인터페이스 (ABC)
├── application/
│   └── use_cases/         # 비즈니스 로직, domain 조합
├── infrastructure/
│   ├── database/
│   │   ├── models/        # SQLAlchemy ORM 모델
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
│   │   │   ├── database.py      # SQLAlchemy async engine & session
│   │   │   ├── auth.py          # JWT 검증, get_current_user
│   │   │   └── rbac.py          # Role 체크 dependencies
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   └── repositories/
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
│   ├── alembic.ini
│   ├── requirements.txt
│   └── .env.example
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   │   ├── (public)/        # 인증 불필요
│   │   │   └── (dashboard)/     # 인증 필요
│   │   ├── components/
│   │   ├── lib/
│   │   │   ├── api.ts
│   │   │   └── utils.ts
│   │   └── types/               # openapi-ts 자동 생성 — 수정 금지
│   ├── openapi-ts.config.ts
│   ├── package.json
│   └── .env.example
└── CLAUDE.md
```

---

## Backend Conventions

### FastAPI (Presentation Layer)
- 라우터는 `presentation/routers/{resource}.py` — use_case 호출만
- 모든 엔드포인트에 `response_model` 명시
- HTTP 상태 코드: 생성=201, 없음=404, 검증오류=422
- 라우터에 비즈니스 로직 작성 금지

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

### SQLAlchemy 2.0 (Infrastructure Layer)
- `AsyncSession` 사용
- ORM 모델은 `infrastructure/database/models/`
- Concrete repository는 `infrastructure/database/repositories/`
- 마이그레이션: Alembic

### Pydantic Schemas (Presentation Layer)
- `{Resource}Create`, `{Resource}Update`, `{Resource}Response` 패턴
- `Response` 스키마는 항상 `id`, `created_at` 포함
- domain entity → response schema 변환은 라우터에서

---

## Auth: Supabase Auth + FastAPI JWT

프론트에서 Supabase Auth로 로그인 → JWT 발급 → `Authorization: Bearer <token>` 헤더로 전송 → FastAPI에서 검증

```python
# app/core/auth.py
from jose import JWTError, jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer

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

**`backend/.env`에 추가:**
```
SUPABASE_JWT_SECRET=your-supabase-jwt-secret  # Supabase 프로젝트 설정에서 확인
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

**역할 부여 (Supabase Dashboard 또는 Admin API):**
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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", settings.FRONTEND_URL],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**`backend/.env`에 추가:**
```
FRONTEND_URL=https://your-app.vercel.app
```

---

## Frontend Conventions

### Next.js App Router
- `app/(public)/` — 인증 불필요 페이지
- `app/(dashboard)/` — 인증 필요 페이지 (middleware로 보호)
- `app/api/` — Route handlers (백엔드 프록시 용도만)
- Server Component 기본, 인터랙션 있는 것만 `"use client"`

### Auth (Frontend)
```typescript
// middleware.ts — 루트에 위치
import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs'

export async function middleware(req) {
  const supabase = createMiddlewareClient({ req, res })
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return NextResponse.redirect('/login')
}

export const config = { matcher: ['/dashboard/:path*'] }
```

### API 호출
- `src/types/` — openapi-ts 자동 생성, 직접 수정 금지
- API 호출은 `src/lib/api.ts`에서 중앙 관리
- 서버 컴포넌트: 직접 fetch + `Authorization` 헤더 주입
- 클라이언트 컴포넌트: TanStack Query

### Components
- shadcn/ui 컴포넌트 우선 사용
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

**`frontend/package.json` 주요 의존성:**
```
next, react, react-dom
@supabase/supabase-js
@supabase/auth-helpers-nextjs
@tanstack/react-query
@hey-api/openapi-ts
tailwindcss
shadcn/ui (npx shadcn-ui@latest init)
```

---

## 개발 서버 실행

```bash
# Backend
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --port 8000
# → http://localhost:8000
# → API 문서: http://localhost:8000/docs

# Frontend
cd frontend
npm run dev
# → http://localhost:3000

# DB (로컬)
supabase start
# → PostgreSQL: localhost:54322
# → Studio: http://localhost:54323
```

---

## DB 환경

Supabase PostgreSQL 사용.

```bash
# 로컬 개발: Supabase CLI (Docker 필요)
brew install supabase/tap/supabase
supabase init && supabase start

# 종료
supabase stop
```

**환경별 DB:**
- 로컬: `supabase start` (localhost)
- 개발: Supabase 프로젝트 `{project}-dev`
- 운영: Supabase 프로젝트 `{project}-prod`

**`backend/.env`:**
```
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:54322/postgres
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=...
SUPABASE_JWT_SECRET=...
FRONTEND_URL=http://localhost:3000
```

---

## Alembic 마이그레이션

```bash
cd backend

# 초기 설정 (최초 1회)
alembic init alembic

# 마이그레이션 생성
alembic revision --autogenerate -m "add users table"

# 적용
alembic upgrade head

# 롤백
alembic downgrade -1

# 현재 상태 확인
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

- 테스트는 `tests/conftest.py`의 fixture 사용
- DB는 테스트용 SQLite in-memory 또는 Supabase 테스트 프로젝트
- 각 테스트는 독립적 (setup/teardown 철저히)
- Use case 테스트: repository를 mock으로 주입 (Clean Architecture 덕분에 가능)
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
