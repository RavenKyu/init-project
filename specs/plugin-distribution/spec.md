# 플러그인 배포 Spec

> 작성일: 2026-10-09 / 상태: 승인됨 (2026-10-09, 열린 질문은 권장안으로 결정)
> ⚠️ 승인 후에는 사용자 지시 없이 수정 금지

## 목표

Claude Code 사용자가 서브모듈·bootstrap 없이 마켓플레이스 플러그인으로 스타터를 도입하고, 원하면 저장소에 아무것도 커밋하지 않고 로컬에서만 사용할 수 있게 한다.

## 요구사항

- R1. Given Claude Code와 스타터 마켓플레이스, When `/plugin marketplace add`와 `/plugin install`을 실행하면, Then 서브모듈 추가·bootstrap 실행 없이 `/init-project:feature`, `/init-project:handoff`, `/init-project:learn`과 네 리마인더 훅(SessionStart·PostToolUse 2종·Stop)이 동작한다.
- R2. Given 도입 표식이 있는 프로젝트, When 세션이 시작되면, Then SessionStart가 공통 정책(AGENTS.md)과 기존 [ACTIVE FEATURES]·메모리 안내를 `additionalContext` 10,000자 이내로 주입한다. Given 표식이 없는 프로젝트, Then 아무것도 출력하지 않는다.
- R3. Given 도입 전 프로젝트, When `/init-project:setup`(팀 모드)을 실행하면, Then docs/ARCHITECTURE.md·CONVENTIONS.md, specs/_archive/, 도입 표식을 생성하고 기존 파일은 덮어쓰지 않는다.
- R4. Given `--scope local` 설치, When `/init-project:setup`(로컬 모드)을 실행하면, Then 생성물과 표식을 `.git/info/exclude`에 등록하고 `.gitignore`·`.claude/settings.json`을 수정하지 않는다. 이후 `git status`에 스타터 관련 변경이 나타나지 않는다.
- R5. Given specs/가 git 제외 대상인 프로젝트, When 코드 변경을 커밋하면, Then 커밋 리마인더([SPEC SYNC])를 출력하지 않는다. specs/가 추적되는 프로젝트의 기존 동작은 유지한다.
- R6. Given 플러그인 모드, When `/init-project:feature`로 새 기능 문서를 만들면, Then 플러그인에 포함된 양식을 사용한다. 스킬·양식·AGENTS.md 문구는 소비 프로젝트의 `specs/_templates/`나 프로젝트 내 AGENTS.md 사본을 전제하지 않는다.
- R7. Given 스타터 저장소 자체, When 개발 세션을 실행하면, Then 각 훅이 한 번만 실행된다 (프로젝트 설정과 플러그인의 중복 등록 없음).
- R8. Given 기존 서브모듈 소비 프로젝트, When 전환 안내를 따르면, Then 서브모듈·심링크·훅 등록을 제거하고 플러그인으로 옮길 수 있으며 소비 프로젝트의 docs·specs 내용은 보존된다. (지원 기간은 Q1 결정에 따름)

## 비목표 (Non-Goals)

- Codex 등 다른 에이전트 지원 — 사용자 결정(2026-10-09)으로 Claude Code 전용.
- 메모리 MCP(claude-memory-layer) 번들링 — 전역 설치가 필요해 미설치 환경에서 서버 시작이 실패한다. 선택적 연결로 유지한다.
- 기존 CLAUDE.md·settings.json 자동 병합 — 사용자 설정 덮어쓰기 위험.
- 공개 마켓플레이스 등록·외부 배포 — 별도 권한이 필요하다.
- 정책 내용 자체의 개정 — 전달 경로만 바꾼다.

## 제약

- 호환성: 훅은 bash와 jq만 사용하고, 오류 시에도 종료 0으로 작업을 막지 않는다. context.md의 기능·상태·마지막 갱신 프론트매터 키를 유지한다.
- 크기: SessionStart `additionalContext`는 10,000자를 넘으면 미리보기 2,000자만 들어간다. 현재 AGENTS.md는 6,899자다.
- 경로: `${CLAUDE_PLUGIN_ROOT}`는 업데이트마다 바뀌므로 상태 파일은 `${CLAUDE_PLUGIN_DATA}`(없으면 TMPDIR)에 둔다. 셸 형식 훅 명령은 경로를 따옴표로 감싼다.
- 테스트 격리: 훅 테스트는 실제 사용자 설정·플러그인 데이터를 읽거나 쓰지 않는다.
- 승인: 배포 모델 변경은 AGENTS.md §1.2 대상이다. [ADR-002](../../docs/adr/002-plugin-distribution.md)는 2026-10-09 승인됐다.

## 결정된 질문 (2026-10-09 사용자 승인: 권장안)

- Q1. 서브모듈 방식을 유지할까? 결정: 플러그인으로 대체하고 bootstrap은 전환 기간 동안만 유지 후 제거. 두 방식 병행은 훅 경로·스킬 이름·양식 위치를 이중으로 관리해야 한다.
- Q2. 도입 표식을 무엇으로 할까? 결정: setup이 만드는 `specs/.init-project` 파일. `specs/` 존재만으로 판단하면 다른 용도의 specs 폴더를 가진 프로젝트에도 정책이 주입된다.
- Q3. 팀의 버전 고정 방식은? 결정: 마켓플레이스를 태그 ref(`owner/repo#vX.Y`)로 등록. 서브모듈의 커밋 고정을 대체한다.

## 완료 기준 (Definition of Done)

- [ ] R1~R8에 대응하는 검증 완료 (훅은 tests/hooks 샘플 입력, 플러그인은 `claude plugin validate`와 임시 프로젝트 설치 확인)
- [ ] `bash tests/hooks/run.sh`, `git diff --check`, 설정 JSON `jq empty` 통과
- [ ] README·ARCHITECTURE.md·CONVENTIONS.md 갱신, ADR-002 승인 및 ADR-001 상태를 대체됨으로 갱신
- [ ] R4 로컬 모드에서 임시 git 저장소의 `git status`가 깨끗함을 확인
