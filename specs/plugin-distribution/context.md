---
기능: plugin-distribution
상태: 진행중(Phase 4)
마지막 갱신: 2026-10-09
---

# 플러그인 배포 Context

## 현재 상태

사용자가 ADR-002와 Q1~Q3 권장안을 승인했다(2026-10-09). [plan.md](plan.md)·[tasks.md](tasks.md)를 작성했고 Phase 1~3을 마쳤다. 훅은 `hooks/`, 스킬은 `skills/`, 양식은 `skills/feature/templates/`에 있고 옛 경로는 호환 심링크다. 저장소 루트가 플러그인·마켓플레이스이며(`.claude-plugin/`), 훅 원본은 `hooks/hooks.json`이다. 스타터의 `.claude/settings.json`은 삭제했고 개발은 `claude --plugin-dir .`로 한다. 다음 작업은 T8(Phase 4 실패 테스트)이다.

## 핵심 결정 로그

- [2026-10-09] 플러그인을 저장소 루트(`"source": "."`)에 배치 / 이유: T1에서 validate 통과, 정책 원본 AGENTS.md를 옮길 필요 없음 / 기각: `plugin/` 하위 디렉터리 / 재검토 조건: 루트 CLAUDE.md 경고가 오류로 바뀌거나 CI에서 `--strict`가 필요해질 때.
- [2026-10-09] 스타터 저장소도 도입 표식을 두고 `--plugin-dir .`로 개발, CLAUDE.md의 `@AGENTS.md` import 제거 / 이유: 정책·훅 중복 방지(R2·R7) / 기각: 스타터만 settings.json 훅 유지(이중 등록) / 재검토 조건: Phase 1에서 `--plugin-dir` 동작이 기대와 다를 때.
- [2026-10-09] 전환 기간 동안 `.claude/hooks`·`.claude/skills/*`·`specs/_templates` 호환 심링크 유지 / 이유: 기존 서브모듈 소비 프로젝트가 업데이트 후 깨지지 않게 / 재검토 조건: 알려진 소비 프로젝트 전환 완료 시 제거.
- [2026-10-09] Claude Code만 지원 / 이유: 사용자 결정 / 기각: Codex 병행 지원(훅 입력 형식 차이로 어댑터 필요, 로컬 모드 정책 전달이 기존 AGENTS.md와 충돌) / 재검토 조건: 다른 에이전트 지원 요구 시 → ADR-002.

## T1 플랫폼 검증 결과 (Claude Code 2.1.295, 2026-10-09)

- `claude plugin validate .`: 루트에 CLAUDE.md·`plugin.json`·`marketplace.json`(`source: "."`)을 함께 두어도 통과. 경고는 author·marketplace description 누락과 "루트 CLAUDE.md는 로드되지 않음" 세 가지. `--strict`는 CLAUDE.md 경고 때문에 실패하므로 검증 명령은 비-strict로 한다.
- 훅 환경: `CLAUDE_PLUGIN_ROOT`(디렉터리 소스는 원본 경로 그대로), `CLAUDE_PLUGIN_DATA`(`~/.claude/plugins/data/init-project-<marketplace>`, `--plugin-dir`는 `init-project-inline`, 자동 생성), `CLAUDE_PROJECT_DIR` 모두 설정됨. 공백 경로에서 따옴표 명령 정상.
- 주의: 하위 디렉터리에서 세션을 시작하면 `CLAUDE_PROJECT_DIR`와 cwd가 그 하위 디렉터리다. 표식·specs 탐색은 상위로 올라가야 한다 (T9 반영).
- 스킬: `/init-project:feature|handoff|learn`으로 로드됨. SKILL.md 본문의 `${CLAUDE_PLUGIN_ROOT}`와 `${CLAUDE_SKILL_DIR}`가 실제 경로로 치환됨 (T16 반영).
- local scope: `marketplace add --scope local`과 `install --scope local`은 `.claude/settings.local.json`(extraKnownMarketplaces·enabledPlugins)만 쓴다. 전역 git exclude의 `**/.claude/settings.local.json`으로 `git status`에 나타나지 않음. 로컬에 설치한 플러그인의 SessionStart 주입 동작 확인.
- 태그 ref: 로컬 경로와 `file://` 소스는 `#ref`를 받지 않아 확인하지 못했다. 원격(owner/repo, https)에서만 가능하므로 push 승인 후 T20에서 확인. `claude plugin tag`가 `{name}--v{version}` 태그를 만든다.
- 한 줄 설치 `/plugin install init-project --marketplace <owner>/<repo>`가 2.1.275 이상에서 지원됨 (validate 안내).
- 검증에 쓴 시험 마켓플레이스·설치·플러그인 데이터 디렉터리는 모두 제거했다.

## 시도했으나 실패한 접근

- 로컬 git 저장소를 `file://…#v0.1.0`·`경로#v0.1.0`으로 마켓플레이스 등록 → "Invalid marketplace source format"/"Path does not exist". 태그 고정 확인은 원격 저장소로 해야 한다.

## 발견된 문제 / 열린 질문

- 태그 ref 고정 동작은 원격 push 후에만 확인 가능 (T20, 외부 행위 승인 필요).
- `posttool_edit.sh`의 마커 경로가 `TMPDIR`를 직접 쓰는 문제는 상태 경로 변경과 함께 T10에서 처리한다.

## 다음 세션 시작점

1. tasks.md T8: `tests/hooks/run.sh`에 표식 유무·정책 주입·10,000자 한도·AGENTS.md 8,000자 상한 케이스를 먼저 추가해 실패를 확인한다.
2. T9 구현 시 하위 디렉터리 시작(T1 결과)과 `INIT_PROJECT_HOOK_TMPDIR` 우선순위(테스트 주입 > `CLAUDE_PLUGIN_DATA` > TMPDIR)를 지킨다.

## 파일 맵

- `specs/plugin-distribution/spec.md` — 요구사항 R1~R8, 결정된 질문 Q1~Q3
- `specs/plugin-distribution/plan.md`, `tasks.md` — Phase 1~7, T1~T21
- `docs/adr/002-plugin-distribution.md` — 배포 모델 결정 (승인됨, ADR-001 대체)
- `hooks/`, `skills/`, `skills/feature/templates/` — 이동된 원본 (Phase 2)
- `.claude/hooks`, `.claude/skills/*`, `specs/_templates` — 기존 소비 프로젝트용 호환 심링크
- `.claude-plugin/plugin.json`, `marketplace.json` — 플러그인·마켓플레이스 매니페스트 (`source: "."`)
- `hooks/hooks.json` — 훅 등록 원본. bootstrap이 `${CLAUDE_PLUGIN_ROOT}`를 서브모듈 경로로 바꿔 소비 프로젝트 settings.json을 만든다
- `scripts/bootstrap.sh` — 원본 경로로 링크·훅 경로 생성

## 검증·승인 상태

- 실행한 검증과 결과: 문서 링크·`git diff --check` 통과. T1 플랫폼 검증 결과는 위 절 참조. Phase 2 이동 전후 `bash tests/hooks/run.sh`·`bash tests/bootstrap/run.sh` 통과, 옛 소비 프로젝트 링크(`init-project/.claude/skills/*`, `specs/_templates`, `.claude/hooks/*.sh`)와 새 bootstrap 링크 해석 수동 확인. Phase 3: `claude plugin validate .` 통과(경고는 루트 CLAUDE.md, README 설치 줄), `--plugin-dir .` 세션에서 SessionStart 메시지 1회·플러그인 스킬 3개 로드 확인, 훅·bootstrap 테스트(플러그인 hooks.json 공백 경로 실행 포함) 통과.
- 미실행 검증과 이유: 훅·플러그인 검증은 코드 변경이 없어 해당 없음.
- 승인된 범위·근거: plan.md Phase 1~7 (2026-10-09 "권장안대로 승인").
- 남은 승인 대상·재개 조건: bootstrap·호환 심링크 제거(전환 완료 후 별도), 태그 생성·push(실행 직전 확인).
