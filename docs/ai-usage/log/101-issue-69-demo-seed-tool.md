# 2026-11-27 · #69 데모 시드 도구

- 작성자: @carti1108
- 이슈·PR: #69
- 커밋: 없음(커밋 전)

> **요약** W2 갈래(`feat/69-seed`)에서 `./gradlew seedDemo -Pemail=…`로 지정한 계정에 `db/seed/demo/seed.json` 34건을 넣는 도구를 만들었다. 요약·태그·찾기 본문은 미리 만든 값을 그대로 넣고 처리 작업을 만들지 않아 워커·하루 한도와 겹치지 않는다. 사람은 핸드오프로 범위와 막을 조건(첫 로그인 전, 이미 자료가 있는 계정)을 정했다.

## 사용 도구

Claude Code(CLI), Claude Opus 5.5, `docs:ai-usage`.

## 요청

- 핸드오프(`.handoff-latest.md`)대로 #69 진행: 이메일로 계정을 받아 34건을 S번호 순서로 넣고, 날짜는 실행일 기준, 파일 20개는 `ObjectStorage` 포트로 올리기
- `item_jobs`에 `queued` 작업을 만들지 않기, 이미 자료가 있는 계정은 거부

## AI 산출물

- `DemoSeedService`(도메인), `JdbcDemoSeedRepository`(어댑터), `DemoSeedMain`(실행 진입점), Gradle `seedDemo` 작업
- 계정 찾기: `users`에 이메일이 없어 Supabase `auth.users.id`(토큰 sub)를 `users.external_id`와 잇고 로그인 방식(기본 google)으로 하나를 고름
- 번호 발급은 `users.last_item_number` 증가와 INSERT를 한 문장(ARC-001). 사용자 행을 잠근 뒤 `last_item_number > 0`이면 거부. 실패하면 올린 원본을 지움
- `ObjectStorage.put` 추가(S3 `putObject`, 테스트 가짜는 있던 `put`에 `override`)
- `seed.json`: S07을 `ready`에서 `blocked`/`no_text`로, S33에 `login_required`를 적음. 워커(`ProcessingWorker`)와 넘길 글(`Handoff.missingReason`)이 글자 없는 이미지를 `blocked`/`no_text`로 다뤄야 `(요약 없음: 이미지에 글자 없음)`이 나오기 때문
- `db/seed/demo/README.md`에 실행 방법
- 테스트 5건(`DemoSeedServiceTest`): 34건 S번호·날짜·상태·원본·`찾기 텀블러` 8건·`찾기 텀블러 캠페인` 4건, 자료 있는 계정 거부, 첫 로그인 전, 다른 로그인 방식만 있음, 시드 뒤 워커가 집지 않음

## 사람의 판단

- 핸드오프에서 범위, 계정 인자(이메일), 거부 조건, 워커와 겹치지 않게 할 것을 정함
- `#69 진행해`로 구현을 지시

## 검증

- `cd server && ./gradlew test --tests "*DemoSeedServiceTest*"`: 5건 통과
- `./gradlew seedDemo`(이메일 없음): 스프링을 띄우기 전에 안내하고 종료 코드 64로 멈춤
- `cd server && ./gradlew test`: 135건 중 134건 통과, 1건 건너뜀(Gemini 실제 호출, 키 없음)
- `bash Scripts/check-docs.sh`: 통과

## 검증하지 못한 것

1. 실제 Supabase DB·Storage에 넣기. 계정 B가 생긴 뒤 통합 세션이 실행하고 demo-seed 5절 장면표를 실측한다
2. 실제 Supabase `auth.users`의 `email` 칸 이름·대소문자. 테스트는 같은 모양의 표를 만들어 돌렸다

## AI의 오류와 정정

1. 테스트에서 `created_at`을 `OffsetDateTime`으로 읽어 형 변환 오류가 났다. `JdbcClient` 행 맵은 `Timestamp`를 주므로 그것으로 바꿨다

## 근거 링크

없음(커밋 전)
