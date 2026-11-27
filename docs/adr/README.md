# ADR (설계 결정 기록)

그렙에서 대안을 비교해 고른 설계·기술 결정을 남긴다. 기록·조회·대체 절차는 `docs:adr-manager` 스킬을 따른다.

## 번호 체계 (멀티 플랫폼)

- 여러 플랫폼에 걸친 공통 결정은 이 폴더에 `ADR-<네 자리 번호>-<영문-슬러그>.md`로 둔다. 번호는 프로젝트 전체 순번이다.
- 한 플랫폼에만 해당하는 결정은 플랫폼 폴더에 `ADR-<플랫폼 접두어>-<세 자리 번호>-<영문-슬러그>.md`로 둔다.
- 번호는 모든 ADR 폴더를 통틀어 겹치지 않고, 재사용하지 않는다.
- 새 ADR은 [ADR 틀](../templates/adr.md)을 복사해 쓰고, 아래 "ADR 목록" 표에 한 줄을 추가한다.

## 플랫폼과 접두어

| 접두어 | 플랫폼 | 폴더 |
|---|---|---|
| BCK | 백엔드 | `backend/` |
| WEB | 웹 | `web/` |
| IOS | iOS | `ios/` |
| AND | Android | `android/` |

플랫폼이 정해지면 이 표에 행을 추가하고(예: 웹 `WEB`, 백엔드 `BCK`) 같은 이름의 하위 폴더를 만든다.

## 작성 규칙

1. 채택한 ADR은 내용을 고치지 않는다. 결정이 바뀌면 새 ADR을 쓰고, 옛 ADR의 `- 상태:` 줄만 `대체됨 (→ 새 번호)`로 바꾼다.
2. "고려한 대안"과 기각 이유가 없으면 ADR로 쓰지 않는다.
3. 결과에는 얻는 것과 비용을 함께 쓴다.

## ADR 목록

| 번호 | 제목 | 상태 | 날짜 |
|---|---|---|---|
| [ADR-0001](ADR-0001-api-contract-first.md) | 프론트엔드와 백엔드는 OpenAPI 계약으로만 연결하고, 서비스 규칙은 서버가 최종 판정한다 | 채택 | 2026-11-25 |
| [ADR-BCK-002](backend/ADR-BCK-002-postgres-and-object-storage.md) | 자료와 작업 큐는 Postgres 하나에, 파일은 오브젝트 스토리지에 둔다 | 채택 | 2026-11-25 |
| [ADR-BCK-003](backend/ADR-BCK-003-kotlin-spring-boot.md) | 서버 언어는 Kotlin, 프레임워크는 Spring Boot로 한다 | 채택 | 2026-11-25 |
| [ADR-BCK-004](backend/ADR-BCK-004-modular-monolith-hexagonal.md) | 서버는 기능별 모듈러 모놀리스로 만들고, 모듈 안은 포트와 어댑터로 나눈다 | 채택 | 2026-11-25 |
| [ADR-BCK-005](backend/ADR-BCK-005-image-text-llm-vision.md) | 이미지 글자 읽기(F16)는 서버가 LLM 비전으로 하고, 앱이 기기에서 읽은 글자는 함께 받는다 | 채택 | 2026-11-25 |
| [ADR-BCK-006](backend/ADR-BCK-006-supabase-without-lock-in.md) | DB, 인증, 파일 저장소는 Supabase를 쓰고, Supabase 전용 기능에는 묶이지 않는다 | 채택 | 2026-11-25 |
| [ADR-WEB-007](web/ADR-WEB-007-react-views-swift-core-tauri.md) | 웹 클라이언트는 React 뷰와 carti-RIBs-Swift 공유 코어로 만들고, 데스크톱은 Tauri로 감싼다 | 채택 | 2026-11-25 |
| [ADR-BCK-008](backend/ADR-BCK-008-server-small-llm-summary.md) | 요약은 서버 처리 워커에서 소형 LLM으로 만들고, 북마크로 가져온 자료는 처음 열거나 넘길 때 만든다 | 일부 대체됨 (결정 4 → ADR-BCK-014, 결정 2 → ADR-BCK-017) | 2026-11-25 |
| [ADR-IOS-009](ios/ADR-IOS-009-share-sheet.md) | iOS에서 공유로 받기는 네이티브 공유 확장으로, 보내기는 시스템 공유 시트로 한다 | 채택 | 2026-11-25 |
| [ADR-AND-001](android/ADR-AND-001-share-intent-receiver.md) | Android에서 공유로 받기는 `ACTION_SEND` 인텐트 필터를 둔 투명 액티비티로 한다 | 채택 | 2026-11-28 |
| [ADR-0010](ADR-0010-monorepo-top-level-folders.md) | 앱 코드는 이 저장소에 두고 계약·서버·공유 코어·플랫폼별 앱을 최상위 폴더로 나눈다 | 채택 | 2026-11-26 |
| [ADR-0011](ADR-0011-free-tier-deploy-portable.md) | 데모 단계 배포는 Render 무료(서버)·Cloudflare Pages(웹)·Supabase로 하고, 옮기기 쉽게 만든다 | 채택 | 2026-11-26 |
| [ADR-WEB-012](web/ADR-WEB-012-popup-login-broadcast-channel.md) | 웹 로그인은 팝업으로 하고, 결과는 콜백 페이지가 BroadcastChannel로 넘긴다 | 대체됨 (→ ADR-WEB-013) | 2026-11-26 |
| [ADR-WEB-013](web/ADR-WEB-013-login-popup-close-as-cancel.md) | 웹 로그인 창 닫힘은 그렙 창이 포커스를 되찾는 것으로 알고, 바로 취소로 처리한다 | 채택 | 2026-11-26 |
| [ADR-BCK-014](backend/ADR-BCK-014-gemini-flash-free-tier.md) | 발표까지 요약·태그·글자 읽기 LLM은 Gemini Flash 무료 등급으로 한다 | 채택 | 2026-11-27 |
| [ADR-BCK-015](backend/ADR-BCK-015-mcp-oauth-authorization-server.md) | AI 도구 연결(MCP)은 그렙 서버가 OAuth 인가 서버가 되어 연결마다 토큰을 준다 | 채택 | 2026-11-27 |
| [ADR-BCK-016](backend/ADR-BCK-016-gemini-embedding-pgvector.md) | 뜻이 가까운 찾기는 Gemini 임베딩을 처리 워커에서 만들고 pgvector에 둔다 | 채택 | 2026-11-27 |
| [ADR-BCK-017](backend/ADR-BCK-017-imports-background-low-priority.md) | 가져온 자료도 백그라운드에서 요약하되, 직접 저장한 자료보다 뒤에 처리한다 | 채택 | 2026-11-28 |
| [ADR-0015](ADR-0015-mobile-feature-modules-per-issue.md) | iOS·Android 앱은 공유 코어의 피처마다 UI·Adapter·Example 모듈로 만들고, 웹 이슈가 끝날 때마다 짧은 브랜치로 따라간다 | 채택 | 2026-11-27 |
