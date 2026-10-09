# init-project — Agentic 개발 스타터

Claude Code 플러그인으로 에이전트 공통 정책, 기능 문서 양식·스킬, 문서 동기화 리마인더 훅을 배포한다.

## 어디를 관리하나

| 필요 | 원본 |
|------|------|
| 자율성·명확화·승인·완료 정책 | [AGENTS.md](AGENTS.md) |
| 스타터 구조·소비 프로젝트 구조 작성 | [ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| 검증 명령·컨벤션 | [CONVENTIONS.md](docs/CONVENTIONS.md) |
| 배포 결정 | [ADR-002](docs/adr/002-plugin-distribution.md) (ADR-001 대체) |
| 버전별 변경 사항 | [CHANGELOG.md](CHANGELOG.md) |
| 진행 중 기능 | specs/[feature]/ |
| 문서 양식·완료 기록 | skills/feature/templates/, specs/_archive/ |
| 계획·인수인계·회고·도입 절차 | skills/ |
| 훅 연결·구현 | hooks/hooks.json, hooks/ |
| 플러그인·마켓플레이스 매니페스트 | .claude-plugin/ |

정책을 바꾸면 스킬·템플릿·훅 안내의 일관성을 함께 검토한다. 실제 중단·승인 기준은 AGENTS.md가 원본이다.

## 도입

이 저장소가 마켓플레이스이자 플러그인이다. Claude Code에서 아래 명령을 프로젝트 루트에서 실행한다.
`claude plugin …` 명령은 세션 안에서 `/plugin …`으로도 실행할 수 있다.

### 팀 공유

```bash
claude plugin marketplace add justinbuzzni/init-project --scope project
claude plugin install init-project@init-project --scope project
```

새 세션에서 `/init-project:setup`을 실행하고 팀 모드를 고른다. docs 양식, `specs/`, 도입 표식 `specs/.init-project`가 생긴다.
`.claude/settings.json`(마켓플레이스·플러그인 등록), `docs/`, `specs/`를 커밋한다.
팀원은 폴더를 신뢰한 뒤 각자 `claude plugin install init-project@init-project --scope project`를 실행한다.

### 로컬 전용

저장소에 아무것도 커밋하지 않고 개인적으로만 쓴다.

```bash
claude plugin marketplace add justinbuzzni/init-project --scope local
claude plugin install init-project@init-project --scope local
```

새 세션에서 `/init-project:setup`을 실행하고 로컬 모드를 고른다.
플러그인 등록은 `.claude/settings.local.json`에만 기록된다. setup은 생성물과 `specs/`를 `.git/info/exclude`에 등록하고 `.gitignore`는 수정하지 않는다. 결과적으로 `git status`에 아무것도 나타나지 않는다.

### 사용자 범위 (여러 프로젝트)

```
/plugin install init-project --marketplace justinbuzzni/init-project
```

한 번 설치하면 모든 프로젝트에서 로드되지만, `/init-project:setup`으로 도입 표식을 만든 프로젝트에서만 동작한다.

### 버전 고정

마켓플레이스를 태그로 등록하면 그 버전에 고정된다. 태그는 `claude plugin tag`가 `init-project--v<version>` 형식으로 만든다.

```bash
claude plugin marketplace add justinbuzzni/init-project#init-project--v0.1.0 --scope project
```

고정하지 않으면 `claude plugin update init-project@init-project`로 최신 버전을 받는다.

### 도입 후

1. docs/ARCHITECTURE.md·CONVENTIONS.md를 실제 구조·검증 명령으로 채운다.
2. 훅은 bash와 jq를 사용한다. 두 명령의 가용성을 확인한다.
3. 공통 정책은 세션 시작 시 주입된다. 도입 표식이 없는 프로젝트에서는 플러그인이 아무것도 출력하지 않는다.
4. 메모리(claude-memory-layer)는 선택 사항이며 플러그인에 포함되지 않는다. 쓰려면 해당 패키지를 설치·등록한다.

## 서브모듈 방식 (전환 기간만 지원)

ADR-002로 플러그인 방식으로 대체됐다. 기존 서브모듈 소비 프로젝트는 서브모듈을 갱신해도 옛 경로(`init-project/.claude/hooks`, `.claude/skills/*`, `specs/_templates`)가 호환 심링크로 계속 동작한다.
새 프로젝트는 플러그인 방식을 쓴다. bootstrap(`bash init-project/scripts/bootstrap.sh`)은 전환이 끝나면 제거한다.

### 플러그인으로 전환

1. 위 [팀 공유](#팀-공유) 절차로 플러그인을 설치하고 `/init-project:setup`(팀 모드)을 실행한다. 기존 docs·specs는 보존되고 도입 표식만 추가된다.
2. 서브모듈 연결을 제거한다. 남겨 두면 훅과 정책이 두 번 실행된다.
   - `.claude/settings.json`에서 `init-project/hooks/`(또는 `init-project/.claude/hooks/`)를 가리키는 훅 항목
   - `.claude/skills/feature`·`handoff`·`learn` 심링크와 `specs/_templates` 심링크
   - CLAUDE.md의 `@init-project/AGENTS.md` 줄과 AGENTS.md의 서브모듈 안내 문장 (정책은 플러그인이 주입한다)
   - 서브모듈: `git submodule deinit -f init-project && git rm init-project`
3. `.mcp.json`은 메모리를 계속 쓸 때만 남긴다.
4. 새 세션에서 `[INIT-PROJECT POLICY]`가 한 번만 주입되는지 확인하고 커밋한다.

## 스킬

- [/init-project:setup](skills/setup/SKILL.md): 팀·로컬 모드로 프로젝트에 도입.
- [/init-project:feature](skills/feature/SKILL.md): 기능 계획 문서 준비와 기존 승인 확인.
- [/init-project:handoff](skills/handoff/SKILL.md): 변경을 보존하며 검증·승인 상태와 재개 지점 기록.
- [/init-project:learn](skills/learn/SKILL.md): 검증된 교훈 정리와 승인받을 승격안 준비.

일반 대화에도 공통 정책을 적용한다. 스킬은 선택적인 실행 보조다. 서브모듈 방식에서는 접두사 없이(`/feature` 등) 호출한다.

## 훅

플러그인 훅은 도입 표식 `specs/.init-project`가 있는 프로젝트에서만 동작한다. 하위 디렉터리에서 세션을 시작해도 git 루트까지 올라가며 표식을 찾는다.
SessionStart는 공통 정책(AGENTS.md)을 주입한다. 합계가 10,000자를 넘으면 본문 대신 원본 경로를 안내한다.
SessionStart는 등록된 CML의 버전이 2.4.0 이상이면 `mem-lesson-get` 우선, 이전 버전이면 기존 회수 방법과 업그레이드를 안내하며 등록·버전을 확인할 수 없으면 CML 안내를 생략한다.
훅은 차단·승인 집행기가 아니다. 상태 보고와 승인 판단은 [AGENTS.md](AGENTS.md) §2.7을 따른다.
훅이 출력하지 않아도 진행 기능이나 동기화 필요가 없다고 단정하지 않는다.

| 이벤트 | 훅 | 역할 |
|--------|-----|------|
| SessionStart | `session_start.sh` | 공통 정책 주입, 진행 기능과 CML 버전별 교훈 회수 안내 |
| PostToolUse (Edit/Write) | `posttool_edit.sh` | 편집 후 문서 동기화 리마인더 |
| PostToolUse (Bash) | `posttool_commit.sh` | 커밋의 문서 누락 리마인더 (specs가 git 제외 대상이면 침묵) |
| Stop | `stop_lesson_reminder.sh` | 턴을 연장하지 않는 사용자 표시용 교훈 저장 리마인더 |

## 개발

이 저장소에서는 `claude --plugin-dir .`로 실행한다. 사용자 범위로 init-project를 설치했다면 비활성화해 중복 실행을 막는다.
전환 기간에는 호환 심링크 때문에 `/feature`와 `/init-project:feature`가 함께 보인다.
검증 명령은 [CONVENTIONS.md](docs/CONVENTIONS.md)의 스타터 저장소 전용 표를 따른다 (`tests/hooks`, `tests/bootstrap`, `tests/setup`, `claude plugin validate .`).
테스트는 `INIT_PROJECT_CLAUDE_SETTINGS`와 `INIT_PROJECT_HOOK_TMPDIR`로 임시 설정·마커 경로를 주입하며 실제 사용자 설정을 읽거나 쓰지 않는다.
