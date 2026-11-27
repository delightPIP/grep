# Android 앱

공유 코어([`core/`](../core/Package.swift))를 Swift Android SDK(6.4.2)로 `.so` 빌드하고 `swift-java`로 Kotlin/Compose에 연결한 Android 앱이다([ADR-0015](../docs/adr/ADR-0015-mobile-feature-modules-per-issue.md), 이슈 #79).
피처 `demo` 앱은 하단 시나리오 바 대신 **시나리오 목록 화면 → 항목 선택 시 전체 화면으로 피처 표시 + 닫기(뒤로 가기) 복귀** 패턴을 따른다(iOS `Example` 앱과 통일).

## 구조

| 위치 | 내용 |
|---|---|
| `swift/Sources/GrepAndroidSupport` | 화면 기반 클래스(`BridgedScreen`), 화면 등록부, 루트·자리표시 화면 |
| `swift/Sources/FeatureXxxAndroid` | 피처의 Android 화면(뷰 계약 구현)과 뷰 팩토리 |
| `swift/Sources/GrepAndroid` | 전체 앱(`GrepAppController`), 피처 데모(`FeatureDemoController`), 플랫폼 포트 어댑터 |
| `swift/Sources/GrepBridge` | JNI 진입점(`JNI.swift`)과 `swift-java` 바인딩(`*Handle.swift`) |
| `bridge` | Kotlin 브리지(`SwiftBridge`, `RibActivity`)와 플랫폼 포트 5종(`HttpUrlConnectionTransport`, `AndroidAuthPort`, `AndroidClipboardPort`, `AndroidFilePort`, `SharedPrefsHistoryStore`) |
| `feature/<피처>/ui` | 순수 Compose 뷰(`:bridge` 비의존) |
| `feature/<피처>/adapter` | `swift-java` 브리지 구현과 `:ui` 연결 |
| `feature/<피처>/demo` | 해당 피처만 띄우는 단독 실행 앱 |
| `app` | 전체 앱(`MainActivity`) |

## 빌드와 테스트 (WSL Ubuntu / macOS / Linux)

```bash
# 1. Swift 호스트 단위 테스트
bash android/build-swift.sh test

# 2. Android .so 교차 빌드 (기본 arm64-v8a, 에뮬레이터는 x86_64)
bash android/build-swift.sh arm64-v8a

# 3. Android Gradle 단위 테스트 및 디버그 APK 빌드
cd android
./gradlew test
./gradlew :app:assembleDebug
./gradlew :feature:loggedout:demo:assembleDebug
./gradlew :feature:terminal:demo:assembleDebug
```
