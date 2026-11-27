# 2026-11-28 · #79 Android 2단계 터미널(저장·최근·찾기·#62 고르기·넘기기·확인·도움말)과 하단 탭 컨테이너 구현

- 작성자: @carti1108
- 이슈·PR: #79, #62
- 커밋: 없음(커밋 전)

> **요약** 이슈 #79 2단계로 Android 터미널 피처(`:feature:terminal:{ui,adapter,demo}`), 로그인 후 하단 탭 컨테이너(`:feature:loggedin:ui`), 그리고 이미 `core/`에 머지된 `#62`(고르기·넘기기·5건 초과 확인·도움말) UI·Swift 브리지를 함께 구현했다. 에뮬레이터 검증 중 발견한 Swift Foundation 런타임 `.so` 누락을 `bridge/build.gradle.kts`에 반영해 무크래시 렌더링을 확인했다.

## 사용 도구

Antigravity(Gemini), WSL Ubuntu-24.04(Swift 6.4.2, Swift Android SDK, OpenJDK 21, Gradle 9.7.1), Android Emulator(`Medium_Phone_API_37.0`), `gh` CLI.

## 요청

오픈된 Android 이슈와 다음 계획을 정리한 뒤, `#79` 2단계(`feature/terminal`, `feature/loggedin` 하단 탭 컨테이너)에 이미 `core/`·웹·iOS에 반영된 `#62` 출력(고르기·넘기기·5건 초과 확인·도움말)을 함께 구현·검증하고 PR을 생성할 것을 요청했다.

## AI 산출물

- Swift 브리지·데모(`android/swift/`): `FeatureTerminalAndroid/TerminalStateEncoder.swift`, `GrepBridge/TerminalHandle.swift`, `GrepAndroid/FeatureDemoController.swift`(터미널 시나리오 12종), `GrepBridge/JNI.swift`, `GrepAndroidTests/ControllerTests.swift`
- Android 런타임 패키징: `android/bridge/build.gradle.kts`(`libswiftDispatch.so`, `libFoundation.so`, `libFoundationInternationalization.so`, `lib_FoundationICU.so` 추가)
- 터미널 피처(`android/feature/terminal/{ui,adapter,demo}`): `TerminalModels.kt`, `TerminalView.kt`(환영 화면, 결과 행 탭 즉시 `고르기`, 선택 줄 `넘기기 N건`, 넘기기 미리보기·Android 공유 시트 `ACTION_SEND`, 5건 초과 44dp 낱말 버튼, 도움말 13줄, 4버튼/확장 명령 바), `TerminalStateDecoder.kt`, `TerminalScreen.kt`, `TerminalDemoActivity.kt`, 단위 테스트 `TerminalFormatTest`·`TerminalStateDecoderTest`
- 로그인 후 탭 컨테이너·앱 연결: `android/feature/loggedin/ui/LoggedInTabContainer.kt`(MOB-001 3탭·키보드/선택 시 탭바 숨김·상태 유지·재선택 스크롤), `LoggedInTabTest.kt`, `android/app/src/main/kotlin/com/unwrap/grep/MainActivity.kt`

## 사람의 판단

- `#62`는 서버·`core/`·웹·iOS가 이미 완료되어 있으므로, Android `#79` 2단계 터미널 구현 시 별도 PR로 쪼개지 않고 한 번에 함께 연결하기로 결정했다.

## 검증

- WSL Swift 호스트 단위 테스트 (`swift test --disable-sandbox`): 8/8 통과
- WSL Android Gradle 테스트 및 `x86_64` APK 빌드 (`./gradlew -PswiftAbis=x86_64 test :app:assembleDebug :feature:terminal:demo:assembleDebug :feature:loggedout:demo:assembleDebug`): 통과
- Windows `Medium_Phone_API_37.0` (`x86_64`) 에뮬레이터에서 `:feature:terminal:demo` 설치·실행 및 `도움말`·`고르기 선택 줄` 시나리오 Swift `.so` 연동 렌더링·뒤로 가기 복귀·무크래시 확인: 통과
- `Scripts/check-docs.sh`: 통과

## 검증하지 못한 것

1. 로컬 백엔드 서버를 띄운 실제 로그인 → `담기` → `최근` E2E 확인은 이번 PR에서 수행하지 않았다.
2. 이번 `.so` 교차 빌드는 에뮬레이터 검증용 `x86_64`만 실행했으며, `arm64-v8a` 실기기 빌드는 추후 확인한다.

## AI의 오류와 정정

- JVM 단위 테스트(`TerminalStateDecoderTest`)에서 Android SDK `org.json.JSONObject` 스텁 예외가 발생해 `feature/terminal/adapter/build.gradle.kts`에 `testImplementation("org.json:json:20240303")`을 추가해 해결했다.
- 에뮬레이터에서 시나리오 진입 시 `TerminalStateEncoder`의 `Foundation` 사용으로 인해 `libswiftDispatch.so` 누락(`UnsatisfiedLinkError`)이 발생했고, `readelf -d`로 필요한 런타임 `.so` 4종을 확인해 `bridge/build.gradle.kts`에 추가한 뒤 재검증했다.

## 근거 링크

이슈 #79, 이슈 #62, ADR-0015, MOB-001, MOB-002.
