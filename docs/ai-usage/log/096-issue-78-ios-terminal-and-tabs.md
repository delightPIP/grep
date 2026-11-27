# 2026-11-27 · #78·#61 iOS 터미널(저장·최근·찾기) 화면과 하단 탭 컨테이너 구현

- 작성자: @carti1108
- 이슈·PR: #78, #61
- 커밋: 없음(커밋 전)

> **요약** 로컬로 내보낸 디자인 시안(`/Users/carti/Desktop/grep-design`의 M1·M2·M3·MTopBar·MCommandBar·MTabBar·MList)을 기준으로 `Features/Terminal/{UI,Adapter,Example,Tests}`와 `Features/LoggedIn/UI`(하단 탭 컨테이너)를 구현하고 `GrepIOSApp`에 연결했다. 사람이 Example 앱의 시나리오 선택 UI를 하단 바 대신 `MusicSearch`의 목록 → 전체 화면 전환 방식으로 바꾸도록 지시해 `TerminalExampleApp`과 `LoggedOutExampleApp`에 반영했다.

## 사용 도구

Antigravity, Gemini 4 Neon (Medium), `docs:ai-usage`, `core-dev:commit-rules`, Tuist 4.191.5, Xcode 27.0.

## 요청

- 이미 `main`에 머지된 웹·코어 기능(#57 저장, #60 최근, #77 Terminal 분리, #61 찾기)을 따라가는 다음 iOS 뷰 구현
- 로컬 디자인 폴더(`/Users/carti/Desktop/grep-design`)를 참고해 새 브랜치(`feat/m61-ios`)에서 진행
- Example 앱 시나리오 전환을 하단 바 대신 `MusicSearch` 방식(시나리오 목록 → 전체 화면)으로 변경 및 PR 준비

## AI 산출물

- `Features/Terminal/UI`: `TerminalModels.swift`, `TerminalView.swift` (M1 첫 화면, M2 확장 명령 격자, M3 두 줄 결과 행·`→ 더 보기`, MTopBar, MCommandBar)
- `Features/Terminal/Adapter`: `TerminalStateMapper.swift`(정책 원문·KST 시각·24자 제목·상태줄 포맷), `TerminalScreen.swift`
- `Features/Terminal/Example`: `TerminalExampleApp.swift` (시나리오 목록 → `fullScreenCover` 전환, 7종 시나리오)
- `Features/LoggedOut/Example`: `LoggedOutExampleApp.swift` (동일한 시나리오 목록 → `fullScreenCover` 패턴으로 통일)
- `Features/Terminal/Tests`: `TerminalStateMapperTests.swift` (단위 테스트 5건)
- `Features/LoggedIn/UI`: `LoggedInTabContainerView.swift` (하단 탭 3칸, 키보드 표시 시 숨김)
- `ios/App/Sources/GrepIOSApp.swift`, `ios/Project.swift`: `TerminalPlaceholderScreen` 제거 및 실제 `TerminalScreenFactory` + 하단 탭 컨테이너 연결

## 사람의 판단

- 로컬 내보내기 시안 폴더(`/Users/carti/Desktop/grep-design`)를 기준으로 새 브랜치에서 작업 진행 지시
- "시나리오를 하단에 해놨는데 이렇게 하기보단 `MusicSearch` 쪽 방식으로 하는게 맞지 않나" 피드백으로 Example 앱을 시나리오 목록 → 전체 화면 방식으로 변경 결정
- 분할 커밋(옵션 A) 및 PR 생성 승인

## 검증

- `tuist test --no-selective-testing --device "iPhone 17"`: 22/22 통과 (`FeatureTerminalAdapterTests` 5, `GrepPlatformTests` 17)
- `xcodebuild build`: `Grep`, `FeatureTerminalExample`, `FeatureLoggedOutExample` 스킴 빌드 통과
- `iPhone 17` 시뮬레이터에서 `FeatureTerminalExample` 실행 및 M1 시안 대조 확인
- `bash Scripts/check-docs.sh`: 통과

## 검증하지 못한 것

- 로컬 백엔드 서버를 띄운 상태에서의 전체 앱(`Grep`) `담기 <링크>` → `최근` → `찾기` 실서버 왕복 테스트

## 근거 링크

이슈 #78, #61, ADR-0015
