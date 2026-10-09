#!/bin/bash
# PostToolUse(Edit|Write): 코드 수정 후 tasks.md 체크 / context.md 갱신 리마인더.
# 문서(.md, docs/, specs/) 수정이거나 진행 중 기능이 없으면 침묵. 30분에 1회로 스로틀.
set -uo pipefail
. "$(dirname "$0")/lib/common.sh" || exit 0

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file_path" ] && exit 0

case "$file_path" in
  *.md|*/docs/*|docs/*|*/specs/*|specs/*|*/.claude/*|.claude/*) exit 0 ;;
esac

active=$(list_feature_contexts | head -1)
[ -z "$active" ] && exit 0

session_id=$(printf '%s' "$input" | jq -r '.session_id // "default"' 2>/dev/null)
marker="${TMPDIR:-/tmp}/claude_spec_sync_${session_id:-default}"
if [ -f "$marker" ] && [ -n "$(find "$marker" -mmin -30 2>/dev/null)" ]; then
  exit 0
fi
touch "$marker" 2>/dev/null

jq -n '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"[SPEC SYNC] 코드가 수정되었습니다. 완료한 작업은 tasks.md에 체크하고, 의미 있는 결정과 재개에 필요한 미해결 사실은 context.md에 기록하세요 (마지막 갱신 날짜 포함)."}}'
exit 0
