---
name: plan
description: 기능 요청을 받아 API/DB/파일/테스트 케이스가 포함된 구현 계획서를 생성하고 사용자 컨펌을 기다립니다. FastAPI + Next.js 풀스택 프로젝트에 최적화. Keywords: plan, 계획, 기능, feature, implement, 구현
---

# /plan — Feature Planning Skill

When the user invokes `/plan [기능 설명]`, act as a senior software architect.

## Your job

1. 현재 코드베이스를 파악 (CLAUDE.md, 기존 파일 구조, 기존 라우터/모델 확인)
2. 아래 형식의 구조화된 계획서 생성
3. 계획서 출력 후 사용자 컨펌 대기 — **컨펌 전까지 절대 구현하지 않는다**

## Plan Output Format

```
## 기능: [기능명]

**요약:** [1-2줄 설명]

### API 엔드포인트
| Method | Path | 설명 |
|--------|------|------|
| POST   | /api/v1/... | ... |

**Request 스키마:**
\`\`\`python
class XxxCreate(BaseModel):
    field: type
\`\`\`

**Response 스키마:**
\`\`\`python
class XxxResponse(BaseModel):
    id: int
    field: type
    created_at: datetime
\`\`\`

### DB 변경사항
- 새 테이블: `table_name` (필드 목록)
- 기존 테이블 변경: 없음

### 생성할 파일
- `backend/app/models/xxx.py` — ORM 모델
- `backend/app/schemas/xxx.py` — Pydantic 스키마
- `backend/app/routers/xxx.py` — 라우터
- `backend/app/services/xxx.py` — 비즈니스 로직
- `backend/tests/test_xxx.py` — 테스트

### 수정할 파일
- `backend/app/main.py` — 라우터 등록

### 테스트 케이스
- [ ] `test_create_xxx_success` — 정상 생성
- [ ] `test_create_xxx_validation_error` — 필수 필드 누락
- [ ] `test_get_xxx_success` — 정상 조회
- [ ] `test_get_xxx_not_found` — 존재하지 않는 ID 조회
- [ ] `test_list_xxx` — 목록 조회

### 리스크 / 고려사항
- [있으면 기술]

---
이 계획으로 진행할까요? 수정이 필요하면 말씀해 주세요.
```

## Rules
- 기존 패턴과 일관성 유지 (코드베이스 먼저 읽기)
- 테스트 케이스는 happy path + edge case 반드시 포함
- 프론트엔드 변경이 필요하면 별도 섹션으로 추가
- 불확실한 것은 추측하지 말고 계획서에 질문으로 명시
