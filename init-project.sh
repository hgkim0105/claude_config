#!/bin/bash
# 프로젝트에 CLAUDE.md 초기화 스크립트
# 사용법: /path/to/claude_config/init-project.sh [템플릿명]
# 예시:
#   ~/.claude_config/init-project.sh           # 기본 fullstack 템플릿
#   ~/.claude_config/init-project.sh fullstack # 명시적 지정

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${1:-fullstack}"
TEMPLATE_FILE="$REPO_DIR/templates/${TEMPLATE}/CLAUDE.md"

# 단일 CLAUDE.md도 지원
if [ ! -f "$TEMPLATE_FILE" ]; then
  TEMPLATE_FILE="$REPO_DIR/templates/CLAUDE.md"
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "오류: 템플릿을 찾을 수 없습니다: $TEMPLATE"
  echo "사용 가능한 템플릿:"
  ls "$REPO_DIR/templates/"
  exit 1
fi

TARGET="$(pwd)/CLAUDE.md"

if [ -f "$TARGET" ]; then
  echo "CLAUDE.md 가 이미 존재합니다."
  read -p "덮어쓰시겠습니까? (y/N) " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "취소됨."
    exit 0
  fi
fi

cp "$TEMPLATE_FILE" "$TARGET"
echo "CLAUDE.md 생성 완료: $TARGET"
echo "템플릿: $TEMPLATE_FILE"
