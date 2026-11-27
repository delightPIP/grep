# 2026-11-27 · #78 iOS 1단계 뼈대(Tuist·플랫폼 포트·로그인 화면) 구현

- 작성자: @carti1108
- 이슈·PR: #78
- 커밋: 없음(커밋 전)

> **요약** 이슈 #78의 1단계(Tuist 프로젝트·`core/` 로컬 SwiftPM 의존·플랫폼 포트 5종·앱 루트·`Features/LoggedOut` UI/Adapter/Example)를 구현하고, `iPhone 17` 시뮬레이터에서 실제 Google 소셜 로그인까지 확인했다. 사람이 시안 불일치를 지적하고 모바일 시안 M7 스크린샷을 제공해 풀블리드 로그인 화면으로 교정했다.

## 사용 도구

Antigravity, Gemini 4 Neon (Medium), `apple-dev:tuist-modularization`, `docs:ai-usage`, `core-dev:commit-rules`, Tuist 4.191.5, Xcode 27.0.

## 요청

- `feat/m0-ios` 브랜치 확인 후 워크트리 생성·`origin/main` 리베이스 및 이슈 #78 1단계(뼈대) 구현
- 기존 `web/.env.local` 환경값으로 시뮬레이터에서 실제 Google 로그인 확인
- 모바일 시안(M7)과 로그인 화면 대조·수정 및 PR 준비

## AI 산출물

- Tuist 매니페스트 및 설정: `ios/Tuist.swift`, `ios/Project.swift`, `ios/.gitignore`, `ios/README.md`
- 플랫폼 포트 5종(`GrepPlatform`) 및 단위 테스트(`GrepPlatformTests`, 17건): `URLSessionHTTPTransport`, `WebAuthService`(`ASWebAuthenticationSession` + PKCE + Keychain), `PasteboardClipboardPort`, `URLSessionFilePort`, `UserDefaultsHistoryStore`
- 앱 루트 및 로그인 피처: `ios/App/Sources/GrepIOSApp.swift`, `ios/Features/LoggedOut/{UI,Adapter,Example}`
- `origin/main`의 #77(`Terminal` 분리) 리베이스 반영(`FeatureTerminalInterface` 전환)

## 사람의 판단

- `feat/m0-ios` 1단계 구현과 `web/.env.local` 기반 시뮬레이터 실로그인 검증 진행 결정
- Supabase Redirect URLs에 `grep://auth-callback` 직접 등록 후 실제 Google 로그인 성공 확인
- "뷰 시안대로 한거 맞음?" 지적 및 모바일 시안(M1~M11) 스크린샷 제공으로 웹 카드형 UI를 모바일 M7 풀블리드 시안으로 교정 결정
- 1단계 상태로 우선 PR 준비 및 분할 커밋(옵션 A) 선택

## 검증

- `tuist test --no-selective-testing --device "iPhone 17"`: `GrepPlatformTests` 17/17 통과
- `xcodebuild build`: `Grep`, `FeatureLoggedOutExample` 스킴 빌드 통과
- `iPhone 17` 시뮬레이터에서 `web/.env.local` 값으로 Google OAuth 로그인 및 화면 전환 수동 확인
- `bash Scripts/check-docs.sh`: 통과

## 검증하지 못한 것

- GitHub 소셜 로그인 실서버 왕복(Google만 수동 확인)
- 2단계 화면(`Features/Terminal`, `Features/LoggedIn` 하단 탭)은 다음 작업으로 남김

## AI의 오류와 정정

- 초기 `LoggedOutView`를 웹 구현 코드와 텍스트 문서만 보고 작성해, 두더지 마스코트·배너 제목·모바일 풀블리드 구조를 놓쳤다. 사용자가 시안 차이를 지적하고 M7 스크린샷을 제공한 뒤 풀블리드 헤더·48px 마스코트·버튼 카드 구조로 수정했다.
- 내장 브라우저로 Claude Design 아티팩트 링크 열기를 시도했으나 크로스오리진 iframe이 `HTTP 403`으로 차단되어 열리지 않았다.

## 근거 링크

이슈 #78, ADR-0015
