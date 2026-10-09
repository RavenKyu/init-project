#!/bin/bash
# PostToolUse(Bash): git commit 감지 → 직전 커밋에 코드 변경은 있는데
# specs/*/tasks.md·context.md 갱신이 없으면 경고 (차단 아님, 리마인더).
set -uo pipefail
. "$(dirname "$0")/lib/common.sh" || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

active=$(list_feature_contexts | head -1)
[ -z "$active" ] && exit 0

cd "$PROJECT_DIR" 2>/dev/null || exit 0
files=$(git diff --name-only HEAD~1 HEAD 2>/dev/null) || exit 0
[ -z "$files" ] && exit 0

code_changed=0
docs_changed=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    specs/*/tasks.md|specs/*/context.md) docs_changed=1 ;;
    *.md|docs/*|specs/*|.claude/*) ;;
    *) code_changed=1 ;;
  esac
done <<< "$files"

if [ "$code_changed" -eq 1 ] && [ "$docs_changed" -eq 0 ]; then
  jq -n '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"[SPEC SYNC] 방금 커밋에 코드 변경이 있지만 tasks.md/context.md 갱신이 없습니다. 관련 문서에 실제 누락이 있는지 확인하고, 있으면 동기화하세요 (AGENTS.md §2.7)."}}'
fi
exit 0
