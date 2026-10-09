# 변경 이력

## v0.1.0 — 2026-10-09: Claude Code 플러그인 배포

init-project를 이제 **Claude Code 플러그인**으로 설치한다. 서브모듈 추가와 bootstrap 실행이 필요 없고, 저장소에 아무것도 남기지 않고 혼자만 쓸 수도 있다. 결정 배경은 [ADR-002](docs/adr/002-plugin-distribution.md)에 있다.

### 무엇이 달라졌나

| 이전 (서브모듈) | 이제 (플러그인) |
|---|---|
| `git submodule add` 후 `bootstrap.sh` 실행 | 플러그인 설치 명령 두 줄 |
| `.gitmodules`·심링크·훅 설정·`.gitignore` 수정이 저장소에 커밋됨 | 팀 공유를 원할 때만 커밋, 로컬 전용은 커밋 없음 |
| `git submodule update --remote`로 업데이트 | `claude plugin update`로 업데이트 |
| 스킬 이름 `/feature` | `/init-project:feature` |

### 설치

자세한 절차는 [README의 도입](README.md#도입)을 따른다.

- **팀과 함께 쓰기:** `--scope project`로 설치한 뒤 `/init-project:setup`을 실행하고, 생성된 `.claude/settings.json`·`docs/`·`specs/`를 커밋한다. 팀원은 폴더를 신뢰한 뒤 설치 명령만 각자 실행한다.
- **나만 쓰기:** `--scope local`로 설치한 뒤 `/init-project:setup`을 실행한다. 플러그인 설정은 `.claude/settings.local.json`에만 기록되고, 생성 문서와 `specs/`는 `.git/info/exclude`에 등록된다. `.gitignore`는 건드리지 않으며 `git status`에 아무것도 나타나지 않는다.
- **여러 프로젝트에서 쓰기:** 사용자 범위로 한 번 설치하면 모든 프로젝트에 로드되지만, `/init-project:setup`을 실행한 프로젝트에서만 동작한다.

### 새 기능

- **공통 정책 자동 적용:** 세션 시작 시 AGENTS.md(자율성·승인·검증 원칙)를 Claude에게 전달한다. 프로젝트에 CLAUDE.md를 만들 필요가 없다.
- **`/init-project:setup`:** 프로젝트 도입 스킬. docs 양식·`specs/`·도입 표식(`specs/.init-project`)을 만들고, 플러그인 설치 위치로 팀·로컬 모드를 판단한다. 기존 파일은 덮어쓰지 않는다.
- **진행 중 작업 안내와 문서 동기화 리마인더:** 진행 중 기능 문서를 세션 시작 때 알리고, 코드 수정·커밋 후 tasks·context 갱신을 상기시킨다. 로컬 모드에서는 문서가 커밋되지 않으므로 커밋 리마인더를 띄우지 않는다.
- **하위 폴더 지원:** 하위 폴더에서 Claude Code를 시작해도 프로젝트 루트의 도입 표식을 찾아 동작한다.
- 기존 스킬 `/init-project:feature`·`/init-project:handoff`·`/init-project:learn`은 플러그인에 포함된 문서 양식을 사용한다.

### 기존 서브모듈 사용자

- 바로 바꾸지 않아도 된다. 서브모듈을 업데이트해도 기존 경로(`init-project/.claude/hooks`, `.claude/skills/*`, `specs/_templates`)가 호환 심링크로 계속 동작한다.
- 전환은 [README의 플러그인으로 전환](README.md#플러그인으로-전환) 절차를 따른다. 플러그인 설치 → `/init-project:setup`(기존 docs·specs 보존) → 서브모듈 연결 정리 순서다. 서브모듈 연결을 남겨 두면 훅과 정책이 두 번 실행된다.
- 서브모듈 방식은 전환 기간이 끝나면 지원을 종료한다.

### 알아 둘 점

- Claude Code 전용이다. Codex 등 다른 에이전트는 지원하지 않는다.
- 훅은 `bash`와 `jq`가 필요하다.
- 메모리(claude-memory-layer)는 플러그인에 포함되지 않는다. 필요하면 별도로 설치·등록한다.
- 커밋 리마인더는 `git -c … commit`처럼 옵션이 중간에 들어간 커밋 명령을 감지하지 못한다.
- 버전 고정(`justinbuzzni/init-project#init-project--v0.1.0`)은 첫 태그를 만든 뒤부터 쓸 수 있다.
