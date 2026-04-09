# Project Rules

## Stack
- **Backend**: FastAPI + SQLAlchemy 2.0 + Supabase PostgreSQL
- **Frontend**: Next.js 14 (App Router) + shadcn/ui + Tailwind CSS
- **Type sharing**: openapi-ts로 FastAPI OpenAPI 스펙 → TS 타입 자동 생성
- **Auth**: Supabase Auth
- **Deploy**: Vercel (frontend) + Railway (backend)

## Project Structure

```
project/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── core/
│   │   │   ├── config.py        # Settings (pydantic-settings)
│   │   │   └── database.py      # SQLAlchemy engine & session
│   │   ├── models/              # SQLAlchemy ORM models
│   │   ├── schemas/             # Pydantic request/response schemas
│   │   ├── routers/             # FastAPI routers (1 file = 1 resource)
│   │   └── services/            # Business logic (routers → services)
│   ├── tests/
│   │   ├── conftest.py          # pytest fixtures
│   │   └── test_*.py
│   ├── requirements.txt
│   └── .env.example
├── frontend/
│   ├── src/
│   │   ├── app/                 # Next.js App Router pages
│   │   ├── components/          # shadcn/ui + custom components
│   │   ├── lib/
│   │   │   ├── api.ts           # API client (generated + custom)
│   │   │   └── utils.ts
│   │   └── types/               # openapi-ts generated types (DO NOT EDIT)
│   ├── package.json
│   └── .env.example
└── CLAUDE.md
```

## Backend Conventions

### FastAPI
- 라우터는 `app/routers/{resource}.py` 1파일 1리소스
- 비즈니스 로직은 반드시 `app/services/`로 분리 (라우터에 직접 쓰지 않음)
- 모든 엔드포인트에 response_model 명시
- HTTP 상태 코드: 생성=201, 없음=404, 검증오류=422

### SQLAlchemy 2.0
- `async` 세션 사용 (`AsyncSession`)
- 모델은 `app/models/{resource}.py`
- 마이그레이션: Alembic 사용

### Pydantic Schemas
- `{Resource}Create`, `{Resource}Update`, `{Resource}Response` 패턴
- `Response` 스키마는 항상 `id`, `created_at` 포함

### 환경변수
- `pydantic-settings`로 관리, `app/core/config.py`에서 `Settings` 클래스
- `.env` 파일, `.env.example`에 키 목록 유지

## Frontend Conventions

### Next.js App Router
- `app/(auth)/` — 인증 필요 없는 페이지
- `app/(dashboard)/` — 인증 필요 페이지
- `app/api/` — Route handlers (백엔드 프록시 용도만)
- Server Component 기본, 인터랙션 있는 것만 `"use client"`

### Components
- shadcn/ui 컴포넌트 우선 사용
- 커스텀 컴포넌트는 `components/{feature}/` 하위에
- 페이지 레벨 컴포넌트는 `app/` 안에서만

### API 호출
- `src/types/` 는 openapi-ts 자동 생성 — 직접 수정 금지
- API 호출은 `src/lib/api.ts` 에서 중앙 관리
- 서버 컴포넌트에서는 직접 fetch, 클라이언트에서는 TanStack Query

### 타입 생성 명령
```bash
# backend 실행 후
cd frontend && npx openapi-ts
```

## DB 환경

Supabase PostgreSQL 사용.

```bash
# 로컬 개발: Supabase CLI (Docker 필요)
brew install supabase/tap/supabase
supabase init && supabase start
# → 로컬 PostgreSQL: postgresql://postgres:postgres@localhost:54322/postgres
# → Supabase Studio: http://localhost:54323

# 종료
supabase stop
```

**환경별 DB:**
- 로컬: `supabase start` (localhost)
- 개발: Supabase 프로젝트 `{project}-dev`
- 운영: Supabase 프로젝트 `{project}-prod`

**`backend/.env` 설정:**
```
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:54322/postgres
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=...
```

- `.env`의 `DATABASE_URL`만 바꿔서 환경 전환
- `.env.example`에 키 목록 유지 (값은 제외)

## Python 환경

```bash
# 가상환경 위치: backend/.venv
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

- 모든 Python 명령은 `backend/` 에서 실행 (venv 활성화 상태)
- `pytest`, `uvicorn` 등 전부 `backend/.venv` 기준

## Testing

### Backend (pytest)
```bash
cd backend && pytest -v
cd backend && pytest tests/test_specific.py -v
```
- 테스트는 반드시 `tests/conftest.py`의 fixture 사용
- DB는 테스트용 인메모리 SQLite 또는 Supabase 테스트 프로젝트
- 각 테스트는 독립적 (setup/teardown 철저히)
- 테스트 파일명: `test_{resource}.py`
- 테스트 함수명: `test_{method}_{scenario}` (예: `test_create_user_success`)

### 테스트 작성 원칙 (TDD)
1. 실패하는 테스트 먼저 작성
2. 테스트 통과하는 최소 구현
3. 리팩터

## TDD Loop 규칙

구현 전 반드시 테스트를 먼저 작성한다.
- 테스트가 실패하는 것을 확인 후 구현 시작
- 구현 후 `pytest` 실행
- 실패 시: 에러 분석 → 수정 → 재실행 (최대 5회)
- 5회 초과 실패 시: 사용자에게 상황 보고 후 대기
- 전체 통과 시: 완료 보고

## Code Style
- Python: black 포맷, 타입 힌트 필수
- TypeScript: strict mode, any 사용 금지
- 주석: 로직이 자명하지 않을 때만
- 함수/변수명: 의미 있는 이름, 축약 금지
