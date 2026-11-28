# 2026-11-28 · Android 터미널이 버리던 피처 줄 40가지를 그리기

- 작성자: @carti1108
- 이슈·PR: #95, #98, #101, #104, #110, #113, #123, #126, #133, #136(터미널 줄 부분)
- 커밋: 없음(커밋 전)

> **요약** Android `TerminalStateEncoder`가 `shortcut:` 주석과 함께 `return nil`로 버리던 코어 줄 40가지(정리·고치기·샘플·고르기 빼기·모든 기기 로그아웃·묶음·자세히 보기·찾아두기·연결·가져오기)를 JSON으로 넘기고, Kotlin 디코더가 웹 `terminal.tsx`와 같은 문구로 그리게 했다. 코어·서버·계약은 건드리지 않았다.

## 사용 도구

Claude Code(Opus 5.5), WSL Ubuntu-24.04(Swift 6.4.2, Swift Android SDK, OpenJDK 21), Android Emulator(`Medium_Phone_API_37.0`, x86_64).

## 요청

남은 Android 이슈를 정리하던 중, 코어에 로직이 다 있으니 터미널 줄은 뷰만 붙이면 된다는 판단에 따라 버려지던 줄을 한 번에 그리라고 요청했다.

## AI 산출물

- Swift: `FeatureTerminalAndroid/TerminalStateEncoder.swift`(줄 40가지 인코딩, `missingArgument`의 `sub`, `summarySource`), `GrepAndroid/FeatureDemoController.swift`(데모 시나리오 3종), 테스트 `TerminalEncoderFeatureTests.swift`
- Kotlin: `TerminalFeatureLineDecoder.kt`(줄별 문구), `TerminalStateDecoder.kt`(빠진 인자 문구·명령 이름 추가), `TerminalModels.kt`(`PlainLine`·`ChipLine`·`ItemDetail`), `TerminalChipBlocks.kt`(칩 줄·자세히 보기 화면), `TerminalView.kt`(새 항목 연결, 고른 행을 누르면 `고르기 빼기`), 테스트 `TerminalFeatureLineDecoderTest.kt`

## 사람의 판단

- 이슈마다 PR을 나누지 않고 터미널 줄 전체를 한 PR로 붙이기로 했다. 휴지통·편집·상세처럼 터미널 밖 화면이 있는 이슈는 그 뒤에 이슈별로 한다.

## 검증

- WSL `swift test --disable-sandbox`: 20/20 통과(새 3건, 그중 하나는 40가지 줄이 모두 인코딩되는지)
- WSL `./gradlew -PswiftAbis=x86_64 test :app:assembleDebug :feature:terminal:demo:assembleDebug`: 단위 테스트 54건 통과(새 13건), APK 빌드 통과
- 에뮬레이터 `:feature:terminal:demo` 새 시나리오 3종: 정리·묶음·찾아두기·자세히 보기(펼치기 포함)·연결·가져오기 줄 표시 확인

## 검증하지 못한 것

1. 실제 코어와 서버로 명령을 쳐서 나오는 줄은 확인하지 않았다(데모는 고정 상태를 그린다).
2. 자세히 보기의 이미지 미리보기(`previewUrl`)는 그리지 않는다. Android에 이미지 로더가 없다.

## AI의 오류와 정정

- 버려지던 줄을 처음에 41가지라고 했으나 인코더 목록을 세어 보니 40가지였다.
- 칩 줄에서 `FlowRow`가 항목을 위로 붙여 글자와 칩의 세로 위치가 어긋났다. 에뮬레이터 화면에서 보고 `itemVerticalAlignment`로 가운데 맞췄다.

## 근거 링크

ARC-002, ARC-003, ARC-004, ARC-005, ARC-007, ARC-008, ARC-010, ARC-011, ARC-012, ACC-002, COM-007, MOB-002, commands 6절.
