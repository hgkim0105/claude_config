# claude_config 프로젝트 규칙

이 레포는 Claude Code 바이브 코딩을 위한 스킬과 템플릿을 관리하는 설정 저장소입니다.

## 이 레포에서 하는 작업

- `skills/` — Claude Code 슬래시 커맨드 스킬 작성/개선
- `templates/` — 프로젝트별 CLAUDE.md 템플릿 작성/개선
- `install.sh`, `init-project.sh` — 설치 스크립트 유지보수

## 파일 구조 규칙

### 스킬 추가
```
skills/{스킬명}/SKILL.md
```
- 반드시 프론트매터 포함: `name`, `description`
- `description`에 트리거 키워드 포함 (스킬 목록 노출용)
- `install.sh` 재실행 없이 심링크라 자동 반영

### 템플릿 추가
```
templates/{스택명}/CLAUDE.md
```
- 해당 스택에서 Claude가 올바른 코드를 생성하기 위한 모든 정보 포함
- 컨벤션, 패턴 예시 코드, 실행 명령, 환경변수 형식까지 명시
- 스킬(`/plan`, `/tdd-loop`)은 CLAUDE.md를 읽고 동작하므로 상세할수록 좋음

## 작업 원칙

- 스킬/템플릿은 실제 프로젝트에서 써보고 부족한 부분을 발견하면 바로 개선
- 템플릿은 "Claude가 이 파일만 보고 올바른 코드를 생성할 수 있는가"를 기준으로 작성
- 스킬은 사용자 개입 최소화를 목표로 설계
