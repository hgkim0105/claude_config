# Project Rules

## Stack
- **Backend**: FastAPI + SQLAlchemy 2.0 + PostgreSQL (Supabase)
- **Auth**: Supabase Auth (JWT) + RBAC
- **Architecture**: Clean Architecture

---

## Architecture: Clean Architecture

의존성 방향: `Presentation → Application → Domain ← Infrastructure`

```
app/
├── domain/
│   ├── entities/          # 순수 Python 도메인 모델 (프레임워크 의존 없음)
│   ├── repositories/      # 추상 인터페이스 (ABC)
│   └── exceptions.py      # 도메인 커스텀 예외
├── application/
│   └── use_cases/         # 비즈니스 로직 (1 use case = 1 파일)
├── infrastructure/
│   ├── database/
│   │   ├── models/
│   │   │   ├── __init__.py  # Base + 모든 모델 import (Alembic용)
│   │   │   └── base.py
│   │   └── repositories/
│   └── external/
├── presentation/
│   ├── routers/
│   └── schemas/
└── core/
    ├── config.py
    ├── database.py
    ├── auth.py
    └── rbac.py
```

### 레이어 규칙
- **domain**: SQLAlchemy, FastAPI import 금지
- **application/use_cases**: domain만 의존. `execute()` 메서드
- **infrastructure**: domain 인터페이스 구현. ORM은 여기서만
- **presentation**: use_case 호출 후 schema 변환. 비즈니스 로직 금지

---

## Core 패턴

### `app/core/config.py`
```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DATABASE_URL: str
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_JWT_SECRET: str

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

---

## Backend Conventions

### FastAPI
- 라우터는 `presentation/routers/{resource}.py` — use_case 호출만
- 모든 엔드포인트에 `response_model` 명시
- HTTP 상태 코드: 생성=201, 없음=404, 검증오류=422

### Dependency Injection 패턴
```python
from typing import Annotated
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_session

async def get_use_case(
    session: Annotated[AsyncSession, Depends(get_session)],
):
    return MyUseCase(MyRepositoryImpl(session))

@router.post("/", status_code=201, response_model=MyResponse)
async def create(
    data: MyCreate,
    use_case: Annotated[MyUseCase, Depends(get_use_case)],
):
    entity = await use_case.execute(data)
    return MyResponse.model_validate(entity.__dict__)
```

### ORM → Domain Entity 변환
```python
class MyRepositoryImpl(MyRepositoryABC):
    def _to_entity(self, model: MyModel) -> MyEntity:
        return MyEntity(id=str(model.id), ...)

    async def get_by_id(self, id: str) -> MyEntity | None:
        model = await self.session.get(MyModel, id)
        return self._to_entity(model) if model else None
```

### Error Handling
```python
# domain/exceptions.py
class DomainException(Exception): pass
class NotFoundError(DomainException): pass
class ConflictError(DomainException): pass
class ForbiddenError(DomainException): pass

# app/main.py — exception_handler 등록, 라우터 try/except 금지
@app.exception_handler(NotFoundError)
async def not_found_handler(request, exc):
    return JSONResponse(status_code=404, content={"detail": str(exc)})
```

### Pydantic Schemas
- `{Resource}Create`, `{Resource}Update`, `{Resource}Response` 패턴
- `Response`는 항상 `id`, `created_at` 포함

---

## Auth: Supabase JWT

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

## RBAC

```python
# app/core/rbac.py
def require_role(*roles: str):
    async def dependency(user: dict = Depends(get_current_user)):
        user_role = user.get("app_metadata", {}).get("role", "user")
        if user_role not in roles:
            raise HTTPException(status_code=403, detail="Permission denied")
        return user
    return dependency
```

역할: `admin`, `manager`, `user` (기본값: `user`, Supabase `app_metadata.role`에 저장)

## CORS

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", settings.FRONTEND_URL],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

## 환경변수 (`.env`)
```
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:54322/postgres
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=...
SUPABASE_JWT_SECRET=...
FRONTEND_URL=http://localhost:3000
```

---

## Python 환경
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 기본 패키지 (`requirements.txt`)
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

## 개발 서버
```bash
source .venv/bin/activate
uvicorn app.main:app --reload --port 8000
# → http://localhost:8000/docs
```

---

## Alembic 마이그레이션

`alembic.ini`: `sqlalchemy.url =` (비워두기)

`alembic/env.py` — async 필수:
```python
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from app.core.config import settings
from app.infrastructure.database.models import Base  # 모든 모델 로드

def run_migrations_online():
    connectable = create_async_engine(settings.DATABASE_URL)
    async def run():
        async with connectable.connect() as connection:
            await connection.run_sync(do_run_migrations)
        await connectable.dispose()
    asyncio.run(run())

def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=Base.metadata)
    with context.begin_transaction():
        context.run_migrations()

run_migrations_online()
```

`infrastructure/database/models/__init__.py` — 모델 추가 시 반드시 여기도 추가:
```python
from app.infrastructure.database.models.base import Base
from app.infrastructure.database.models.user import UserModel
```

```bash
alembic revision --autogenerate -m "description"
alembic upgrade head
alembic downgrade -1
```

---

## Testing

`pyproject.toml`:
```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
```

```python
# tests/conftest.py
import pytest
from unittest.mock import AsyncMock
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.auth import get_current_user

@pytest.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c

@pytest.fixture
def auth_client(client):
    async def override():
        return {"sub": "test-id", "app_metadata": {"role": "user"}}
    app.dependency_overrides[get_current_user] = override
    yield client
    app.dependency_overrides.clear()

@pytest.fixture
def admin_client(client):
    async def override():
        return {"sub": "admin-id", "app_metadata": {"role": "admin"}}
    app.dependency_overrides[get_current_user] = override
    yield client
    app.dependency_overrides.clear()
```

```bash
pytest -v
pytest tests/test_specific.py -v
```

---

## TDD Loop 규칙
- 구현 전 반드시 테스트 먼저 작성
- 실패 시: 에러 분석 → 수정 → 재실행 (최대 5회)
- 5회 초과 실패 시: 사용자에게 보고 후 대기

## Code Style
- Python: black 포맷, 타입 힌트 필수
- 주석: 로직이 자명하지 않을 때만
