#!/bin/bash
# 훅 공통 유틸. 의존성: bash + jq (+ coreutils date). 오류 시에도 워크플로를 막지 않도록 exit 0 기본.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SPECS_DIR="$PROJECT_DIR/specs"
CML_SETTINGS_FILE="${INIT_PROJECT_CLAUDE_SETTINGS:-${HOME:-}/.claude/settings.json}"
HOOK_TMPDIR="${INIT_PROJECT_HOOK_TMPDIR:-${TMPDIR:-/tmp}}"

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
