# 개발 팀 설정

`po-workflow` 플러그인의 dev 스킬(`dev-flow`, `dev-requirements-intake`, `dev-technical-design`)이 읽는 그렙의 팀 정보다. 스킬은 이 파일에 없는 값을 추측하지 않고 "팀 설정 미입력"으로 둔다. 값마다 근거를 붙였고, 근거를 찾지 못한 칸은 `{{}}`로 비워 두었다.

- 마지막 확인: 2026-11-26 / 확인한 사람: AI 초안, PO·개발자 확인 전 / 다시 볼 조건: 플랫폼 순서, 결정권, 리뷰 방식, 다음 관문이 바뀔 때

## 제품과 범위

- 제품·단계: 기획 → 개발 → 발표까지 하는 프로젝트. 실사용자 출시와 베타는 없다
- 다음 관문: 데모·발표. 개발자가 데모 필수 세 가지를 11/29까지 보장한다고 확정했다([PRD](planning/PRD.md) 규모 절)
- 해당 없는 단계·문서: S11 모니터링·유지관리, 스토어·데스크톱 배포, 단계적 출시, 온콜, 장애 보고서. 이유: 실사용자 출시가 범위 밖. 대신 데모 점검을 S10 자리에 둔다
- 무료 운영: [COM-005](policies/common/COM-005-free-tier-only.md)

## 플랫폼과 스택

- 플랫폼: 네 플랫폼(iOS·Android·데스크톱·웹)이 후보이고, 데모는 웹이 먼저다([PRD](planning/PRD.md) 가정 표). 플랫폼 순서는 개발 판단이다
- 서버: Kotlin, Spring Boot([ADR-BCK-003](adr/backend/ADR-BCK-003-kotlin-spring-boot.md)), 기능별 모듈러 모놀리스([ADR-BCK-004](adr/backend/ADR-BCK-004-modular-monolith-hexagonal.md))
- 데이터·인증·파일: Supabase, 전용 기능에 묶이지 않음([ADR-BCK-006](adr/backend/ADR-BCK-006-supabase-without-lock-in.md))
- 웹·데스크톱: React 뷰 + Swift 공유 코어, 데스크톱은 Tauri([ADR-WEB-007](adr/web/ADR-WEB-007-react-views-swift-core-tauri.md))
- API 방식과 계약 원본: OpenAPI 계약, 서버가 최종 판정([ADR-0001](adr/ADR-0001-api-contract-first.md)). 계약 파일 위치: `api/openapi.yaml`([ADR-0010](adr/ADR-0010-monorepo-top-level-folders.md))
- 앱 저장소: 이 저장소([ADR-0010](adr/ADR-0010-monorepo-top-level-folders.md)). 배포: [ADR-0011](adr/ADR-0011-free-tier-deploy-portable.md)
- 버전을 고정한 파일: `{{}}`(구현 시작 뒤 Gradle·SwiftPM·npm 잠금 파일 위치를 적는다)

## 역할과 결정권

- 역할: 2인 팀. PO 1명, 개발자 1명([PRD](planning/PRD.md) 규모 절)
- 범위·정책·수용 기준 승인: PO
- 기술 채택·플랫폼 순서·구현 방식: 개발자. 개발 판단은 개발 안을 기본으로 하고 PO 질문으로 남기지 않는다
- 우선순위·일정: 데모 범위와 빼는 순서는 PO가 요청하고 개발자가 확정했다([PRD](planning/PRD.md) 규모 절). 그 밖의 경우: `{{}}`
- 병합: `{{}}`
- 데모 진행 판단: `{{}}`
- 법무·개인정보: `{{}}`

## 원본 위치

- 요청·이슈: GitHub 이슈와 PR
- 정책·결정 기록: [docs/policies/](policies/README.md). 정책이 서비스 동작·값·문구의 유일한 근거다. 새 결정 기록 문서를 따로 만들지 않는다
- 열린 질문: 정책 영역별 `open-questions.md`
- ADR: [docs/adr/](adr/README.md). 절차는 `docs:adr-manager`. 개발자 확인 전 ADR은 상태를 "제안"으로 둔다(예: ADR-IOS-009)
- AI 활용 기록: [docs/ai-usage/log/](ai-usage/log/README.md)
- 디자인: [디자인 검토](planning/design-review-2026-11-26.md), [모바일·데스크톱 디자인](planning/design-mobile-desktop.md)
- 문서 이름 대응: 결정 기록 → 정책 문서와 영역 `CHANGELOG.md`, 기능 명세 → 정책 + [PRD](planning/PRD.md)(위치 색인은 [SPEC](SPEC.md)), 개발 전달 형식 → [handoff-format](planning/handoff-format.md)

## 개발 규칙

- 브랜치·커밋·PR: 루트 `AGENTS.md`의 Freshness & Rebase Gate. 커밋 메시지는 `종류: 요약` 형식(git 기록 기준)
- 문서를 고친 뒤: `bash Scripts/check-docs.sh`
- 리뷰 스킬: `{{}}` / 필수 승인 수: `{{}}`
- 필수 검사 명령: `cd server && ./gradlew test && cd ../core && swift test && cd ../web && npm test`(Docker 필요, 루트 README 테스트 절)
- 테스트 작성(개발자 결정 2026-11-26, 모든 플랫폼): 테스트 메서드 안을 `// given`, `// when`, `// then` 주석으로 나누고, 이름은 그 순서대로 `~했을때_~하면_~하는지`로 짓는다. `_`는 given·when·then 경계 두 곳에만 쓰고, 각 부분 안의 낱말은 띄우지 않고 붙인다(예: `로그인창이열려있을때_버튼을다시누르면_창을하나더띄우지않는지`)
- 작은 개선 상한: `{{}}` / 긴급 기준: `{{}}`
- 비밀키: API 키·토큰은 `.env` 같은 저장소 밖에서만 관리하고 커밋하지 않는다. LLM·Supabase 비밀 키는 클라이언트에 두지 않는다. 확인한 사람: AI 초안(2026-11-26 PO 승인), 개발자 확인 대기

## 데이터와 AI 사용

- 입력 금지: 실명·연락처, 키·토큰, 실제 사용자 자료. 외부 LLM으로 보내는 자료의 범위는 [COM-002](policies/common/COM-002-external-llm-data.md)
- 에이전트 권한: 저장소 읽기 가능 / 명령·테스트 실행 `{{}}` / 이슈 접근 가능(`gh`)
