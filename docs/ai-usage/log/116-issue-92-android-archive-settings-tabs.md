# 2026-11-28 · #92 Android 보관함·설정 탭과 `:feature:loggedin` 어댑터·데모

- 작성자: @carti1108
- 이슈·PR: #92
- 커밋: 없음(커밋 전)

> **요약** iOS #91과 같은 구성으로 Android 하단 탭의 보관함·설정 탭을 채웠다. 보관함 목록은 Swift 쪽 `HTTPArchiveItemLoader`·`ArchiveItemMapper`(iOS와 같은 규칙)가 이미 설치된 HTTP·인증 포트로 `GET /items`를 불러 행 값 JSON으로 넘기고, Kotlin은 탭 상태 모델과 순수 Compose 화면만 갖는다. 보관함 체크·해제와 설정 로그아웃은 터미널 명령(`고르기`, `고르기 빼기`, `고르기 비우기`, `로그아웃`)으로 보낸다.

## 사용 도구

Claude Code(Opus 5.5), WSL Ubuntu-24.04(Swift 6.4.2, Swift Android SDK, OpenJDK 21), Android Emulator(`Medium_Phone_API_37.0`, x86_64), `gh` CLI.

## 요청

열린 Android 이슈를 파악한 뒤 첫 이슈인 #92(보관함·설정 탭)를 진행할 것을 요청했다.

## AI 산출물

- Swift(`android/swift/`): `GrepAndroid/Archive/ArchiveItemLoader.swift`, `GrepAndroid/Archive/ArchiveItemMapper.swift`(`ArchivePageEncoder` 포함), `GrepBridge/ArchiveHandle.swift`(`ArchiveLoaderHandle`, `ArchivePageCallback`), 테스트 `GrepAndroidTests/ArchiveTests.swift`
- 순수 뷰(`android/feature/loggedin/ui`): `ArchiveView.kt`, `SettingsView.kt`, `LoggedInComponents.kt`(MTopBar·UiButton·UiSettingRow·MPickBar·MSheet), `LoggedInModels.kt`, `LoggedInPalette.kt`, `LoggedInTabContainer.kt`(선택 탭을 밖으로 올리고 탭 재선택 콜백 추가), 테스트 `ArchiveRowTailTest.kt`
- 어댑터(`android/feature/loggedin/adapter`, 새 모듈): `LoggedInTabsModel.kt`, `LoggedInTabsScreen.kt`, `ArchiveItemLoader.kt`(`SwiftArchiveItemLoader`, JSON 해석), 테스트 `LoggedInTabsModelTest.kt`·`ArchivePageDecoderTest.kt`
- 데모(`android/feature/loggedin/demo`, 새 모듈): iOS Example과 같은 시나리오 5종, 가짜 보관함 로더, 터미널 탭 자리표시
- 터미널 연결: `TerminalUiState.itemCount`, `TerminalScreen`의 `onContextChanged`·`TerminalCommandSender`, `MainActivity`의 `LoggedInHostScreen`

## 사람의 판단

- #92를 Android 이슈 중 첫 작업으로 진행하기로 했다.

## 검증

- WSL Swift 호스트 단위 테스트(`swift test --disable-sandbox`): 17/17 통과(새 9건 포함)
- WSL Gradle(`./gradlew -PswiftAbis=x86_64 test :app:assembleDebug :feature:{loggedin,terminal,loggedout}:demo:assembleDebug`): 단위 테스트 37건 통과, APK 빌드 통과
- 에뮬레이터 `:feature:loggedin:demo`: 보관함 목록·머리 줄 `자료 25`·체크/선택 줄/해제·고르기 중 탭바 숨김·더 보기(25건)·보관함 탭 재선택 시 맨 위로·연결 끊김 뒤 다시 시도·0건 화면·설정 로그아웃 시트(뒤로 가기로 닫힘, 확인 시 `로그아웃` 명령) 확인

## 검증하지 못한 것

1. 실제 서버와 로그인으로 전체 앱(`:app`)에서 보관함 `GET /items`를 부르는 흐름은 확인하지 않았다.
2. `arm64-v8a` 빌드는 하지 않았다.

## AI의 오류와 정정

- `LoggedInTabsScreen`의 마지막 파라미터를 `modifier`로 두어 trailing lambda가 `modifier`로 넘어가 컴파일이 실패했다. `terminalContent`를 마지막으로 옮겼다.
- 데모의 닫기 버튼(오른쪽 위)이 보관함 머리 줄의 `자료 N`을 가려 가운데로 옮겼다.
- Windows 체크아웃에서 `android/build-swift.sh`가 CRLF라 WSL에서 `set: pipefail` 오류가 났다. 스크립트 대신 `swift test`를 직접 실행했다.

## 근거 링크

이슈 #92, #91, ADR-0015, MOB-001, ACC-001, ARC-004, COM-010.
