#!/bin/bash
# init-project 플러그인을 현재 프로젝트에 도입한다 (멱등 — 재실행 안전).
#   bash setup.sh team    docs·specs·도입 표식을 만들고 커밋 대상으로 둔다
#   bash setup.sh local   같은 파일을 만들되 .git/info/exclude에 등록해 저장소에 흔적을 남기지 않는다
# .gitignore와 .claude/settings.json은 수정하지 않는다. 기존 파일은 덮어쓰지 않는다.
set -euo pipefail

MODE="${1:-}"
case "$MODE" in
  team|local) ;;
  *) echo "사용법: setup.sh team|local" >&2; exit 2 ;;
esac

SKILL_DIR=$(cd "$(dirname "$0")" && pwd)
if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
elif [ "$MODE" = local ]; then
  echo "오류: 로컬 모드는 git 저장소에서만 쓸 수 있습니다 (.git/info/exclude 사용)." >&2
  exit 1
fi

created() { echo "  + $1"; }
skipped() { echo "  = $1 (이미 존재, 건너뜀)"; }
new_files=()

echo "[1/3] docs/"
mkdir -p docs/adr
for f in ARCHITECTURE.md CONVENTIONS.md; do
  if [ -f "docs/$f" ]; then skipped "docs/$f"; else
    cp "$SKILL_DIR/templates/$f" "docs/$f"; created "docs/$f"; new_files+=("/docs/$f"); fi
done

echo "[2/3] specs/ · 도입 표식"
mkdir -p specs/_archive
marker=specs/.init-project
if [ -f "$marker" ] && grep -qx "mode=$MODE" "$marker"; then skipped "$marker (mode=$MODE)"; else
  [ -f "$marker" ] && echo "  ~ $marker: mode=$MODE로 변경" || created "$marker (mode=$MODE)"
  printf 'mode=%s\n' "$MODE" > "$marker"
fi

echo "[3/3] git 제외 설정"
if [ "$MODE" = local ]; then
  exclude=$(git rev-parse --git-path info/exclude)
  mkdir -p "$(dirname "$exclude")"
  touch "$exclude"
  # specs/ 전체를 제외해야 이후 /init-project:feature가 만드는 기능 문서도 드러나지 않는다.
  for line in "/specs/" "/.claude/settings.local.json" "${new_files[@]+"${new_files[@]}"}"; do
    if grep -qxF "$line" "$exclude"; then skipped "exclude: $line"; else
      echo "$line" >> "$exclude"; created "exclude += $line"; fi
  done
  if git ls-files --error-unmatch specs >/dev/null 2>&1; then
    echo "  ! specs/에 이미 추적 중인 파일이 있습니다. 추적 파일은 계속 git에 나타납니다."
  fi
else
  echo "  = 팀 모드: 생성물을 커밋 대상으로 둡니다 (.gitignore 미수정)"
fi

echo ""
echo "init-project setup 완료 (mode=$MODE). 다음 단계:"
echo "  1) docs/ARCHITECTURE.md·CONVENTIONS.md를 실제 구조와 검증 명령으로 채우세요"
if [ "$MODE" = team ]; then
  echo "  2) docs/·specs/와 .claude/settings.json의 플러그인 등록(--scope project)을 커밋하세요"
else
  echo "  2) 플러그인은 --scope local로 설치하세요 (.claude/settings.local.json만 기록됨)"
fi
echo "  3) 새 세션부터 공통 정책이 주입되고 리마인더 훅이 동작합니다"
