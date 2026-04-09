# /tdd-loop — Autonomous TDD Execution Skill

When the user invokes `/tdd-loop [기능명 또는 계획]`, execute the full TDD cycle autonomously.

## Precondition
- `/plan`으로 생성된 계획서가 컨펌된 상태여야 함
- CLAUDE.md가 프로젝트 루트에 존재해야 함

## Execution Loop

### Phase 1: 테스트 작성
1. `backend/tests/test_{resource}.py` 생성
2. conftest.py fixture 확인 및 필요시 추가
3. `pytest tests/test_{resource}.py -v` 실행
4. **모든 테스트가 실패하는지 확인** (통과하면 테스트가 잘못된 것)
5. TodoWrite로 테스트 케이스 목록 기록

### Phase 2: 구현
순서 중요:
1. `app/models/{resource}.py` — ORM 모델
2. `app/schemas/{resource}.py` — Pydantic 스키마
3. `app/services/{resource}.py` — 비즈니스 로직
4. `app/routers/{resource}.py` — 라우터
5. `app/main.py` — 라우터 등록

### Phase 3: 테스트 실행 루프
```
pytest 실행
  ├─ 전체 통과 → Phase 4로
  └─ 실패 →
       에러 분석 (traceback 읽기)
       원인 파악 (타입 오류? 로직 오류? fixture 문제?)
       최소 수정 적용
       재실행
       (최대 5회 반복)
```

### Phase 4: 전체 테스트 검증
```bash
pytest -v  # 프로젝트 전체 테스트
```
- 기존 테스트가 깨지지 않았는지 확인
- 새 테스트 전부 통과 확인

### Phase 5: 완료 보고
```
## 완료: [기능명]

**통과한 테스트:** X개
**생성한 파일:**
- ...
**수정한 파일:**
- ...

프론트엔드 타입 업데이트가 필요합니다:
  cd frontend && npx openapi-ts
```

## Escalation Rules (사용자에게 보고 후 대기)
다음 상황에서는 **즉시 멈추고 사용자에게 상황을 설명**:
- 루프 5회 초과 후에도 동일 에러 반복
- 기존 테스트가 깨짐 (자신의 변경으로 인한)
- DB 스키마 변경이 마이그레이션 필요 (Alembic)
- 환경변수나 외부 서비스 설정 필요
- 계획에 없던 설계 결정이 필요한 시점

## Rules
- 한 번에 하나의 파일만 수정 후 테스트
- 테스트를 통과시키기 위해 테스트 코드를 수정하지 않는다
- 실패 원인을 traceback에서 반드시 읽은 후 수정
- TodoWrite로 진행 상황 실시간 업데이트
- 구현 완료 전까지 리팩터링하지 않는다
