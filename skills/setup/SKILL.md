---
name: setup
description: init-project 플러그인을 현재 프로젝트에 도입한다. docs 양식·specs·도입 표식을 만들고, 팀 공유(커밋) 또는 로컬 전용(git 제외) 모드를 적용한다. 사용자가 도입·설정·setup을 요청할 때 사용한다.
---

# /init-project:setup — 프로젝트 도입

이 스킬은 새 승인 조건을 만들지 않는다. 기존 파일은 덮어쓰지 않는다.

1. 모드를 정한다. 사용자가 지정했으면 따른다. 아니면 플러그인 등록 위치로 판단한다.
   - `.claude/settings.local.json`의 `enabledPlugins`에 init-project가 있으면 `local`
   - `.claude/settings.json`에 있으면 `team`
   - 둘 다 아니면(사용자 범위 설치 등) 팀 공유인지 로컬 전용인지 묻는다.
2. `bash "${CLAUDE_SKILL_DIR}/setup.sh" <team|local>`을 실행한다. 스크립트가 git 루트를 찾아 그곳에 만든다.
3. 출력의 생성·건너뜀·exclude 결과를 그대로 보고한다. 실패하면 오류 메시지와 원인을 보고하고 우회하지 않는다.
4. 팀 모드면 커밋 대상(docs/, specs/, 플러그인 등록)을 안내한다. 커밋은 사용자가 요청할 때 한다.
5. 공통 정책은 다음 세션부터 주입된다고 알린다. 이번 세션에서는 `${CLAUDE_PLUGIN_ROOT}/AGENTS.md`를 읽고 따른다.
