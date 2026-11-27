# 2026-11-27 · #79 Android 1단계 뼈대(Gradle·Swift .so·swift-java·플랫폼 포트·로그인 화면) 구현

- 작성자: @carti1108
- 이슈·PR: #79
- 커밋: 없음(커밋 전)

> **요약** 이슈 #79 1단계로 `android/` Gradle + Compose 프로젝트와 공유 코어(`core/`)의 Swift Android SDK(`.so`)·`swift-java` 바인딩, 플랫폼 포트 5종, `feature/loggedout/{ui,adapter,demo}`를 구현했다. 사람은 `grep-design` 시안 반영, 데모 앱 시나리오 목록 패턴 통일(이슈 #79 댓글), 1단계 선 PR 머지 순서를 결정했다.

## 사용 도구

Antigravity(Gemini), WSL Ubuntu-24.04(Swift 6.4.2, Swift Android SDK, OpenJDK 21, Gradle 9.7.1), Android Emulator(`Medium_Phone_API_37.0`), `gh` CLI.

## 요청

세션 핸드오프 문서(`.handoff-latest.md`)를 확인하고 이슈 #79 1단계(Android 뼈대, `.so` 빌드·`swift-java` 바인딩, 플랫폼 포트 Kotlin 구현, `loggedout` ui·adapter·demo)를 구현·검증한 뒤 `origin/main`에 리베이스해 PR로 정리할 것을 요청했다. 작업 중 `grep-design` 시안 반영, 에뮬레이터 실행 확인, 이슈 #79 댓글의 시나리오 목록 패턴 적용을 지시했다.

## AI 산출물

- Gradle 멀티모듈 뼈대: `android/settings.gradle.kts`, `android/build.gradle.kts`, `android/gradle/libs.versions.toml`, `android/bridge/build.gradle.kts`, `android/app/build.gradle.kts`, `android/feature/loggedout/{ui,adapter,demo}/build.gradle.kts`, `android/build-swift.sh`
- Swift Android 브리지(`android/swift/`): `Package.swift`, `GrepAndroidSupport`, `FeatureLoggedOutAndroid`, `FeatureTerminalAndroid`(최소 스텁), `GrepAndroid`(앱·데모 컨트롤러 및 플랫폼 포트 어댑터 5종), `GrepBridge`(JNI 진입점과 `swift-java` 핸들), `GrepAndroidTests`
- Kotlin 브리지·플랫폼 포트(`android/bridge/`): `SwiftBridge`, `RibHost`, `HttpUrlConnectionTransport`, `AndroidAuthPort`, `AndroidClipboardPort`, `AndroidFilePort`, `SharedPrefsHistoryStore`, 단위 테스트 `PlatformPortsTest`
- 로그인 피처·앱: `LoggedOutView`(`MobileLogin.dc.html` 시안·16×16 픽셀 두더지·`ACC-001` 원문), `LoggedOutScreen`, `LoggedOutDemoActivity`(시나리오 목록 → 전체 화면 피처 + 닫기/뒤로 가기 복귀), `MainActivity`, 단위 테스트 `LoggedOutNoticeFormatTest`·`LoggedOutDecodeTest`

## 사람의 판단

- 뷰 구현 시 로컬 `C:\Users\user\Desktop\grep-design` 시안을 참고해 그리도록 지시했다.
- 이슈 #79 댓글로 피처 `demo` 앱을 하단 시나리오 바 대신 **시나리오 목록 화면 → 전체 화면 피처 + 닫기(뒤로 가기) 복귀** 패턴으로 통일하도록 결정했다.
- 에뮬레이터 PIN을 초기화하고 직접 에뮬레이터를 실행해 `loggedout:demo` 동작을 확인했다.
- iOS(`#82` → `#83`)와 동일하게 `#79` 1단계를 먼저 `origin/main`에 리베이스해 PR을 열고, 2단계(`terminal`·`loggedin` 하단 탭)를 이어가기로 선택했다.

## 검증

- `bash android/build-swift.sh test` (WSL Swift 호스트 단위 테스트): 통과
- `./gradlew test :app:assembleDebug :feature:loggedout:demo:assembleDebug` (WSL, `arm64-v8a` `.so` 포함): 통과
- Windows `Medium_Phone_API_37.0` (`x86_64`) 에뮬레이터에서 `feature:loggedout:demo` 설치·실행 및 화면 캡처 확인: 통과
- `Scripts/check-docs.sh`: 통과

## 검증하지 못한 것

1. 실제 Supabase OAuth 딥링크(`grep://auth/callback`) 왕복 로그인과 실제 백엔드 서버 연동은 2단계 터미널 화면 완성 후 에뮬레이터에서 통합 확인할 예정이다.
2. `MainActivity`의 로그인 후 화면(`TerminalPlaceholderScreen`)은 `#79` 2단계에서 `:feature:terminal`·`:feature:loggedin` 하단 탭으로 교체할 임시 스텁이다.

## AI의 오류와 정정

- 초기에 `android/build-swift.sh`에서 `set -u` 뒤에 `~/.profile`을 불러와 미선언 변수로 즉시 종료되는 문제가 있었고, `source`를 `set -u` 이전으로 옮겨 해결했다.
- `bridge/build.gradle.kts`에 `outputs.file(swiftKitCoreJar)`를 추가했을 때 Gradle 9.7의 암묵적 의존성 오류가 발생해 `api(files(swiftKitCoreJar) { builtBy(swiftLibTasks) })`로 수정했다.
- 에이전트 셸에서 직접 띄운 Android Emulator·Android Studio가 비가시 세션·Job Object 제약으로 사용자 화면에 표시되지 않는 문제를 확인하고 중단·보고한 뒤, 사용자가 직접 띄운 에뮬레이터에 `adb`로 설치·실행했다.

## 근거 링크

이슈 #79, ADR-0015, 커밋 없음(커밋 전).
