#!/bin/bash
# Claude Config 전역 설치 스크립트
# 사용법: ./install.sh
# - skills/ 하위 각 디렉토리를 ~/.claude/skills/ 에 심링크
# - 업데이트: git pull 후 자동 반영 (심링크이므로)

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

echo "Claude Config 설치 중..."
echo "저장소 위치: $REPO_DIR"

# skills 디렉토리 생성
mkdir -p "$SKILLS_DIR"

# skills 하위 디렉토리 심링크 설치
for skill_dir in "$REPO_DIR/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DIR/$skill_name"

  if [ -L "$target" ]; then
    echo "  갱신: $skill_name"
    ln -sf "$skill_dir" "$target"
  elif [ -d "$target" ]; then
    echo "  건너뜀 (기존 디렉토리 존재): $skill_name — 수동으로 처리해 주세요"
  else
    echo "  설치: $skill_name"
    ln -s "$skill_dir" "$target"
  fi
done

echo ""
echo "완료! 설치된 스킬:"
for skill_dir in "$REPO_DIR/skills"/*/; do
  echo "  /$(basename "$skill_dir")"
done

echo ""
echo "프로젝트에 CLAUDE.md 추가하려면:"
echo "  $REPO_DIR/init-project.sh"
