#!/bin/bash
# /init-project:setup 스크립트가 팀·로컬 모드에서 기대한 파일만 만들고, 로컬 모드는 git에 흔적을 남기지 않는지 검증한다.
set -euo pipefail
unset CLAUDE_PLUGIN_ROOT CLAUDE_PLUGIN_DATA

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SETUP="$ROOT/skills/setup/setup.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/init-project-setup.XXXXXX")
trap 'rm -r -- "$TMP"' EXIT

new_repo() {
  local repo="$TMP/WINDOWS USER/$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  echo "$repo"
}
setup() { (cd "$1" && bash "$SETUP" "$2" >/dev/null); }
snapshot() { (cd "$1" && find . -path ./.git -prune -o -type f -exec cksum {} + | sort; cat "$(git rev-parse --git-path info/exclude)"); }

# 1) 팀 모드: 문서·표식을 만들고 .gitignore·settings는 건드리지 않는다
repo=$(new_repo team)
setup "$repo" team
[ -f "$repo/docs/ARCHITECTURE.md" ] && [ -f "$repo/docs/CONVENTIONS.md" ] && [ -d "$repo/specs/_archive" ]
grep -qx 'mode=team' "$repo/specs/.init-project"
[ ! -e "$repo/.gitignore" ] && [ ! -e "$repo/.claude/settings.json" ]
git -C "$repo" status --porcelain --untracked-files=all | grep -q 'specs/.init-project'
# 소비 프로젝트 양식에는 스타터 저장소 전용 설명이 없다
! grep -q '스타터 저장소 전용' "$repo/docs/CONVENTIONS.md"

# 2) 재실행은 멱등이고 기존 문서를 보존한다
echo '# 우리 아키텍처' > "$repo/docs/ARCHITECTURE.md"
before=$(snapshot "$repo")
setup "$repo" team
[ "$(snapshot "$repo")" = "$before" ]

# 3) 로컬 모드: git status가 깨끗하고, 이후 만든 기능 문서도 드러나지 않는다
repo=$(new_repo local)
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
mkdir -p "$repo/.claude"
printf '%s\n' '{"enabledPlugins":{"init-project@init-project":true}}' > "$repo/.claude/settings.local.json"
setup "$repo" local
grep -qx 'mode=local' "$repo/specs/.init-project"
[ -f "$repo/docs/ARCHITECTURE.md" ]
[ ! -e "$repo/.gitignore" ]
[ -z "$(git -C "$repo" status --porcelain --untracked-files=all)" ]
mkdir -p "$repo/specs/demo" && echo '상태' > "$repo/specs/demo/context.md"
[ -z "$(git -C "$repo" status --porcelain --untracked-files=all)" ]
git -C "$repo" check-ignore -q specs/demo/context.md

# 4) 로컬 모드 재실행은 exclude를 중복 추가하지 않는다
before=$(snapshot "$repo")
setup "$repo" local
[ "$(snapshot "$repo")" = "$before" ]

# 5) 이미 추적 중인 문서는 로컬 모드에서도 exclude에 넣지 않는다
repo=$(new_repo tracked)
mkdir -p "$repo/docs" && echo '# 팀 문서' > "$repo/docs/CONVENTIONS.md"
git -C "$repo" add docs && git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m docs
setup "$repo" local
! grep -q 'CONVENTIONS' "$(git -C "$repo" rev-parse --git-path info/exclude | sed "s#^#$repo/#")"
grep -qx '# 팀 문서' "$repo/docs/CONVENTIONS.md"

# 6) 모드 전환은 표식을 갱신한다
setup "$repo" team
grep -qx 'mode=team' "$repo/specs/.init-project"

# 7) 하위 디렉터리에서 실행해도 git 루트에 만든다
repo=$(new_repo subdir)
mkdir -p "$repo/src/deep"
setup "$repo/src/deep" team
[ -f "$repo/specs/.init-project" ] && [ ! -e "$repo/src/deep/specs" ]

# 8) 잘못된 모드·git 밖 로컬 모드는 실패하고 아무것도 만들지 않는다
mkdir -p "$TMP/plain"
! (cd "$TMP/plain" && bash "$SETUP" local >/dev/null 2>&1)
! (cd "$TMP/plain" && bash "$SETUP" bogus >/dev/null 2>&1)
[ -z "$(ls -A "$TMP/plain")" ]

# 9) 설치 후 플러그인 SessionStart가 표식을 찾아 정책을 주입한다
out=$(CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$TMP/WINDOWS USER/local" INIT_PROJECT_CLAUDE_SETTINGS=/dev/null bash "$ROOT/hooks/session_start.sh" < "$ROOT/tests/hooks/session_start.json")
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("[INIT-PROJECT POLICY]")' >/dev/null

bash -n "$SETUP"
echo "setup: all tests passed ($(uname -s))"
