# 2026-11-27 · #61 찾기 서버 API(W1)

- 작성자: Kiseok
- 이슈·PR: #61 (PR 없음, 브랜치 `feat/61-server`)
- 커밋: 없음(커밋 전)

> **요약** AI가 `GET /items/search`를 PGroonga 검색 어댑터 하나로 구현하고, 데모 시드 34건으로 `찾기 텀블러` 8건·`텀블러 캠페인` 4건을 Testcontainers 테스트로 확인했다. 사람은 핸드오프의 다음 작업 순서를 승인하고, 문제가 없으면 푸시까지 하라고 지시했다.

## 사용 도구

Claude Code(Claude Opus 5.5). gradle, Docker(Testcontainers, PGroonga 이미지), git, gh. 스킬: core-dev:commit-rules, docs:ai-usage.

## 요청

핸드오프 확인, 리베이스 후 1단계(openapi 응답 모양 확인과 컨트롤러·서비스·포트 추가) 시작, 문제 없으면 푸시까지.

## AI 산출물

- `domain/ItemSearch.kt`: 검색 포트 `ItemSearch`, `SearchQuery`(낱말·태그), `SearchHit`, `SearchPage`, `MatchedIn`
- `adapters/postgres/PgroongaItemSearch.kt`: 검색 SQL이 있는 유일한 곳. 낱말마다 `search_text &@ ?`(AND), 태그는 소문자로 정확히 일치(배열 포함), 전체 건수 쿼리, `matchedIn`(제목 → 출처 → 요약 → 태그 → 이미지 파일이면 이미지 속 글자, 그 밖은 본문)
- `BrowseItemsService.search`, `BrowseItemsController`의 `GET /items/search`. 커서·쪽 크기 검사를 목록과 같이 쓰도록 함수로 뺌
- `ItemSummaryResponse.of`에 `matchedIn` 인자 추가. `JdbcItemRepository`의 행 매퍼·열 목록을 `internal`로
- 테스트: `SearchItemsApiTest` 8개, 시드 적재 `SearchFixtures.kt`

## 사람의 판단

- 핸드오프 요약과 다음 작업(리베이스 후 1단계 시작)을 그대로 승인
- 구현 결과 보고 뒤 문제가 없으면 커밋·푸시하라고 지시. AI 로그 초안 승인 절차는 이 지시로 갈음함

## 검증

- 구현 전 `SearchItemsApiTest` 8개 실패 확인(엔드포인트 없음 404 등). 처음 실행에서 픽스처 버그 2건(Jackson 3 타입 추론, 링크 자료에 `file_format`을 넣음)을 고친 뒤 다시 실패 원인을 확인
- 구현 후 `SearchItemsApiTest` 8개, `BrowseItemsApiTest` 통과
- 서버 `./gradlew test` 전체 91개 통과(Docker)
- `server/gradlew` 실행 권한 100755 확인

## 검증하지 못한 것

1. 실제 데이터에서는 `search_text`를 채우는 코드가 아직 없다(처리 워커 W2 몫). 테스트는 제목·URL·요약 두 가지·본문·태그를 이어 붙여 직접 넣었다. 워커가 만드는 값이 다르면 결과가 달라질 수 있다
2. `items_search_idx`를 실제로 타는지 EXPLAIN으로 보지 않았다
3. 시점 필터(F22)는 openapi 계약에 매개변수가 없어 넣지 않았다
4. 낱말이 제목과 요약에 나뉘어 맞으면 `matchedIn`은 앞선 한 곳만 준다
5. CI는 PR을 열지 않아 돌지 않음

## AI의 오류와 정정

1. 처음 어댑터를 Spring 이름 매개변수(`:word0`)로 짰는데, Spring이 PGroonga 연산자 `&@`의 `&`를 매개변수 기호로 읽어 `No value supplied for the SQL parameter '@'`로 실패했다. 어댑터를 위치 매개변수(`?`)로 바꿔 해결하고 이유를 클래스 주석에 남겼다
2. 컨트롤러 정규식을 `Regex("\s+")`로 써 컴파일 오류가 났고 `"\\s+"`로 고쳤다

## 근거 링크

#61, #56(계약), 없음(커밋 전)
