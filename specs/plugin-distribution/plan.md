# 플러그인 배포 Plan

> 작성일: 2026-10-09 / 상태: 승인됨
> 근거 문서: [spec.md](./spec.md), [ADR-002](../../docs/adr/002-plugin-distribution.md)

## 아키텍처 영향

| 항목 | 내용 |
|------|------|
| 관련 모듈/레이어 | 배포(bootstrap → 플러그인 매니페스트·setup), 리마인더(.claude/hooks → hooks/), 선택적 절차(.claude/skills → skills/), 양식(specs/_templates → skills/feature/templates/), 에이전트 연결(CLAUDE.md·.claude/settings.json) |
| 새 외부 의존성 | 없음. Claude Code 플러그인 시스템만 사용 |
| 모듈 경계/공개 API 변경 | 스킬 이름이 `/feature` → `/init-project:feature`로 바뀐다. 기존 서브모듈 소비 프로젝트가 참조하는 `.claude/hooks/`·`.claude/skills/`·`specs/_templates` 경로는 전환 기간 동안 호환 심링크로 유지한다 (ADR-002) |
| 데이터 스키마 변경 | context.md 프론트매터 유지. 새 파일 `specs/.init-project`(도입 표식, 내용 `mode=team` 또는 `mode=local`) 추가 |

## 접근 방식

저장소 루트를 마켓플레이스이자 플러그인(`"source": "."`)으로 만든다. Phase 1 검증에서 루트 배치가 실패하면 `plugin/` 하위 디렉터리로 바꾼다.
먼저 동작을 바꾸지 않는 파일 이동(structural)을 하고, 그다음 플러그인 등록·훅 동작·setup을 테스트 우선으로 추가한다.
setup은 스킬이 결정적 스크립트(`skills/setup/setup.sh team|local`)를 호출하는 구조로 만든다. 그래야 bootstrap처럼 임시 프로젝트에서 회귀 테스트할 수 있다.
스타터 저장소는 자기 훅 등록을 `.claude/settings.json`에서 제거하고 `claude --plugin-dir .`로 개발한다 (R7). 스타터에도 도입 표식을 두고, CLAUDE.md의 `@AGENTS.md` import는 일반 안내 문장으로 바꿔 정책이 중복 주입되지 않게 한다.

기각한 대안:
- 정책 주입 여부를 "CLAUDE.md가 AGENTS.md를 import하는지"로 판단 — 파싱이 깨지기 쉽다.
- 스타터 저장소가 `.claude/settings.json`과 플러그인 양쪽에 훅을 등록 — R7 위반, 등록 이중 관리.
- setup을 스킬 지시문만으로 구현 — 결과가 실행마다 달라질 수 있고 R4의 `git status` 검증을 자동화할 수 없다.

## 단계 (Phases)

- [ ] **Phase 1: 플랫폼 검증 (저장소 변경 없음)** → 검증: 스크래치 디렉터리의 시험 플러그인에서 아래 다섯 가지 결과를 context.md에 기록
  - 루트에 CLAUDE.md·`.claude-plugin/plugin.json`·`marketplace.json`(`source: "."`)이 함께 있을 때 `claude plugin validate`가 통과하는지
  - `--plugin-dir`로 SessionStart 훅이 실행되고 `CLAUDE_PLUGIN_ROOT`·`CLAUDE_PLUGIN_DATA`·`CLAUDE_PROJECT_DIR`가 설정되는지
  - 플러그인 스킬에서 같은 디렉터리의 양식 파일을 참조할 수 있는지 (skill base directory 안내)
  - `--scope local` 설치가 `.claude/settings.local.json`만 쓰고 그 파일이 git에 나타나지 않는지
  - 마켓플레이스 태그 ref(`#ref`) 등록이 되는지
- [ ] **Phase 2: 구조 이동 (structural)** → 검증: 이동 전후 `bash tests/hooks/run.sh`·`bash tests/bootstrap/run.sh` 통과, 기존 서브모듈 경로(호환 심링크) 유지
- [ ] **Phase 3: 플러그인 등록** → 검증: `claude plugin validate .` 통과, `--plugin-dir .` 세션에서 스킬 세 개와 훅 네 개가 각 1회 동작 (R1, R7)
- [ ] **Phase 4: 훅 동작 변경 (테스트 우선)** → 검증: 표식 유무별 SessionStart 출력, 주입 문자열 10,000자 이하, 로컬 모드 커밋 리마인더 미출력, 상태 파일 경로 격리 테스트 통과 (R2, R5)
- [ ] **Phase 5: setup 스킬** → 검증: `tests/setup/run.sh`에서 팀 모드 생성·보존, 로컬 모드 `git status` 깨끗함, 재실행 멱등 (R3, R4)
- [ ] **Phase 6: 문서·전환 안내** → 검증: 상대 링크·경로 대조, AGENTS.md·스킬·양식에 소비 프로젝트 `specs/_templates/`를 전제하는 문구 없음, bootstrap 폐지 예고 출력 (R6, R8)
- [ ] **Phase 7: 종단 검증과 완료 처리** → 검증: 임시 git 프로젝트에서 팀·로컬 설치 시나리오 수동 확인, 전체 검증 명령 통과, context 완료 처리 후 아카이브

## 리스크와 대응

- 루트 플러그인 배치가 validate에서 실패하거나 CLAUDE.md 경고가 오류로 바뀜 → Phase 1에서 확인하고 `plugin/` 하위 디렉터리 배치로 전환한다. 정책 원본(AGENTS.md)은 루트에 두고 훅이 상대 경로로 읽는다.
- 기존 서브모듈 소비 프로젝트가 `git submodule update --remote` 후 경로가 깨짐 → `.claude/hooks`, `.claude/skills/<name>`, `specs/_templates` 호환 심링크를 전환 기간 동안 유지하고 tests/bootstrap으로 확인한다. 되돌리려면 이동 커밋을 revert한다.
- 스타터 저장소에서 호환 심링크(`.claude/skills/*`) 때문에 `/feature`와 `/init-project:feature`가 함께 보임 → 전환 기간의 알려진 중복으로 README에 적고, bootstrap 제거 때 같이 정리한다.
- AGENTS.md가 늘어 주입 한도를 넘음 → 길이 테스트가 8,000자에서 실패하도록 해 ADR-002 재검토 조건을 자동으로 알린다. 한도를 넘으면 훅은 정책 대신 원본 경로 안내를 주입하고 stderr에 경고한다.
- 개발자가 `--plugin-dir` 없이 스타터에서 작업해 정책·훅이 빠짐 → CLAUDE.md와 CONVENTIONS.md에 개발 실행 명령을 명시한다.
- 사용자 범위로 설치된 플러그인과 `--plugin-dir`가 동시에 켜져 훅이 두 번 실행됨 → CONVENTIONS.md에 개발 시 설치본 비활성화 방법을 적는다.

## 실행 근거와 승인 상태

- 사용자 요청 범위·실행 근거: 2026-10-09 "권장안대로 승인, plan이랑 tasks 작성해줘"
- 승인 필요 여부·이유: 배포 모델 변경(AGENTS.md §1.2). ADR-002와 Q1~Q3 권장안으로 승인됨
- 승인받은 사항: 이 plan의 Phase 1~7. 호환 심링크를 통한 전환 기간 유지, 스타터 CLAUDE.md의 `@AGENTS.md` import 제거, AGENTS.md의 경로 문구 수정(권한·승인 정책 변경 아님) 포함
- 사용자 지정 검토 지점: 없음
- 보류 범위·재개 조건: bootstrap·호환 심링크 실제 제거는 이번 범위 밖이다. 알려진 서브모듈 소비 프로젝트가 모두 전환되면 별도 작업으로 진행한다. 마켓플레이스 태그 생성과 push는 외부 행위이므로 실행 직전에 사용자 권한을 확인한다
