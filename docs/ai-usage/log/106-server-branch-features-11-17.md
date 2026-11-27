# 2026-11-28 · 서버 갈래 W1: 묶음·자세히 보기·찾아두기·가져오기·자동 묶음·뜻 찾기

- 작성자: @carti1108
- 이슈·PR: #121 #131 #134 #127 #137 #128 #154(절반), #124(대기), 이 기록을 담은 PR
- 커밋: ea9b421 ab5c6b8 cd67e09 f129ece c800ea3 ec1b30f d20d94c

> **요약** 웹 피처 11~17의 서버 몫을 이슈마다 테스트를 먼저 쓰고 구현해 커밋했다. 계약 변경 6건은 통합 세션의 승인을 받아 넣었다. 뜻 찾기 거리 기준은 실제 Gemini 임베딩으로 쟀다. 사람은 #124를 미루고 #137부터 하기로 정했고, 임베딩 한도 임시값과 실측 방법을 승인했다.

## 사용 도구

Claude Code(CLI), Claude Opus 5.5, `core-dev:commit-rules`, `docs:ai-usage`, 세션 간 메시지(통합 세션 grep-5e), Docker(Testcontainers, `groonga/pgroonga:4.0.4-debian-17` + PGDG pgvector), Gradle, Swift 6.4.2(Windows), `gh`.

## 요청

핸드오프(`.handoff-latest.md`)를 읽고 #121부터 차례로 진행해 달라는 요청. 이슈마다 커밋·푸시하고, 계약 변경은 통합 세션에 먼저 묻는다.

## AI 산출물

- #121 묶음: `/bundles` 목록·보기·넣기·빼기·지우기, 이름 판정(`invalid_bundle_name` format·reserved, 대소문자 무시), 동시 넣기 한 번만, 휴지통 숨김, `POST /handoff`의 `bundle`·`removedCount`, 여는 줄 `묶음="<이름>"`. 오류 코드 `invalid_bundle_name`(400)·`not_in_bundle`(404)
- #131 자세히 보기: `GET /items/{number}`, 처리 워커가 읽은 본문을 남기는 V5(`body_text`·`body_length`·`body_from_image`), 시드·샘플 본문 채움, 원본·미리보기 서명 GET URL(10분)
- #134 찾아두기: `/saved-searches` 조회·저장·삭제(공백 정리, 1~40자, 건수 다시 셈), 앱 `찾기`와 같은 `#태그` 해석, `SearchPage.isSavedSearch`
- #127 가져오기: Netscape 북마크 HTML 파싱(jsoup), 앞 200건·`overLimit`, 같은 링크 건너뜀, 뒤에서 진행, 가져온 자료는 `열기`·`넘기기` 때 처리 작업을 한 번만 만듦
- #137 자동 묶음: `GET /groups`(형식·출처·날짜·태그), `GET /items`의 `kind`·`source`·`tag`
- #128 뜻 찾기: V6(pgvector, `embedding vector(768)`), 임베딩 워커(Gemini `gemini-embedding-001`, 하루 50번 임시, 실패 1시간 뒤), 0건일 때 `SearchPage.related` 최대 3건, 라이브 측정 테스트 `GeminiEmbedderLiveTest`, ADR-BCK-016 '값' 절
- #154: `빼기 6`·`비우기`·`remove`·`clear`에 `고르기 빼기 6` 등을 제안(코어)
- 통합 세션에 보낸 계약 변경 요청·알림, 정책 공백 두 건(영구 삭제 건수, 빈 묶음 넘기기) 정리

## 사람의 판단

- 통합 세션(사람이 운영하는 다른 세션)이 승인·요청한 계약 변경: V5 본문 열, `ItemDetail.url`, `ItemDetail.bodyLength` nullable, `SearchPage.isSavedSearch`, `SearchPage.related`, V6
- `removedCount`는 휴지통 자료만 세고, 빈 묶음 넘기기는 200으로 두는 AI 안을 받아들였다("ㅇㅇ")
- #124는 OAuth 실험 환경이 준비될 때까지 미루고 #137부터 한다("b")
- 하루 임베딩 한도 임시 50번, 거리 실측 때 메인 체크아웃 `.env`를 실행할 때만 읽기를 승인했다
- #154의 남은 절반(빼기용 예시 문구)은 렌더러 변경이 필요해 M 갈래로 넘기기로 통합 세션이 정했다. 이후 `core/`는 건드리지 않는다

## 검증

- 이슈마다 `cd server && ./gradlew test bootJar`(Docker) 전체를 돌려 실패 0을 확인했다. 마지막 실행 기준 테스트 클래스 37개
- 뜻 찾기 거리: `GeminiEmbedderLiveTest`로 실제 Gemini를 불러 데모 시드 34건과 검색어 8개를 쟀다. 관련 검색어 1위 거리 0.240~0.323, 무관 검색어 1위 거리 0.392~0.434였고, 기준을 0.35로 정했다
- #154: `cd core && swift test` 전체 통과(Windows Swift 6.4.2)
- `bash Scripts/check-docs.sh` 통과(ADR 수정 뒤)
- 코드 리뷰 에이전트는 돌리지 않았다

## 검증하지 못한 것

1. 실제 Supabase에 V4~V6을 적용하지 않았다. 운영에서 V6이 `CREATE EXTENSION vector`를 부를 수 있는지 확인하지 않았다
2. 웹·iOS·Android 화면에서 새 API를 불러 보는 실측은 하지 않았다
3. 가져오기는 서버 메모리 작업이라 도는 중에 서버가 내려가면 `running`으로 남는다(코드에 한계로 적음)
4. 거리 기준은 지어낸 시드 34건으로만 쟀다. 관련·무관 간격이 0.07 정도로 좁다
5. 하루 임베딩 무료 한도를 AI Studio에서 확인하지 않았다. 검색어 임베딩 호출은 한도에 넣지 않았다
6. 코드 리뷰 에이전트 검토를 하지 않았다

## AI의 오류와 정정

1. #134를 푸시할 때 `origin/main`에 새 커밋이 있는 것을 보고도 리베이스 없이 올렸다. 곧바로 리베이스하고, 원격이 직전 푸시 그대로인지 확인하는 lease를 걸어 강제 푸시했다. #128 때도 같은 방식으로 올렸다
2. 처음에는 파이썬 치환이 맞지 않은 것을 확인하지 않아 `Handoff.compose` 시그니처 변경이 빠진 채 컴파일했다. 컴파일 오류로 알아채고 고쳤다
3. 테스트 쪽 실수 세 건: 이름 길이 픽스처(16자를 20자로 셈), JsonPath의 문자열 `length()` 사용, 워커 테스트 조회 SQL에 열 추가가 빠짐. 테스트 실패로 알아채고 고쳤다
4. 테스트 DB 이미지 빌드에서 Apache Arrow 저장소 서명 오류로 `apt-get update`가 실패했다. 컨테이너 안에서 원인을 확인한 뒤 빌드 때 그 저장소만 뺐다

## 발견 사항

1. pgroonga 데비안 이미지 안의 Apache Arrow apt 저장소는 서명 키가 맞지 않아, 이미지 위에 패키지를 설치하려면 그 목록을 빼야 한다

## 근거 링크

ea9b421(#121), ab5c6b8(#131), cd67e09(#134), f129ece(#127), c800ea3(#137), ec1b30f(#128), d20d94c(#154 절반). PR은 아직 없음.
