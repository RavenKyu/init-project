#!/bin/bash
# init-project 스타터를 서브모듈로 사용하는 프로젝트의 초기 세팅 스크립트 (멱등 — 재실행 안전).
# 소비 프로젝트 루트에서 실행:
#   git submodule add <repo-url> init-project
#   bash init-project/scripts/bootstrap.sh [submodule-dir]
set -euo pipefail

SUB="${1:-init-project}"
if [ ! -f "$SUB/AGENTS.md" ]; then
  echo "오류: '$SUB/'에서 스타터를 찾을 수 없습니다. 먼저 서브모듈을 추가하세요:" >&2
  echo "  git submodule add <repo-url> $SUB" >&2
  exit 1
fi

created() { echo "  + $1"; }
skipped() { echo "  = $1 (이미 존재, 건너뜀)"; }

echo "[1/6] 루트 가이드 (CLAUDE.md / AGENTS.md 포인터)"
if [ -f CLAUDE.md ]; then skipped "CLAUDE.md"; else
cat > CLAUDE.md <<EOF
# CLAUDE.md

> 공통 가이드 원본은 서브모듈 \`$SUB/AGENTS.md\`입니다. 공통 규칙 수정은 스타터 저장소에서 하세요 (여기에 복사 금지 — 드리프트의 원인).

@$SUB/AGENTS.md

## 이 프로젝트 전용

- (Claude Code 전용 규칙이 생기면 여기에 추가)
EOF
created "CLAUDE.md"; fi

if [ -f AGENTS.md ]; then skipped "AGENTS.md"; else
cat > AGENTS.md <<EOF
# AGENTS.md

이 프로젝트의 AI 에이전트 공통 가이드는 [\`$SUB/AGENTS.md\`]($SUB/AGENTS.md)를 따릅니다. 작업 시작 전 반드시 읽으세요.
프로젝트 고유 규칙이 필요하면 이 파일에 추가하되, 공통 규칙과의 중복은 금지합니다.
EOF
created "AGENTS.md"; fi

echo "[2/6] docs/ 뼈대"
mkdir -p docs/adr
for f in ARCHITECTURE.md CONVENTIONS.md; do
  if [ -f "docs/$f" ]; then skipped "docs/$f"; else cp "$SUB/docs/$f" "docs/$f"; created "docs/$f"; fi
done

echo "[3/6] specs/ (템플릿은 서브모듈 심링크 — 중앙 업데이트 반영)"
mkdir -p specs/_archive
if [ -e specs/_templates ] || [ -L specs/_templates ]; then skipped "specs/_templates"; else
  ln -s "../$SUB/skills/feature/templates" specs/_templates
  created "specs/_templates -> ../$SUB/skills/feature/templates"; fi

echo "[4/6] .claude/settings.json (훅을 서브모듈 경로로 와이어링)"
mkdir -p .claude
if [ -f .claude/settings.json ]; then
  # 따옴표 없이 시작하는 ${CLAUDE_PROJECT_DIR} 는 공백 경로(예: C:\Users\WINDOWS USER)에서 쪼개진다 — 기존 파일도 치유
  sed -E 's#("command"[[:space:]]*:[[:space:]]*")\$\{?CLAUDE_PROJECT_DIR\}?/#\1\\"${CLAUDE_PROJECT_DIR}\\"/#' \
    .claude/settings.json > .claude/settings.json.tmp
  if cmp -s .claude/settings.json .claude/settings.json.tmp; then
    rm .claude/settings.json.tmp
  else
    mv .claude/settings.json.tmp .claude/settings.json
    echo "  ~ .claude/settings.json: 훅 명령의 \${CLAUDE_PROJECT_DIR}를 따옴표로 감쌈 (공백 경로 대응)"
  fi
  skipped ".claude/settings.json — 훅 병합이 필요하면 $SUB/.claude/settings.json의 경로에 '$SUB/'를 붙여 수동 반영"
else
  sed "s#}\\\\\"/.claude/hooks/#}\\\\\"/$SUB/hooks/#g" \
    "$SUB/.claude/settings.json" > .claude/settings.json
  created ".claude/settings.json"
fi

echo "[5/6] 스킬 심링크 (/feature, /handoff, /learn)"
mkdir -p .claude/skills
for d in "$SUB"/skills/*/; do
  name=$(basename "$d")
  if [ -e ".claude/skills/$name" ] || [ -L ".claude/skills/$name" ]; then skipped ".claude/skills/$name"; else
    ln -s "../../$SUB/skills/$name" ".claude/skills/$name"
    created ".claude/skills/$name -> ../../$SUB/skills/$name"; fi
done

echo "[6/6] MCP 등록 · .gitignore"
if [ -f .mcp.json ]; then skipped ".mcp.json — claude-memory-layer 항목이 있는지 확인하세요"; else
  cp "$SUB/.mcp.json" .mcp.json; created ".mcp.json"; fi
touch .gitignore
for line in "memory/" ".DS_Store"; do
  if grep -qxF "$line" .gitignore; then skipped ".gitignore: $line"; else
    echo "$line" >> .gitignore; created ".gitignore += $line"; fi
done

echo ""
echo "부트스트랩 완료. 다음 단계:"
echo "  1) docs/ARCHITECTURE.md의 소비 프로젝트 작성 영역과 docs/CONVENTIONS.md의 소비 프로젝트 명령어를 실제 내용으로 채우세요"
echo "  2) (권장) npm i -g claude-memory-layer && claude-memory-layer install && claude-memory-layer import"
echo "  3) Claude Code를 재시작하면 훅·스킬이 활성화됩니다"
echo "  4) 스타터 업데이트 반영: git submodule update --remote $SUB"
