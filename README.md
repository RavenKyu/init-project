# init-project — Agentic 개발 스타터

에이전트 공통 지침, 프로젝트 문서 양식, 선택적 스킬과 Claude Code 리마인더 훅을 배포한다.

## 어디를 관리하나

| 필요 | 원본 |
|------|------|
| 자율성·명확화·승인·완료 정책 | [AGENTS.md](AGENTS.md) |
| 스타터 구조·소비 프로젝트 구조 작성 | [ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| 검증 명령·컨벤션 | [CONVENTIONS.md](docs/CONVENTIONS.md) |
| 배포 결정 | [ADR-001](docs/adr/001-submodule-distribution.md) |
| 진행 중 기능 | specs/[feature]/ |
| 문서 양식·완료 기록 | skills/feature/templates/, specs/_archive/ |
| 계획·인수인계·회고 절차 | skills/ |
| 훅 연결·구현 | hooks/hooks.json, hooks/ |

정책을 바꾸면 스킬·템플릿·훅 안내의 일관성을 함께 검토한다. 실제 중단·승인 기준은 AGENTS.md가 원본이다.

## 도입

### 서브모듈

소비 프로젝트 루트에서 실행한다.

```bash
git submodule add <repo-url> init-project
bash init-project/scripts/bootstrap.sh
```

부트스트랩은 기존 파일을 보존하며 다음을 생성한다.

| 산출물 | 방식 | 업데이트 시 주의 |
|--------|------|------------------|
| AGENTS.md·CLAUDE.md | 공통 지침 포인터 생성 | 기존 파일은 자동 병합하지 않음 |
| docs/ARCHITECTURE.md·CONVENTIONS.md | 복사 | 소비 프로젝트 내용으로 작성·유지 |
| specs/_templates·.claude/skills/* | 심링크 | 스타터 버전 변경 시 함께 바뀜 |
| .claude/settings.json | hooks/hooks.json의 훅 경로를 서브모듈로 치환 | 기존 설정은 수동 병합 |
| .mcp.json | 없으면 복사 | 실제 MCP 가용성은 별도 확인 |

기본 디렉터리명 init-project 사용을 권장한다. 다른 배치는 스크립트의 상대 심링크 경로를 검증해야 한다.
업데이트는 소비 프로젝트별로 스타터 변경을 검토한 뒤 해당 서브모듈 버전을 갱신한다. 여러 프로젝트가 자동으로 갱신되는 것은 아니다.

### 복사형

저장소를 새 프로젝트로 복사하거나 clone한 뒤 remote를 변경한다. 이후 스타터 변경은 필요한 파일을 직접 반영한다.

### 도입 후

1. docs의 **소비 프로젝트 작성 영역**을 실제 구조·검증 명령으로 채운다. 스타터 설명을 애플리케이션 구조로 간주하지 않는다.
2. Claude Code 훅을 사용할 경우 bash와 jq 가용성을 확인한다.
3. 메모리를 사용할 경우 해당 패키지 설치·연결 상태를 확인한다. .mcp.json 존재만으로 인증·실행·자동 기록을 보장하지 않는다.
4. [CONVENTIONS.md](docs/CONVENTIONS.md)에 따라 연결과 검증 명령을 확인한다.

## 스킬

- [/feature](skills/feature/SKILL.md): 기능 계획 문서 준비와 기존 승인 확인.
- [/handoff](skills/handoff/SKILL.md): 변경을 보존하며 검증·승인 상태와 재개 지점 기록.
- [/learn](skills/learn/SKILL.md): 검증된 교훈 정리와 승인받을 승격안 준비.

일반 대화에도 공통 정책을 적용한다. 스킬은 선택적인 실행 보조다.

## 훅

SessionStart는 등록된 CML의 버전이 2.4.0 이상이면 `mem-lesson-get` 우선, 이전 버전이면 기존 회수 방법과 업그레이드를 안내하며 등록·버전을 확인할 수 없으면 CML 안내를 생략한다.
훅은 차단·승인 집행기가 아니다. 상태 보고와 승인 판단은 [AGENTS.md](AGENTS.md) §2.7을 따른다.
훅이 출력하지 않아도 진행 기능이나 동기화 필요가 없다고 단정하지 않는다.

| 이벤트 | 훅 | 역할 |
|--------|-----|------|
| SessionStart | `session_start.sh` | 진행 기능과 CML 버전별 교훈 회수 안내 |
| PostToolUse (Edit/Write) | `posttool_edit.sh` | 편집 후 문서 동기화 리마인더 |
| PostToolUse (Bash) | `posttool_commit.sh` | 커밋의 문서 누락 리마인더 |
| Stop | `stop_lesson_reminder.sh` | 턴을 연장하지 않는 사용자 표시용 교훈 저장 리마인더 |

훅 수정 검증은 `bash tests/hooks/run.sh`로 실행한다.
테스트는 `INIT_PROJECT_CLAUDE_SETTINGS`와 `INIT_PROJECT_HOOK_TMPDIR`로 임시 설정·마커 경로를 주입하며 실제 사용자 설정을 읽거나 쓰지 않는다.
기존 소비 프로젝트는 서브모듈 갱신과 gitlink 커밋 후 Stop 등록 여부를 확인한다. bootstrap은 기존 settings.json을 덮어쓰지 않으므로 누락된 등록은 해당 프로젝트에서 별도로 병합해야 한다.
