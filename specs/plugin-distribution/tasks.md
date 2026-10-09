# 플러그인 배포 Tasks

> plan.md의 각 Phase를 실행 단위로 분해한 체크리스트. 번호(T1, T2, ...)는 현재 실행 순서이며 조정 시 이유를 기록한다.
> 세부 작업 추가·순서 조정·Phase 보고·승인 판단은 AGENTS.md §2.2~2.3을 따른다.
> 작업 단위: 변경 → 관련 검증 → 문서 동기화 → 체크. 커밋은 AGENTS.md §4 조건에 따라 묶는다.

## 실행 순서 근거 (한 줄)

플랫폼 동작이 불확실한 부분(T1)이 이후 배치를 결정하므로 먼저 검증하고, 동작 보존 이동(T2~T4)을 동작 변경(T5~) 앞에 둔다.

## Phase 1: 플랫폼 검증

- [x] T1. 스크래치 디렉터리에 시험 플러그인을 만들어 루트 배치 validate, 훅 환경 변수, 스킬 양식 참조, local scope 기록 위치, 태그 ref 등록을 확인하고 배치를 확정 → 검증: 결과와 결정을 context.md에 기록

## Phase 2: 구조 이동 (structural, 한 커밋)

- [x] T2. (structural) `.claude/hooks/` → `hooks/`, `.claude/skills/<name>/` → `skills/<name>/`, `specs/_templates/` → `skills/feature/templates/` 이동 → 검증: 이동 전후 `bash tests/hooks/run.sh`
- [x] T3. (structural) 호환 심링크 `.claude/hooks → ../hooks`, `.claude/skills/<name> → ../../skills/<name>`, `specs/_templates → ../skills/feature/templates` 추가, tests·bootstrap의 원본 경로 갱신 → 검증: `bash tests/bootstrap/run.sh`, 기존 소비 프로젝트 경로(`init-project/.claude/hooks/*.sh`) 실행 확인
- [x] T4. (structural) ARCHITECTURE.md 모듈 표의 위치 갱신 → 검증: 경로 대조

## Phase 3: 플러그인 등록 (R1, R7)

- [x] T5. `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `hooks/hooks.json`(`"${CLAUDE_PLUGIN_ROOT}"` 따옴표 경로) 추가 → 검증: `claude plugin validate .`, `jq empty`
- [x] T6. 스타터 `.claude/settings.json`에서 훅 등록 제거, CONVENTIONS.md에 `claude --plugin-dir .` 개발 명령과 설치본 비활성화 방법 추가 → 검증: `--plugin-dir .` 세션에서 스킬 세 개 표시, 훅 각 1회 실행
- [x] T7. tests/bootstrap의 훅 명령 실행 검사를 `hooks/hooks.json` 기준으로도 수행(플러그인 루트 공백 경로 포함) → 검증: `bash tests/bootstrap/run.sh`

## Phase 4: 훅 동작 변경 (R2, R5, 테스트 우선)

- [x] T8. 실패 테스트 추가: 표식 없는 프로젝트의 SessionStart 무출력, 표식 있는 프로젝트의 정책 포함 출력, 주입 문자열 10,000자 이하, AGENTS.md 8,000자 초과 시 실패 → 검증: 새 케이스가 실패하는 것 확인
- [x] T9. `lib/common.sh`에 프로젝트 루트 탐색(`CLAUDE_PROJECT_DIR`에서 상위로 표식·git 루트 탐색, T1에서 하위 디렉터리 시작 시 그 디렉터리가 전달됨을 확인), 표식 확인과 `HOOK_TMPDIR` 기본값(`CLAUDE_PLUGIN_DATA` → TMPDIR) 추가, 네 훅을 표식으로 게이트, SessionStart에 `${CLAUDE_PLUGIN_ROOT}/AGENTS.md` 주입과 한도 초과 시 경로 안내 대체 → 검증: `bash tests/hooks/run.sh`
- [x] T10. `posttool_edit.sh`의 스로틀 마커를 `HOOK_TMPDIR`로 변경 → 검증: 마커가 주입한 임시 디렉터리에만 생기는 테스트
- [x] T11. 실패 테스트 후 구현: 활성 context가 git 제외 대상이면 `posttool_commit.sh`가 리마인더를 내지 않음, 추적되는 경우 기존 출력 유지 → 검증: `bash tests/hooks/run.sh`
- [x] T12. 스타터 저장소에 `specs/.init-project`(mode=team) 추가, CLAUDE.md의 `@AGENTS.md` import를 개발 안내 문장으로 교체 → 검증: `--plugin-dir .` 세션에서 정책이 한 번만 주입됨

## Phase 5: setup 스킬 (R3, R4)

- [x] T13. 실패 테스트 `tests/setup/run.sh` 작성: 팀 모드 생성물과 기존 파일 보존, 로컬 모드 `.git/info/exclude` 등록과 `git status` 깨끗함, `.gitignore`·settings 미수정, 재실행 멱등 → 검증: 실패 확인
- [x] T14. `skills/setup/setup.sh team|local`과 소비 프로젝트용 ARCHITECTURE·CONVENTIONS 양식(`skills/setup/templates/`) 구현. 로컬 모드는 전역 exclude가 없는 환경에 대비해 `.claude/settings.local.json`도 `.git/info/exclude`에 등록 → 검증: `bash tests/setup/run.sh`
- [x] T15. `skills/setup/SKILL.md` 작성: 모드 확인(설치 scope와 일치), 스크립트 실행, 결과 보고 → 검증: `--plugin-dir .`로 임시 프로젝트에서 `/init-project:setup` 실행
- [ ] T15a. (T15에서 발견) 루트 `.mcp.json`이 플러그인 MCP로 로드되어 미설치 환경에서 연결 실패 → bootstrap 전용 자산(`scripts/mcp.json`)으로 이동. `plugin.json`의 `mcpServers: {}`로는 억제되지 않음 → 검증: `claude --plugin-dir . mcp list`에 플러그인 MCP 없음, `bash tests/bootstrap/run.sh`

## Phase 6: 문서·전환 안내 (R6, R8)

- [ ] T16. feature·handoff·learn 스킬과 양식의 경로 문구를 플러그인 기준으로 수정 (양식은 `${CLAUDE_SKILL_DIR}/templates/`) → 검증: `grep`으로 소비 프로젝트 `specs/_templates/` 전제 문구 없음
- [ ] T17. AGENTS.md §0 표와 CONVENTIONS.md의 양식·스킬 위치 문구 수정 (경로만, 정책 변경 없음) → 검증: AGENTS.md 길이 8,000자 이하, 정책 문장 diff 없음
- [ ] T18. README를 플러그인 설치(팀·로컬, 한 줄 설치 `/plugin install init-project --marketplace <owner>/<repo>` 포함)·태그 ref 고정·서브모듈 전환 안내로 개편, bootstrap에 폐지 예고 출력 추가 → 검증: 링크 대조, `bash tests/bootstrap/run.sh`
- [ ] T19. ARCHITECTURE.md 배포·의존성 방향 갱신 → 검증: 실제 구조와 대조

## Phase 7: 종단 검증과 완료 처리

- [ ] T20. 임시 git 프로젝트 두 개에서 로컬 마켓플레이스로 팀(project scope)·로컬(local scope) 설치 후 setup·세션 시작·커밋 시나리오 확인. 태그 ref 고정은 원격 저장소가 필요해 push 승인 후 확인 → 검증: 결과를 context.md에 기록
- [ ] T21. 전체 검증(`git diff --check`, `bash tests/hooks/run.sh`, `bash tests/bootstrap/run.sh`, `bash tests/setup/run.sh`, `jq empty`, `claude plugin validate .`) 후 spec 완료 기준 체크, context 완료, `specs/_archive/`로 이동 → 검증: 명령 결과

## 승인 필요한 변경 (해당 시)

- [ ] (보류) bootstrap·호환 심링크 제거 — 알려진 서브모듈 소비 프로젝트의 전환 완료 후 별도 작업
- [ ] (보류) 마켓플레이스 첫 태그 생성(`claude plugin tag`, 형식 `init-project--v<version>`)·push 및 `owner/repo#<tag>` 고정 확인 — 외부 행위라 실행 직전 사용자 권한 확인
