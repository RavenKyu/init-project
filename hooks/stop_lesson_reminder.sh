#!/bin/bash
# Stop: 재사용 가능한 교훈을 저장하도록 세션당 30분에 1회 리마인드.
set -uo pipefail
. "$(dirname "$0")/lib/common.sh" || exit 0
command -v jq >/dev/null 2>&1 || exit 0

active=$(list_feature_contexts | head -1)
[ -z "$active" ] && exit 0

input=$(cat)
session_id=$(printf '%s' "$input" | jq -er 'select(type == "object") | .session_id // "default" | strings | select(test("^[A-Za-z0-9_.-]+$"))' 2>/dev/null) || exit 0
marker="$HOOK_TMPDIR/claude_lesson_reminder_${session_id:-default}"
if [ -f "$marker" ] && [ -n "$(find "$marker" -mmin -30 2>/dev/null)" ]; then
  exit 0
fi
touch "$marker" 2>/dev/null || exit 0

jq -n '{systemMessage:"[LESSON CHECK] 재사용 가능한 교훈이 있다면 mem-lesson-save로 저장하세요.\ntrigger에는 미래의 내가 검색할 증상·명령어·에러 문자열을 그대로 넣으세요(회수는 어휘 겹침으로 결정됩니다).\n환경 의존 실패·일회성 서사·미검증 우회는 저장하지 마세요. 판단이 안 서면 mem-lesson-candidates로 후보를 확인하세요. 단순 진행 상황 보고라면 무시해도 됩니다."}' 2>/dev/null
exit 0
