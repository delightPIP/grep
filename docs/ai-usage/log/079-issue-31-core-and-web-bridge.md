# 2026-11-26 · #31 B 갈래: Swift 코어 피처와 웹 wasm 브리지

- 작성자: Kiseok
- 이슈·PR: #31
- 커밋: 6044f1d(코어), 웹 브리지는 이 항목과 같은 커밋

> **요약** 개발자가 `feat/31-core` 브랜치 확인과 핸드오프의 남은 작업 1·2번 진행을 요청했다. AI는 로그인·터미널 피처와 앱 루트를 Swift 코어에 구현하고, wasm 브리지와 어댑터를 붙여 브라우저에서 로그인 화면부터 터미널·로그아웃까지 도는 것을 확인했다. 개발자는 단계마다 진행을 지시했고, 로그인 모듈은 임시 구현으로 확인하는 데 그쳤다.

## 사용 도구

Claude Code(Fable 5.2). 스킬 `docs:ai-usage`, `core-dev:commit-rules`. 읽기 전용 리뷰 서브에이전트 3건(Sonnet). 앱 내장 브라우저, swift.org 툴체인 6.4.2와 Swift SDK `swift-6.4.2-RELEASE_wasm`, Vitest

## 요청

- `feat/31-core` 브랜치 확인
- 핸드오프 남은 작업 1번(피처 구현과 앱 루트) 시작
- `web/.env.local`에 넣을 Supabase 공개 값 전달
- 테스트에 뷰가 있는 이유, Uber RIBs 테스트 방식과의 차이, 구현한 타입 목록 질문
- 남은 작업 2번(웹 wasm 브리지) 진행
- 5173 포트를 쓰던 다른 프로젝트 개발 서버 종료
- AI 활용 로그를 넣고 코어와 웹을 나눠 커밋

## AI 산출물

- 코어: `LoggedOut`·`LoggedIn` 피처(Sources·Testing·Tests), `GrepAppRoot`(App), `GrepCoreTesting`(가짜 `AuthService`·`HTTPTransport`), `core/Package.swift` 타깃 추가
- 계약 타깃에 새 파일 추가: `LoggedOutBuildable.swift`, `LoggedInBuildable.swift`(Dependency·Listener·Buildable), `InteractorTask.swift`(`startTask`). 기존 계약 파일은 고치지 않음
- 웹: `web/Package.swift`, `web/Sources/`(피처 웹 화면, `@JS` 브리지, `FetchHTTPTransport`, `JSAuthService`), `web/support/bridge-state.ts`와 테스트, 피처별 `adapter.tsx`, `web/app.ts`
- 임시 파일: `web/support/temp-views.tsx`, `web/support/dev-auth-service.ts`(C 갈래 병합 때 교체)
- 정책에 없어 AI가 정한 동작: 401 `unauthorized`는 만료로 보지 않음(핸드오프 문구대로), 빈 줄 엔터 무시, `로그아웃 모든기기`는 없는 명령, 영문 명령 대소문자 구분
- `AbortSignal.any`·`timeout`으로 10초 무응답 판정(COM-010, 08 6절 14번). 두 API가 없는 브라우저에서는 시간 제한 없이 보냄

## 사람의 판단

- 1번을 시작하라고 지시했고, 결과 보고 뒤 2번 진행을 지시했다.
- `web/.env.local` 값을 직접 전달했다.
- 다른 프로젝트 개발 서버를 끄라고 지시했다.
- AI가 제안한 커밋 두 개 구성과 임시 파일 포함을 그대로 받았고, AI 활용 로그를 넣으라고 정했다.
- 계약 타깃에 파일을 추가한 것, 위 "AI가 정한 동작" 네 가지, COM-009 규칙 3·4와의 차이는 AI가 보고했고 개발자가 따로 결정하지 않았다.

## 검증

- `cd core && swift test`: 35개 통과
- 코어 `GrepAppRoot` 타깃 wasm 빌드: 통과
- `swift package --swift-sdk swift-6.4.2-RELEASE_wasm js`: 통과(`GrepWeb.wasm`)
- `cd web && npm test`: 11개 통과. `npm run build`: 통과
- 브라우저: 로그인 화면 표시 → 버튼 → 터미널 화면과 `GET /me` 요청 → `logout`·`찻기 결제`가 없는 명령으로 출력 → `signout` → `✓ 로그아웃됨` 로그인 화면
- 읽기 전용 리뷰 3건(코어 코드·동시성, 코어 정책 대조, 웹 브리지): CRITICAL·HIGH 없음. MEDIUM 3건 반영(아래 "AI의 오류와 정정")

## 검증하지 못한 것

1. 실제 Supabase 로그인. C 갈래의 `auth/supabase-auth.ts`가 없어 임시 모듈로 바로 성공시켰다.
2. `/me` 응답과 만료 경로의 브라우저 동작. 서버를 띄우지 않아 연결 거부로 끝났다. 자료 수 표시와 치던 줄 되살리기는 Swift 테스트로만 확인했다.
3. 한글 IME 조합 입력. 입력줄이 Swift를 왕복해 다시 그려지는데 실제 IME로 쳐 보지 않았다.
4. `AbortSignal.any`가 없는 브라우저에서의 동작. 코드 경로만 넣었다.
5. 만료 뒤 다른 계정으로 로그인하면 치던 줄이 되살아난다(COM-009 규칙 3과 다름). `AuthService` 계약에 계정 식별이 없어 고치지 않았다.
6. 만료 때 되살리는 것은 치던 줄뿐이고 출력 기록은 버린다(COM-009 규칙 4와 다름). 핸드오프는 치던 줄만 요구했다.
7. 계약 타깃에 파일을 추가한 사실을 #31에 알리지 않았다.

## AI의 오류와 정정

1. 화면이 떼어진 뒤 늦게 온 `/me` 응답을 그렸다. 테스트가 잡았고 `await` 뒤에 취소 확인을 넣었다.
2. `/me`를 기다리는 중에 로그아웃하면 만료 알림이 뜰 수 있었다. 리뷰가 찾았고 실패하는 테스트를 먼저 쓴 뒤 고쳤다.
3. LoggedOut의 "떼어진 뒤 알리지 않음" 테스트가 응답을 보내지 않아 구현을 검증하지 못했다. 리뷰가 찾았고 떼어진 뒤 성공 응답을 보내도록 고쳤다.
4. `AbortSignal.any`가 없는 브라우저에서 wasm이 멈추는 코드를 썼다. 리뷰가 찾았고 없으면 취소 신호만 쓰도록 고쳤다. 고치는 중 첫 시도는 컴파일에 실패했고 두 번째에 통과했다.
5. Xcode 기본 `swift`로 wasm 빌드를 돌려 SDK 버전 불일치로 실패했다. swift.org 툴체인 6.4.2로 다시 돌렸다.
6. LoggedIn 피처는 구현 없이 테스트만 실패시키는 단계를 따로 돌리지 않고 테스트와 구현을 함께 썼다.

## 발견 사항

1. 5173 포트를 다른 프로젝트의 개발 서버가 쓰고 있어 첫 확인은 다른 포트에서 했다. 이 프로젝트는 OAuth 때문에 5173 고정이다.
2. `docs:ai-usage` 스킬은 초안 승인 뒤 파일을 쓰라고 하지만, 개발자가 로그를 넣고 커밋하라고 지시해 초안 확인 없이 썼다.
3. `core-dev:commit-rules` 스킬은 `.githooks`가 없으면 훅을 설치하라고 하지만, 개발자가 요청하지 않아 설치하지 않았다.

## 근거 링크

- 커밋 6044f1d(코어)
- 이슈 #31
