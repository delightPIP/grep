# 2026-11-26 · #31 통합본 실제 로그인 확인(Mac)

- 작성자: Kiseok
- 이슈·PR: #31
- 커밋: 없음(커밋 전)

> **요약** 개발자가 `feat/demo-express` 통합본의 실제 로그인 확인을 요청했다. AI는 wasm 빌드, 서버·웹 실행, 실패 원인 추적, 로그인 뒤 화면·요청·DB 확인을 맡았고, 로그인과 팝업 조작은 개발자가 했다. Google 로그인이 처음에 실패했고 원인은 Supabase의 Google 제공자 설정이었다. 개발자가 고친 뒤 확인 항목 11개 중 9개가 통과했다.

## 사용 도구

Claude Code(Fable 5.2). 스킬 `docs:ai-usage`. 앱 내장 브라우저(Chromium 계열), Safari(개발자가 직접 조작), swift.org 툴체인 6.4.2, Homebrew `openjdk@21`, `curl`, PostgreSQL JDBC 드라이버로 읽기 전용 조회, `Scripts/check-docs.sh`

## 요청

- `feat/demo-express` 브랜치와 4단계 핸드오프 확인, 실제 로그인 확인
- `server/.env`를 채운 뒤 서버 실행
- "로그인하고 돌아오니 권한 거부가 뜬다"는 문제의 원인 확인
- 로그아웃 방법, 로그아웃 뒤 바로 다시 로그인되는 이유 질문
- Safari로 다시 열기, 결과 기록

## AI 산출물

- 실행: wasm 빌드, `npm ci`, `npm run build`(통합 뒤 첫 `tsc --noEmit`), 웹 5173, 서버 8080
- `web/.env.local`은 앞 작업에서 만든 것을 그대로 썼고, `server/.env`는 예시를 복사해 `SUPABASE_URL`만 채웠다. DB 접속 값 세 개는 개발자가 넣었다(값은 AI가 출력하지 않음)
- 서버 실행 방법: `gradlew`에 실행 권한이 없어 `sh ./gradlew`로 실행
- Flyway 기준선: 이번 실행에만 환경변수 `SPRING_FLYWAY_BASELINE_ON_MIGRATE=true`, `SPRING_FLYWAY_BASELINE_VERSION=0`. 실제 DB에 `flyway_schema_history`(기준선 0, V1)와 `users`, `sessions`가 생김
- 원인 추적: 페이지에 관찰 코드를 임시로 심어 콜백의 오류 코드·설명과 `code` 유무를 읽음(`code` 값은 읽지 않음). 결과는 `server_error`, `unexpected_failure`, `Unable to exchange external code`
- 문서: `08-po-dev-handoff.md` 5절 T-01 실행 결과와 변경 이력, 이 로그

## 사람의 판단

- DB 접속 값을 직접 넣고 서버를 띄우라고 지시했다.
- Supabase 대시보드에서 Google Client Secret을 다시 넣었다.
- Safari로 다시 확인하기로 정하고, 남은 항목을 직접 확인해 "다 됨"이라고 알렸다.
- Flyway 기준선을 환경변수로 준 것은 AI가 먼저 실행하고 뒤에 보고했다. 개발자가 따로 승인하지 않았다.
- `prompt=select_account`를 넣을지, 기준선 설정을 `application.properties`에 넣을지는 AI가 물었고 개발자가 정하지 않았다.

## 검증

핸드오프 4단계 표의 번호를 따른다.

| # | 확인할 것 | 결과 | 확인 방법 |
|---|---|---|---|
| 1 | 로그인 전 화면, 입력 불가 | 통과 | AI, 앱 내장 브라우저. 입력줄 없음 |
| 2 | Google 로그인 → `자료 0`, `GET /me` 200 | 통과 | AI, 앱 내장 브라우저(화면·네트워크 기록). 개발자, Safari |
| 3 | 팝업 닫기 → `✗ 로그인 취소됨` | 통과 | 개발자 보고, Safari |
| 4 | 동의 화면 취소 → `✗ 로그인 취소됨` | 통과 | 개발자 보고, Safari |
| 5 | 로그인 창 하나만 | 통과 | 개발자 보고, Safari |
| 6 | `로그아웃` → GitHub 계정 전환 → 이전 출력 없음 | 통과 | 개발자 보고, Safari |
| 7 | `logout` → `✗ 없는 명령: logout` | 통과 | AI, 앱 내장 브라우저 |
| 8 | 새로 고침 뒤 로그인 유지 | 통과 | AI, 앱 내장 브라우저. 로그인 화면 없이 터미널, `/me` 200 |
| 9 | `users`·`sessions` 행 | 통과 | AI, DB 읽기 전용 조회. google 1행, github 1행, 세션 2행(조회 시점) |
| 10 | 같은 이메일 두 방식의 계정 수 | 미확인 | 두 계정의 이메일이 같은지 확인하지 않음 |
| 11 | 계정 전환에 걸린 시간 | 미확인 | 재지 않음 |

- 서버: `GET /health` 200, 토큰 없는 `GET /me` 401 `unauthorized`, `http://localhost:5173` preflight 200
- 웹: `npm test` 54개 통과, `npm run build` 통과
- 한글 입력: 개발자가 Safari에서 `로그아웃`을 한글로 쳐서 됐다고 보고
- `bash Scripts/check-docs.sh`: 통과

## 검증하지 못한 것

1. 10번, 11번.
2. 3~6번과 한글 입력은 개발자 보고이고 AI가 화면을 보지 못했다. `✗ 로그인 취소됨`이 뜨기까지 걸린 시간은 재지 않았다.
3. Chrome에서의 3~6번. 앱 내장 브라우저에서는 Google 로그인이 남아 있어 팝업이 곧바로 닫혔다.
4. 로그인 만료 경로(30일 미사용, 90일 경과)의 브라우저 동작.
5. `app_metadata.provider`가 이번 로그인 방식인지 처음 가입한 방식인지(핸드오프 4절).
6. `자료 34`. 시드(#43) 뒤에 본다.

## AI의 오류와 정정

1. "Java가 없어 서버를 띄울 수 없다"고 보고했다. Homebrew에 `openjdk@21`이 있었고 PATH에만 없었다. 정정하고 그 JDK로 띄웠다.
2. 서버 기동을 기다리는 명령이 출력 버퍼링 때문에 끝나지 않았다. 서버는 이미 떠 있었고 `curl`로 직접 확인했다.
3. `./gradlew`가 권한 오류로 실패했다. `sh ./gradlew`로 다시 실행했다.

## 발견 사항

1. `server/gradlew`가 git에 `100644`로 들어가 있어 Mac·Linux에서 `./gradlew`가 실행되지 않는다. 핸드오프의 실행 명령이 그대로는 안 된다.
2. Supabase의 `public` 스키마에 `rls_auto_enable` 함수가 있어 Flyway가 기준선 없이 시작하지 않는다. 새 Supabase 프로젝트에서는 같은 문제가 다시 난다.
3. Supabase가 Google 코드 교환에 실패하면 화면에는 `✗ 로그인 실패: 권한 거부`로 나온다. 원인이 설정 오류여도 사용자 탓처럼 읽힌다.
4. `로그아웃`은 그렙 세션만 지운다. 브라우저에 Google 로그인이 남아 있으면 `Google로 계속`이 계정 선택 없이 바로 들어간다. 같은 방식의 다른 계정으로는 바꿀 수 없다.
5. 새로 고침하면 출력 기록이 사라진다(COM-009 규칙 1과 다름). 터미널 기록 저장은 T-18 범위다.
6. 5173 포트를 다른 프로젝트의 개발 서버가 쓰고 있어 개발자 지시로 종료했다.

## 근거 링크

- 이슈 #31
- 커밋: 없음(커밋 전)
