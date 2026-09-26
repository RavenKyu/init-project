#!/bin/bash
# bootstrap 이 만든 훅 명령이 공백을 포함한 프로젝트 경로에서도 실행되는지 검증한다.
# (예: Windows 의 C:\Users\WINDOWS USER\... — 따옴표 없는 ${CLAUDE_PROJECT_DIR} 는 두 단어로 쪼개진다)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
FIXTURES="$ROOT/tests/hooks"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/init-project-bootstrap.XXXXXX")
trap 'rm -r -- "$TMP"' EXIT

# 쪼개진 첫 단어("$TMP/WINDOWS")에 실제 파일이 있던 사고를 재현하는 미끼
printf '#!/bin/sh\nexit 3\n' > "$TMP/WINDOWS"
chmod +x "$TMP/WINDOWS"

new_project() {
  local project="$TMP/WINDOWS USER/$1"
  mkdir -p "$project"
  cp -R "$ROOT" "$project/init-project"
  echo "$project"
}

bootstrap() {
  (cd "$1" && bash init-project/scripts/bootstrap.sh >/dev/null)
}

# settings.json 의 모든 훅 명령을 Claude Code 처럼 셸로 실행해 종료 0 인지 확인한다.
assert_hook_commands_run() {
  local project=$1 event command input
  jq -r '.hooks | to_entries[] | .key as $event | .value[].hooks[] | select(.type == "command") | "\($event)\t\(.command)"' \
    "$project/.claude/settings.json" > "$TMP/commands"
  [ -s "$TMP/commands" ]
  while IFS=$'\t' read -r event command; do
    case "$event" in
      SessionStart) input="$FIXTURES/session_start.json" ;;
      Stop) input="$FIXTURES/stop.json" ;;
      *) input=/dev/null ;;
    esac
    if ! CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS=/dev/null INIT_PROJECT_HOOK_TMPDIR="$TMP" \
      sh -c "$command" < "$input" >/dev/null 2> "$TMP/stderr"; then
      echo "실패: [$event] $command" >&2
      cat "$TMP/stderr" >&2
      return 1
    fi
  done < "$TMP/commands"
}

# 1) 새 소비 프로젝트
project=$(new_project fresh)
bootstrap "$project"
assert_hook_commands_run "$project"

# 2) 따옴표 없이 생성된 기존 settings.json 은 재실행 시 치유되고, 다른 명령은 그대로 둔다
project=$(new_project legacy)
mkdir -p "$project/.claude"
cat > "$project/.claude/settings.json" <<'EOF'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/init-project/.claude/hooks/stop_lesson_reminder.sh"
          },
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/init-project/.claude/hooks/stop_lesson_reminder.sh"
          },
          {
            "type": "command",
            "command": "echo keep"
          }
        ]
      }
    ]
  }
}
EOF
bootstrap "$project"
assert_hook_commands_run "$project"
jq -e '[.hooks.Stop[].hooks[].command] | index("echo keep") != null' "$project/.claude/settings.json" >/dev/null

# 3) 재실행은 멱등이다
cp "$project/.claude/settings.json" "$TMP/before.json"
bootstrap "$project"
cmp -s "$TMP/before.json" "$project/.claude/settings.json"

echo "bootstrap: all tests passed ($(uname -s))"
