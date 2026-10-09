# Conventions

> 마지막 갱신: 2026-09-05
> 이 파일은 소비 프로젝트에도 복사된다. 소비 프로젝트에서는 바로 아래 명령 표를 먼저 채우고 사용한다.

## 소비 프로젝트 명령어 — 도입 시 작성

| 목적 | 실제 명령어 |
|------|-------------|
| 전체 테스트 | 미정 |
| 관련 테스트 | 미정 |
| 린트·포맷 | 미정 |
| 타입 검사 | 미정 또는 해당 없음 |
| 빌드 | 미정 또는 해당 없음 |

패키지 설정·CI 등에서 확인한 명령으로 채운다. 미정 항목은 검증 제약으로 보고하고 실행했다고 주장하지 않는다.

## 스타터 저장소 전용 명령어

> 아래 표는 이 파일이 `init-project` 저장소 자체에 있을 때만 유효하다. 소비 프로젝트의 애플리케이션 검증에 사용하지 않는다.

| 목적 | 명령어 | 적용 |
|------|--------|------|
| diff 공백 오류 | git diff --check | 모든 변경 |
| 훅 회귀·셸 구문 | bash tests/hooks/run.sh | 훅 관련 변경·완료 검증 (러너가 각 셸 파일을 개별 검사) |
| bootstrap 공백 경로·기존 설정 치유 | bash tests/bootstrap/run.sh | bootstrap·훅 설정 변경 |
| 훅·플러그인 설정 JSON | jq empty hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json | 설정 변경 |
| 플러그인 매니페스트 | claude plugin validate . | 매니페스트·스킬·훅 등록 변경 (CLAUDE.md·README 경고는 알려진 경고) |
| MCP 설정 JSON | jq empty .mcp.json | 설정 변경 |
| SessionStart 빈 프로젝트 샘플 | printf '%s' '{}' &#124; INIT_PROJECT_CLAUDE_SETTINGS=/dev/null CLAUDE_PROJECT_DIR=/dev/null bash hooks/session_start.sh | CML 미등록 조건에서 종료 0, 출력 없음 |
| 애플리케이션 테스트·타입·빌드 | 해당 없음 | 이 저장소는 문서·셸 스타터 |

표의 &#124;는 셸 파이프 기호다.

## 변경 유형별 검증

- 문서·스킬: 상대 링크와 경로, 필수 프론트매터, 승인 경계 및 AGENTS.md와의 일관성을 확인한다. 테스트 파일을 형식적으로 추가하지 않는다.
- 훅: 임시 프로젝트의 specs에 context를 만들고 CLAUDE_PROJECT_DIR를 지정해 샘플 stdin JSON으로 직접 실행한다. 활성 기능·완료 기능·빈 프로젝트의 출력과 종료 코드를 확인한다. PostToolUse는 실제 tool_input.file_path 또는 tool_input.command 형태를 사용한다.
- bootstrap: 임시 소비 프로젝트에서 기본 경로로 실행해 생성 파일·스킬/템플릿 심링크·훅 경로를 확인한다. 재실행하여 기존 문서·설정 보존을 확인한다. 실제 사용자 프로젝트를 검증용으로 변경하지 않는다.
- 훅 회귀 러너는 tests/hooks/run.sh, bootstrap 회귀 러너는 tests/bootstrap/run.sh다(공백 포함 경로에서 생성된 훅 명령을 실제로 실행). bootstrap 전체 배포 검증은 별도이며, 셸 구문만으로 동작 검증을 통과했다고 하지 않는다.

## 명명·문서 컨벤션

- 기능 폴더와 스킬 이름은 kebab-case. ADR은 NNN-title.md.
- 새 기능 문서·ADR은 specs/_templates/의 해당 파일을 복사한다.
- 상태·체크박스·검증 결과는 실제 작업과 일치시킨다.
- 공통 승인 정책은 AGENTS.md에만 정의한다. 다른 파일에서는 해당 절을 참조한다.
