---
기능: plugin-distribution
상태: 진행중(Phase 1)
마지막 갱신: 2026-10-09
---

# 플러그인 배포 Context

## 현재 상태

사용자가 ADR-002와 Q1~Q3 권장안을 승인했다(2026-10-09). [plan.md](plan.md)·[tasks.md](tasks.md)를 작성했고 ADR-001을 폐기됨으로 표시했다. 코드·훅 변경은 아직 없으며 다음 작업은 T1(플랫폼 검증)이다.

## 핵심 결정 로그

- [2026-10-09] 스타터 저장소도 도입 표식을 두고 `--plugin-dir .`로 개발, CLAUDE.md의 `@AGENTS.md` import 제거 / 이유: 정책·훅 중복 방지(R2·R7) / 기각: 스타터만 settings.json 훅 유지(이중 등록) / 재검토 조건: Phase 1에서 `--plugin-dir` 동작이 기대와 다를 때.
- [2026-10-09] 전환 기간 동안 `.claude/hooks`·`.claude/skills/*`·`specs/_templates` 호환 심링크 유지 / 이유: 기존 서브모듈 소비 프로젝트가 업데이트 후 깨지지 않게 / 재검토 조건: 알려진 소비 프로젝트 전환 완료 시 제거.
- [2026-10-09] Claude Code만 지원 / 이유: 사용자 결정 / 기각: Codex 병행 지원(훅 입력 형식 차이로 어댑터 필요, 로컬 모드 정책 전달이 기존 AGENTS.md와 충돌) / 재검토 조건: 다른 에이전트 지원 요구 시 → ADR-002.

## 시도했으나 실패한 접근

해당 없음.

## 발견된 문제 / 열린 질문

- 확인 필요: 저장소 루트에 plugin.json과 marketplace.json을 함께 두는 구성이 `claude plugin validate`를 통과하는지. CLAUDE.md가 플러그인 루트에 있으면 validate가 경고한다.
- `posttool_edit.sh`의 마커 경로가 `TMPDIR`를 직접 쓰는 문제는 상태 경로 변경과 함께 T10에서 처리한다.

## 다음 세션 시작점

1. tasks.md T1: 스크래치 디렉터리에서 시험 플러그인으로 루트 배치·훅 환경 변수·local scope를 검증하고 결과를 이 파일에 기록한다.
2. 저장소 파일 이동(T2)은 T1 결과로 배치가 확정된 뒤 시작한다.

## 파일 맵

- `specs/plugin-distribution/spec.md` — 요구사항 R1~R8, 결정된 질문 Q1~Q3
- `specs/plugin-distribution/plan.md`, `tasks.md` — Phase 1~7, T1~T21
- `docs/adr/002-plugin-distribution.md` — 배포 모델 결정 (승인됨, ADR-001 대체)
- `scripts/bootstrap.sh`, `.claude/hooks/`, `.claude/skills/` — 변경 대상 (미착수)

## 검증·승인 상태

- 실행한 검증과 결과: 상대 링크 존재와 `git diff --check` (작성 직후 확인).
- 미실행 검증과 이유: 훅·플러그인 검증은 코드 변경이 없어 해당 없음.
- 승인된 범위·근거: plan.md Phase 1~7 (2026-10-09 "권장안대로 승인").
- 남은 승인 대상·재개 조건: bootstrap·호환 심링크 제거(전환 완료 후 별도), 태그 생성·push(실행 직전 확인).
