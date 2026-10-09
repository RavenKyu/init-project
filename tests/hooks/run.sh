#!/bin/bash
set -euo pipefail

# 플러그인 실행 환경 변수가 개발자 셸에서 새어 들어오지 않게 한다. 플러그인 모드는 케이스별로 명시한다.
unset CLAUDE_PLUGIN_ROOT CLAUDE_PLUGIN_DATA
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOOKS="$ROOT/hooks"
FIXTURES="$ROOT/tests/hooks"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/init-project-hooks.XXXXXX")
trap 'rm -r -- "$TMP"' EXIT

assert_json_event() {
  local output=$1 expected=$2
  printf '%s' "$output" | jq -e --arg event "$expected" '.hookSpecificOutput.hookEventName == $event' >/dev/null
}

assert_stop_message() {
  local output=$1
  printf '%s' "$output" | jq -e '
    .systemMessage
    and (.continue? != false)
    and (has("decision") | not)
    and ((.hookSpecificOutput?.additionalContext // "") == "")
  ' >/dev/null
}

make_settings() {
  local version=$1 root=$2
  mkdir -p "$root/node_modules/claude-memory-layer/dist/hooks"
  printf '{"version":"%s"}\n' "$version" > "$root/node_modules/claude-memory-layer/package.json"
  jq -n --arg command "$root/node_modules/claude-memory-layer/dist/hooks/session-start.js" '{hooks:{SessionStart:[{hooks:[{type:"command",command:$command}]}]}}' > "$TMP/settings.json"
}

project="$TMP/project"
mkdir -p "$project/specs/demo"
printf '%s\n' '---' '상태: 진행중(Phase 1)' '---' > "$project/specs/demo/context.md"

make_settings 2.4.0 "$TMP/cml240"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/settings.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json")
assert_json_event "$out" SessionStart
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("mem-lesson-get") and contains("Project Lessons")' >/dev/null

make_settings 2.3.5 "$TMP/cml235"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/settings.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json")
assert_json_event "$out" SessionStart
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("mem-lesson-list") and contains("업그레이드 권장") and (contains("mem-lesson-get") | not)' >/dev/null

printf '%s\n' '{}' > "$TMP/no-cml.json"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/no-cml.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json")
assert_json_event "$out" SessionStart
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | (contains("mem-lesson-list") | not)' >/dev/null

# 상태 프론트매터가 없는 레거시 context.md 는 추적 대상 밖이므로 활성 기능 목록에
# 올라오지 않는다. 이것이 무너지면 오래된 spec 수백 개가 매 세션 컨텍스트를 채운다.
mkdir -p "$project/specs/legacy"
printf '%s\n' '# 예전 기능 메모' '프론트매터 없음' > "$project/specs/legacy/context.md"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/no-cml.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json")
assert_json_event "$out" SessionStart
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("specs/demo") and (contains("specs/legacy") | not) and (contains("상태: 미기재") | not)' >/dev/null
rm -rf "$project/specs/legacy"

marker_dir="$TMP/markers"
mkdir -p "$marker_dir"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_HOOK_TMPDIR="$marker_dir" bash "$HOOKS/stop_lesson_reminder.sh" < "$FIXTURES/stop.json")
assert_stop_message "$out"
printf '%s' "$out" | jq -e '.systemMessage | contains("어휘 겹침") and contains("환경 의존 실패")' >/dev/null
second=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_HOOK_TMPDIR="$marker_dir" bash "$HOOKS/stop_lesson_reminder.sh" < "$FIXTURES/stop.json")
[ -z "$second" ]

# SessionStart must not infer registration from a different event.
make_settings 2.4.0 "$TMP/wrong-event"
jq '.hooks.Stop = .hooks.SessionStart | del(.hooks.SessionStart)' "$TMP/settings.json" > "$TMP/wrong-event.json"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/wrong-event.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json")
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("mem-lesson-get") | not' >/dev/null

make_settings 2.4.0 "$TMP/path with spaces"
jq '.hooks.SessionStart[0].hooks[0].command |= ("node " + @sh)' "$TMP/settings.json" > "$TMP/quoted.json"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/quoted.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json")
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("mem-lesson-get")' >/dev/null

make_settings nonsense "$TMP/invalid-version"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/settings.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json" 2> "$TMP/stderr")
[ ! -s "$TMP/stderr" ]
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("mem-lesson-list") | not' >/dev/null

out=$(printf '%s' '{bad json' | CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_HOOK_TMPDIR="$marker_dir" bash "$HOOKS/stop_lesson_reminder.sh")
[ -z "$out" ]

jq -e '.hooks.Stop[].hooks[] | select(.command | endswith("/stop_lesson_reminder.sh"))' "$ROOT/hooks/hooks.json" >/dev/null

# Numeric precedence, prerelease boundary, and invalid package metadata.
for version in 2.4.0+build 2.4.1-rc.1 2.10.0 3.0.0; do
  make_settings "$version" "$TMP/version"
  out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/settings.json" bash "$HOOKS/session_start.sh")
  printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("mem-lesson-get")' >/dev/null
done
make_settings 2.4.0-rc.1 "$TMP/version"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/settings.json" bash "$HOOKS/session_start.sh")
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("업그레이드 권장")' >/dev/null
for version in 2.x.0 2.4 02.4.0 999999999999999999999.0.0; do
  make_settings "$version" "$TMP/version"
  out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/settings.json" bash "$HOOKS/session_start.sh" 2> "$TMP/stderr")
  [ ! -s "$TMP/stderr" ]
  printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("mem-lesson-list") | not' >/dev/null
done

# No feature is needed for the CML index reminder; event ordering is unspecified.
mkdir -p "$TMP/empty-project"
make_settings 2.4.0 "$TMP/version"
for source in startup resume compact; do
  jq --arg source "$source" '.source = $source' "$FIXTURES/session_start.json" > "$TMP/input.json"
  out=$(CLAUDE_PROJECT_DIR="$TMP/empty-project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/settings.json" bash "$HOOKS/session_start.sh" < "$TMP/input.json")
  assert_json_event "$out" SessionStart
  printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("mem-lesson-get")' >/dev/null
done

printf '%s' '{bad json' > "$TMP/bad-settings.json"
jq '.disableAllHooks = true' "$TMP/settings.json" > "$TMP/disabled.json"
for settings in "$TMP/no-cml.json" "$TMP/missing.json" "$TMP/bad-settings.json" "$TMP/disabled.json"; do
  out=$(CLAUDE_PROJECT_DIR="$TMP/empty-project" INIT_PROJECT_CLAUDE_SETTINGS="$settings" bash "$HOOKS/session_start.sh" 2> "$TMP/stderr")
  [ -z "$out" ] && [ ! -s "$TMP/stderr" ]
done
for metadata in 'not json' '{}' '{"version":4}'; do
  printf '%s' "$metadata" > "$TMP/version/node_modules/claude-memory-layer/package.json"
  out=$(CLAUDE_PROJECT_DIR="$TMP/empty-project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/settings.json" bash "$HOOKS/session_start.sh" 2> "$TMP/stderr")
  [ -z "$out" ] && [ ! -s "$TMP/stderr" ]
done
jq -n --arg command "$TMP/missing/claude-memory-layer/dist/hooks/session-start.js" '{hooks:{SessionStart:[{hooks:[{type:"command",command:$command}]}]}}' > "$TMP/missing-package.json"
out=$(CLAUDE_PROJECT_DIR="$TMP/empty-project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/missing-package.json" bash "$HOOKS/session_start.sh" 2> "$TMP/stderr")
[ -z "$out" ] && [ ! -s "$TMP/stderr" ]

# Session keys remain independent, expired markers permit a reminder, and bad
# input never creates a default marker or escapes the injected marker directory.
jq '.session_id = "another-session"' "$FIXTURES/stop.json" > "$TMP/another.json"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_HOOK_TMPDIR="$marker_dir" bash "$HOOKS/stop_lesson_reminder.sh" < "$TMP/another.json")
assert_stop_message "$out"
touch -t 200001010000 "$marker_dir/claude_lesson_reminder_test-session"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_HOOK_TMPDIR="$marker_dir" bash "$HOOKS/stop_lesson_reminder.sh" < "$FIXTURES/stop.json")
assert_stop_message "$out"
for input in '{bad' '{"session_id":"../escape"}' '{"session_id":7}' '[]'; do
  out=$(printf '%s' "$input" | CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_HOOK_TMPDIR="$marker_dir" bash "$HOOKS/stop_lesson_reminder.sh" 2> "$TMP/stderr")
  [ -z "$out" ] && [ ! -s "$TMP/stderr" ]
done
[ ! -e "$marker_dir/claude_lesson_reminder_default" ]
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_HOOK_TMPDIR="$TMP/missing-marker-dir" bash "$HOOKS/stop_lesson_reminder.sh" < "$FIXTURES/stop.json" 2> "$TMP/stderr")
[ -z "$out" ] && [ ! -s "$TMP/stderr" ]
printf '%s\n' '---' '상태: 완료' '---' > "$project/specs/demo/context.md"
out=$(CLAUDE_PROJECT_DIR="$project" INIT_PROJECT_HOOK_TMPDIR="$marker_dir" bash "$HOOKS/stop_lesson_reminder.sh" < "$TMP/another.json")
[ -z "$out" ]

# --- 플러그인 모드 (specs/_archive/plugin-distribution R2·R5) ---------------------------------
policy_len() { printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext | length'; }

# 공통 정책은 주입 한도(10,000자) 안에 여유를 두어야 한다 (ADR-002 재검토 조건: 8,000자).
[ "$(jq -Rs 'length' "$ROOT/AGENTS.md")" -le 8000 ]

plugin_project="$TMP/plugin project"
mkdir -p "$plugin_project/specs/demo" "$plugin_project/src/deep"
printf '%s\n' '---' '상태: 진행중(Phase 1)' '---' > "$plugin_project/specs/demo/context.md"

# 표식이 없으면 플러그인 훅은 모두 침묵한다.
out=$(CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$plugin_project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/no-cml.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json")
[ -z "$out" ]
out=$(CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$plugin_project" INIT_PROJECT_HOOK_TMPDIR="$marker_dir" bash "$HOOKS/stop_lesson_reminder.sh" < "$TMP/another.json")
[ -z "$out" ]
out=$(printf '%s' '{"session_id":"edit-silent","tool_input":{"file_path":"src/app.py"}}' | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$plugin_project" INIT_PROJECT_HOOK_TMPDIR="$marker_dir" bash "$HOOKS/posttool_edit.sh")
[ -z "$out" ]

# 표식이 있으면 정책과 진행 중 기능을 한도 안에서 주입한다.
printf '%s\n' 'mode=team' > "$plugin_project/specs/.init-project"
out=$(CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$plugin_project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/no-cml.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json")
assert_json_event "$out" SessionStart
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("[INIT-PROJECT POLICY]") and contains("## 1. 판단과 품질") and contains("[ACTIVE FEATURES]") and contains("specs/demo/context.md")' >/dev/null
[ "$(policy_len "$out")" -le 10000 ]

# 하위 디렉터리에서 시작해도 상위의 표식을 찾는다 (Claude Code는 시작 디렉터리를 CLAUDE_PROJECT_DIR로 넘긴다).
sub_out=$(CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$plugin_project/src/deep" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/no-cml.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json")
[ "$sub_out" = "$out" ]

# 정책이 한도를 넘으면 본문 대신 원본 경로를 안내한다.
big_root="$TMP/big plugin"
mkdir -p "$big_root"
head -c 12000 /dev/zero | tr '\0' 'x' > "$big_root/AGENTS.md"
out=$(CLAUDE_PLUGIN_ROOT="$big_root" CLAUDE_PROJECT_DIR="$plugin_project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/no-cml.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json" 2>/dev/null)
assert_json_event "$out" SessionStart
printf '%s' "$out" | jq -e --arg path "$big_root/AGENTS.md" '.hookSpecificOutput.additionalContext | contains("[INIT-PROJECT POLICY]") and contains($path) and contains("[ACTIVE FEATURES]")' >/dev/null
[ "$(policy_len "$out")" -le 10000 ]

# 서브모듈(프로젝트 설정 등록) 모드는 표식 없이 기존처럼 동작하고 정책을 주입하지 않는다.
rm "$plugin_project/specs/.init-project"
out=$(CLAUDE_PROJECT_DIR="$plugin_project" INIT_PROJECT_CLAUDE_SETTINGS="$TMP/no-cml.json" bash "$HOOKS/session_start.sh" < "$FIXTURES/session_start.json")
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("[ACTIVE FEATURES]") and (contains("[INIT-PROJECT POLICY]") | not)' >/dev/null
printf '%s\n' 'mode=team' > "$plugin_project/specs/.init-project"

# 상태 파일은 테스트 주입 경로 > CLAUDE_PLUGIN_DATA > TMPDIR 순으로 둔다.
plugin_data="$TMP/plugin data"
mkdir -p "$plugin_data"
out=$(printf '%s' '{"session_id":"edit-session","tool_input":{"file_path":"src/app.py"}}' | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$plugin_data" CLAUDE_PROJECT_DIR="$plugin_project" bash "$HOOKS/posttool_edit.sh")
assert_json_event "$out" PostToolUse
[ -e "$plugin_data/claude_spec_sync_edit-session" ]
out=$(printf '%s' '{"session_id":"edit-injected","tool_input":{"file_path":"src/app.py"}}' | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$plugin_data" CLAUDE_PROJECT_DIR="$plugin_project" INIT_PROJECT_HOOK_TMPDIR="$marker_dir" bash "$HOOKS/posttool_edit.sh")
assert_json_event "$out" PostToolUse
[ -e "$marker_dir/claude_spec_sync_edit-injected" ] && [ ! -e "$plugin_data/claude_spec_sync_edit-injected" ]

# 로컬 모드(specs가 git 제외 대상)에서는 커밋 리마인더를 내지 않는다. 추적 중이면 기존처럼 알린다.
commit_input='{"tool_input":{"command":"git commit -m change"}}'
git_commit() { git -C "$plugin_project" -c user.name=t -c user.email=t@t commit -qm "$1"; }
git -C "$plugin_project" init -q
printf '%s\n' 'specs/' > "$plugin_project/.git/info/exclude"
echo one > "$plugin_project/src/app.py"; git -C "$plugin_project" add src; git_commit first
echo two > "$plugin_project/src/app.py"; git -C "$plugin_project" add src; git_commit second
out=$(printf '%s' "$commit_input" | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$plugin_project" bash "$HOOKS/posttool_commit.sh")
[ -z "$out" ]
: > "$plugin_project/.git/info/exclude"
git -C "$plugin_project" add specs; git_commit specs
echo three > "$plugin_project/src/app.py"; git -C "$plugin_project" add src; git_commit third
out=$(printf '%s' "$commit_input" | CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$plugin_project" bash "$HOOKS/posttool_commit.sh")
assert_json_event "$out" PostToolUse

for script in "$HOOKS"/*.sh "$HOOKS"/lib/*.sh "$ROOT/scripts/bootstrap.sh" "$FIXTURES/run.sh"; do
  bash -n "$script"
done
jq empty "$ROOT/hooks/hooks.json"
echo "hooks: all tests passed ($(uname -s))"
