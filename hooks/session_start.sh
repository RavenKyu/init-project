#!/bin/bash
# SessionStart: 진행 중 기능의 context.md를 안내하고, 30일 초과 미갱신은 아카이브 검토를 제안.
# 진행 중 기능 또는 확인된 CML 등록이 있을 때만 안내한다.
set -uo pipefail
. "$(dirname "$0")/lib/common.sh" || exit 0
command -v jq >/dev/null 2>&1 || exit 0

lines=""
while IFS= read -r f; do
  status=$(fm_get "$f" "상태")
  updated=$(fm_get "$f" "마지막 갱신")
  # 상태 프론트매터가 없는 문서는 "진행 중"이 아니라 추적 대상 밖(레거시)이다.
  # 이를 진행 중으로 취급하면 오래된 spec 수백 개가 매 세션 컨텍스트를 채워,
  # 정작 읽어야 할 진행 중 문서와 아래 메모리 회수 안내가 묻힌다.
  [ -n "$status" ] || continue
  rel="${f#"$PROJECT_DIR"/}"
  extra=""
  days=$(days_since "$updated")
  if [ -n "$days" ] && [ "$days" -gt 30 ]; then
    extra=" — ${days}일 경과: 계속 진행할지, specs/_archive/로 옮길지 검토"
  fi
  lines="${lines}- ${rel} (상태: ${status}, 마지막 갱신: ${updated:-미기재})${extra}"$'\n'
done < <(list_feature_contexts)

mem_note=""
# Tokenize the registered command without executing it; preserve quoted spaces.
session_script=$(jq -er '
  select(.disableAllHooks != true) |
  [.hooks.SessionStart[]?.hooks[]? | select(.type == "command") |
   .command | strings | scan("\u0027[^\u0027]*\u0027|\"[^\"]*\"|[^[:space:]]+") |
   sub("^[\u0027\"]"; "") | sub("[\u0027\"]$"; "") |
   select(startswith("/") and endswith("/claude-memory-layer/dist/hooks/session-start.js"))][0] // empty
' "$CML_SETTINGS_FILE" 2>/dev/null) || session_script=""

if [ -n "$session_script" ]; then
  package_json="${session_script%/dist/hooks/session-start.js}/package.json"
  cml_version=$(jq -er '.version | strings' "$package_json" 2>/dev/null) || cml_version=""
  # Reject malformed/oversized numeric fields before bash arithmetic. Prereleases
  # of 2.4.0 precede the index release; build metadata does not affect precedence.
  version_pattern='^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
  if [[ "$cml_version" =~ $version_pattern ]]; then
    cml_major=${BASH_REMATCH[1]}; cml_minor=${BASH_REMATCH[2]}; cml_patch=${BASH_REMATCH[3]}
    prerelease=${BASH_REMATCH[4]:-}
    if (( cml_major > 2 || (cml_major == 2 && (cml_minor > 4 || (cml_minor == 4 && cml_patch > 0))) )) ||
       { (( cml_major == 2 && cml_minor == 4 && cml_patch == 0 )) && [ -z "$prerelease" ]; }; then
      mem_note='관련 교훈이 세션 컨텍스트의 `## Project Lessons` 인덱스에 보이면 `mem-lesson-get`(이름)으로 본문을 열고 나서 작업하세요. 인덱스에 없으면 `mem-lesson-list`로 전체를 볼 수 있습니다.'
    else
      mem_note='과거 맥락·교훈은 mem-context-pack / mem-lesson-list로 회수할 수 있습니다 (AGENTS.md §2.8).
업그레이드 권장: npm i -g claude-memory-layer'
    fi
  fi
fi

msg="$mem_note"
if [ -n "$lines" ]; then
  msg="[ACTIVE FEATURES] 진행 중인 기능 문서:
${lines}작업 시작 전 해당 context.md를 읽고, 현재 상태를 한 문단으로 보고한 뒤 AGENTS.md §2.1에 따라 진행하세요.
${mem_note}"
fi
[ -z "$msg" ] && exit 0

jq -n --arg ctx "$msg" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}' 2>/dev/null
exit 0
