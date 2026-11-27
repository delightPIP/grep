# 2026-11-27 · #60 최근 목록·번호 조회 서버 API(W1)

- 작성자: Kiseok
- 이슈·PR: #60 (PR 없음, 브랜치 `feat/60-server`)
- 커밋: 6d8a443

> **요약** AI가 갈래 핸드오프를 복원해 `GET /items`(최근 목록, 커서)와 `GET /items/status`(번호로 찾기)를 테스트 먼저 쓰는 순서로 구현했다. 사람은 커밋·푸시 시점과 PR을 아직 열지 않기로 정했다.

## 사용 도구

Claude Code(Claude Opus 5.5). gradle, git. 스킬: core-dev:handoff(recall), core-dev:commit-rules, docs:ai-usage.

## 요청

`.handoff-latest.md`로 이전 세션 상태를 복원해 #60 서버 작업을 이어 달라는 요청. 이어서 "문제없으면 푸시까지만", 그 뒤 핸드오프 파일 삭제와 이 기록, 푸시를 요청.

## AI 산출물

- `BrowseItemsController.kt`: `GET /items`(`cursor`, `limit` 1~50 기본 10), `GET /items/status?numbers=`. 쿼리 값을 문자열로 받아 직접 검사하고 틀리면 400 `invalid_request`
- `BrowseItemsService.kt`: 한 건 더 읽어 다음 쪽 여부를 정함. 번호 조회는 중복 번호를 한 번으로 보고(ARC-001 값) 요청 순서대로 `items`, 없거나 휴지통·다른 사용자 번호는 `missing`
- `JdbcItemRepository.kt`: `findActive`, `findActiveByNumbers`. 번호 개수 제한이 없어 IN 목록 대신 배열 하나(`= ANY`)로 넘김
- 커서는 앞 쪽 마지막 자료 번호 문자열로 정함
- `BrowseItemsApiTest.kt` 9개, `ArchiveApiTestSupport.kt` 도우미(`listItems`, `getStatuses`, `saveLinks`)

## 사람의 판단

- AI 보고를 보고 커밋과 푸시만 하고 PR은 열지 않기로 정함
- 푸시 전에 `.handoff-latest.md`를 지우고 이 기록을 남기라고 지시

## 검증

- 새 테스트 9개가 구현 전에 모두 실패하는 것을 확인한 뒤 구현해 통과
- `./gradlew test` 서버 전체 통과(로컬, Docker)
- CI는 PR을 열지 않아 돌지 않음. 레포에 `.githooks/`가 없어 커밋·푸시 훅 검사도 없음

## 검증하지 못한 것

1. 번호를 수천 개 넘게 보내는 `GET /items/status` 요청은 테스트하지 않음
2. CI(server·core·web Wasm·docs) 결과

## AI의 오류와 정정

1. 테스트에서 JSON 배열을 Kotlin `listOf`로 비교하게 써서, 응답이 계약대로인데도 "but was null"로 실패했다. 응답 본문을 찍어 `{"items":[],"missing":[1]}`임을 확인하고 Hamcrest `contains`로 바꿨다

## 근거 링크

#60, 커밋 6d8a443
