# grep 에이전트 지침

문서 지도: [docs/README.md](docs/README.md)

## 작업 시작 전 최신화 및 PR 전 Rebase 강제 (Freshness & Rebase Gate)

- **작업 시작 전 (Pre-Work)**: 모든 코드·문서 작성 전 반드시 `git fetch origin main`으로 원격을 최신화한 뒤 `origin/main`에서 작업 브랜치를 분기하거나 그 위로 리베이스한다.
- **커밋 시점 최신성 유지**: 커밋 전에 `git pull --rebase origin main`으로 최신 상태를 유지한다. `.githooks/pre-commit`이 설치된 레포(`core-dev:commit-rules`가 설치)에서는 뒤처진 브랜치의 커밋이 차단된다.
- **PR 및 푸시 전 Rebase**: `.githooks/pre-push`가 설치된 레포(`core-dev:commit-rules` 또는 `/team-workflow:init`이 설치)에서는 미리베이스 푸시가 차단된다. 훅이 없어도 푸시 전 반드시 `git fetch origin main && git rebase origin/main`을 실행해 `origin/main` 위에 리베이스된 상태를 확보한다.

## 서비스 정책

- 서비스 동작·값·문구의 근거는 [docs/policies/](docs/policies/README.md)다. 정책과 다른 구현을 하지 않는다. 정책이 없거나 모호하면 영역의 `open-questions.md`에 적고 사용자에게 묻는다.
- 정책 조회·추가·수정·폐기는 `docs:policy-manager` 스킬을 따른다.

## 설계 결정 (ADR)

- 대안을 비교해 고른 설계·기술 결정은 [docs/adr/](docs/adr/README.md)에 남긴다. 채택한 ADR은 고치지 않고 새 ADR로 대체한다.
- 기록·조회는 `docs:adr-manager` 스킬을 따른다.

## AI 활용 기록

- AI 활용 내용은 `docs/ai-usage/log/`에 항목당 새 파일로 추가한다. 기존 항목 파일은 고치지 않고 `log/README.md` 목록 표에 한 줄을 추가한다. 형식은 `docs/ai-usage/README.md`를 따른다.
- 기록 절차는 `docs:ai-usage` 스킬을 따른다.

## 문서 검사

- 문서를 고치면 `bash Scripts/check-docs.sh`를 실행해 링크, 정책·ADR·로그 목록 표, 정책·ADR 번호 참조가 맞는지 확인한다. 위반이 있으면 고친 뒤에 커밋한다.
- 루트 `AGENTS.md`(및 호환용 `CLAUDE.md`)는 매 턴 컨텍스트에 포함되므로 작게 유지한다. 세부 도메인 규칙·릴리스 절차·아키텍처 결정은 `docs/README.md` 및 하위 문서에 두고 루트에는 링크만 남긴다.
