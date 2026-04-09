# claude_config

Claude Code 바이브 코딩을 위한 스킬, 템플릿 모음.

## 구조

```
claude_config/
├── skills/
│   ├── plan/SKILL.md       # /plan  — 기능 계획서 생성
│   └── tdd-loop/SKILL.md   # /tdd-loop — TDD 자율 실행 루프
├── templates/
│   ├── fullstack/          # FastAPI + Next.js + Supabase
│   ├── fastapi-only/       # FastAPI 백엔드만
│   ├── nextjs-only/        # Next.js 프론트만
│   └── base/               # 스택 무관 (Clean Architecture + TDD)
├── install.sh              # 스킬 전역 설치
└── init-project.sh         # 프로젝트에 CLAUDE.md 복사
```

## 설치 (머신당 1회)

```bash
git clone https://github.com/hgkim0105/claude_config ~/.claude_config
cd ~/.claude_config && ./install.sh
```

스킬이 `~/.claude/skills/`에 심링크로 설치됩니다.  
이후 `git pull`만 하면 업데이트 자동 반영.

## 새 프로젝트 시작

```bash
mkdir my-project && cd my-project

# 템플릿 선택 (기본값: fullstack)
~/.claude_config/init-project.sh
~/.claude_config/init-project.sh fastapi-only
~/.claude_config/init-project.sh nextjs-only
~/.claude_config/init-project.sh base

claude  # Claude Code 실행
```

## 개발 워크플로우

```
/plan 유저 로그인 기능 만들어줘
    ↕ 대화로 계획 다듬기
   "응, 진행해"
/tdd-loop
    → 테스트 작성 → 구현 → pytest → 완료 보고
```

1. `/plan [기능 설명]` — 코드베이스 파악 후 API/DB/테스트 계획서 생성, 컨펌 대기
2. `/tdd-loop` — 컨펌된 계획 기반으로 테스트→구현→통과까지 자율 실행

## 새 스택 추가

`templates/{스택명}/CLAUDE.md` 파일 하나 추가하면 됩니다.

```bash
mkdir templates/spring-boot
# templates/spring-boot/CLAUDE.md 작성
git push
```

## 업데이트

```bash
cd ~/.claude_config && git pull
```
