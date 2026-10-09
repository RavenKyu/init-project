# CLAUDE.md

공통 운영 정책은 AGENTS.md가 원본이다. 이 파일에 복사하지 않는다.

@AGENTS.md

## Claude Code 연결

- 리마인더 훅은 플러그인 hooks/hooks.json이 연결한다. 이 저장소에서는 `claude --plugin-dir .`로 실행해야 훅과 플러그인 스킬이 로드된다. [ACTIVE FEATURES]와 [SPEC SYNC]의 해석은 AGENTS.md §2.7을 따른다.
- 훅은 bash와 jq를 사용한다. 수정할 때 docs/CONVENTIONS.md의 검증 절차를 따른다.
