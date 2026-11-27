# 2026-11-27 · #62·#63·#67 넘기기 서버 갈래(번호 확인·넘길 글 조립·자료 수)

- 작성자: @carti1108
- 이슈·PR: #62, #63, #67, #84
- 커밋: ce2bb2c, 2e51494

> **요약** W1 서버 갈래(`feat/62-server`)에서 번호 확인(#62)이 이미 `GET /items/status`로 되는 것을 확인하고 같은 응답 테스트만 더했다. `POST /handoff`(#63)를 넘길 글 형식 그대로 만드는 함수 하나로 구현했고, `GET /me` 자료 수(#67)는 이미 구현·테스트되어 있어 고치지 않았다. 통합 PR(#84)에 ARC-004 구현 위치와 열린 질문 두 개를 더했다.

## 사용 도구

Claude Code(CLI), Claude Opus 5.5, `docs:policy-manager`, `docs:ai-usage`.

## 요청

- 갈래 핸드오프(`.handoff-latest.md`)를 확인하고 #62 → #63 → #67 순서로 진행
- 통합 PR #84에서 W1 몫으로 빠진 것을 찾아 더하기

## AI 산출물

- #62: 남의 자료에만 있는 번호와 없는 번호가 같은 본문을 주는지 테스트(`BrowseItemsApiTest`). 번호가 사용자별로 매겨져 구현은 고치지 않음
- #63: `HandoffComposer`(넘길 글 조립), `HandoffService`(고른 순서, 같은 번호는 한 번, 하나라도 없으면 `not_found`와 그 번호들), `HandoffController`, 저장소 조회 `findActiveForHandoff`, `LinkNormalizer.withoutTracking`(출처용 꼬리표만 뺀 주소)
- #63 테스트: handoff-format 예시와 글자까지 같고 442자인지, 상태별 요약 없음 이유, 직접 고친 요약 우선, 일부만 읽음 표시, 출처 표기, 닫는 태그·줄바꿈 바꾸기, 한국 날짜, API 404·400·같은 응답
- 가정: md·txt·docx 출처를 `파일(<형식>)`으로(04 질문 19), ready인데 요약 없는 자료는 `(요약 없음: 처리 실패)`
- #84에 더함: ARC-004 근거의 구현 위치, 자료 영역 열린 질문 두 줄(위 가정), 이 기록

## 사람의 판단

- 핸드오프의 순서(#62 → #63 → #67 → #59)를 그대로 진행하도록 승인
- 한국어로 답하라고 교정
- 통합 PR #84가 "62 PR"임을 확인하고, 빠진 문서 작업을 통합 브랜치에 직접 더하도록 결정
- ARC-004 구현 위치와 열린 질문 두 줄 변경안을 승인

## 검증

- `cd server && ./gradlew test`: `feat/62-server`에서 103건 통과
- `HandoffComposerTest`(7건), `HandoffApiTest`(4건), `BrowseItemsApiTest`(10건)를 따로 먼저 돌려 통과
- PR #84 CI(server·core·web·docs) 통과 확인
- `bash Scripts/check-docs.sh`: 통과(이번 문서 변경 뒤)

## 검증하지 못한 것

1. 앱에서 `넘기기`로 복사한 글을 실제 AI 도구(Claude·ChatGPT)에 붙여 넣어 자료를 지시로 오해하지 않는지(handoff-format 7절 리허설)
2. AI 도구 연결(MCP)이 같은 함수를 쓰는지. MCP는 아직 없다

## AI의 오류와 정정

1. 사용자 기억 규칙(답변은 한국어)이 있는데도 #62·#63 결과 보고를 영어로 했다. 사용자 교정 뒤 한국어로 다시 보고했다
2. `HandoffApiTest`에서 응답 글을 정규식으로 꺼내 `\"`를 풀지 않아 글자 수 비교가 실패했다. 서버가 아니라 테스트 문제였고 JsonPath로 바꿨다
3. #63은 테스트와 구현을 같은 단계에서 써서 실패하는 테스트를 먼저 확인하지 않았다
4. `feat/62-server`를 main 위로 리베이스한 뒤 원격 브랜치를 `--force-with-lease`로 덮어썼다(원격에 있던 것은 핸드오프 커밋 하나)
