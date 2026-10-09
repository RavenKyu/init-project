#!/bin/bash
# 훅 공통 유틸. 의존성: bash + jq (+ coreutils date). 오류 시에도 워크플로를 막지 않도록 exit 0 기본.

OPT_IN_MARKER="specs/.init-project"
CML_SETTINGS_FILE="${INIT_PROJECT_CLAUDE_SETTINGS:-${HOME:-}/.claude/settings.json}"
HOOK_TMPDIR="${INIT_PROJECT_HOOK_TMPDIR:-${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}}"

# 플러그인으로 실행되면 CLAUDE_PLUGIN_ROOT가 설정된다. 서브모듈 방식은 프로젝트 설정에 직접 등록한다.
is_plugin_mode() { [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; }

# 시작 디렉터리에서 git 루트까지 올라가며 도입 표식을 찾는다. 찾으면 그 디렉터리를 출력한다.
# Claude Code는 세션을 시작한 하위 디렉터리를 CLAUDE_PROJECT_DIR로 넘기므로 상위 탐색이 필요하다.
find_opted_in_root() {
  local d
  d=$(cd "$1" 2>/dev/null && pwd) || return 0
  while :; do
    if [ -f "$d/$OPT_IN_MARKER" ]; then echo "$d"; return 0; fi
    [ -e "$d/.git" ] && return 0
    [ "$d" = "/" ] && return 0
    d=$(dirname "$d")
  done
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
OPTED_IN_ROOT=$(find_opted_in_root "$PROJECT_DIR")
[ -n "$OPTED_IN_ROOT" ] && PROJECT_DIR="$OPTED_IN_ROOT"
SPECS_DIR="$PROJECT_DIR/specs"

# 플러그인 모드는 표식이 있는 프로젝트에서만 동작한다. 서브모듈 방식은 등록 자체가 도입 표시다.
hooks_enabled() { ! is_plugin_mode || [ -n "$OPTED_IN_ROOT" ]; }

# 진행 중 기능의 context.md 목록 (_templates, _archive 제외)
list_feature_contexts() {
  [ -d "$SPECS_DIR" ] || return 0
  for f in "$SPECS_DIR"/*/context.md; do
    [ -e "$f" ] || continue
    case "$f" in
      */_templates/*|*/_archive/*) continue ;;
    esac
    case "$(fm_get "$f" "상태")" in 완료*) continue ;; esac
    echo "$f"
  done
}

# YAML 프론트매터에서 "키: 값" 추출. $1=파일 $2=키
# 주의: BSD awk는 UTF-8 로케일에서 문자열 == 비교가 오동작(strcoll)하므로 index() 접두사 매칭 사용
fm_get() {
  awk -v key="$2" '
    BEGIN { prefix = key ": " }
    NR==1 { if ($0=="---") { inFM=1; next } else exit }
    inFM && $0=="---" { exit }
    inFM && index($0, prefix) == 1 { print substr($0, length(prefix)+1); exit }
  ' "$1" 2>/dev/null
}

# YYYY-MM-DD → 오늘까지 경과 일수. 파싱 실패 시 출력 없음 (macOS/GNU date 모두 지원)
days_since() {
  local d="$1" then_ts now_ts
  [ -n "$d" ] || return 0
  then_ts=$(date -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null) \
    || then_ts=$(date -d "$d" +%s 2>/dev/null) \
    || return 0
  now_ts=$(date +%s)
  echo $(( (now_ts - then_ts) / 86400 ))
}
