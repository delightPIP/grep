### ADR-0018 공유 코어는 Core·피처·App 패키지로 나누고, 피처 안은 Shared(Domain·Data)와 Main·하위 모듈로 나눈다
- 상태: 채택
- 날짜: 2026-11-28
- 영역: 공통

> **요약** core 루트 `Package.swift` 하나를 `Core`(GrepDomain·GrepCore·GrepData·GrepCoreTesting), `Features/<피처>`, `App` 패키지로 나눈다. 피처 패키지 안은 MusicSearch `Features/<피처>`처럼 `Shared/Domain`·`Shared/Data`와 RIB인 `<피처>Main`, 하위 모듈로 나눈다. 패키지 목록은 SwiftPM이 맡고 iOS Tuist는 이 패키지들을 로컬 패키지로 가져다 쓴다.

#### 배경

ADR-0017로 보관함·설정을 피처로 뗐지만 core는 여전히 패키지 하나, 터미널은 Interactor 하나(838줄)에 명령 16가지가 붙은 모양이었다. 개발자는 MusicSearch처럼 피처마다 따로 모듈·패키지로 나누기를 원했다. MusicSearch는 Tuist로 피처마다 `Project.swift`를 두지만, Tuist 4.191.5의 빌드 대상은 Apple 플랫폼(iOS·macOS·watchOS·tvOS·visionOS)뿐이고 웹(wasm)·Android는 core를 SwiftPM으로 빌드한다.

#### 결정

1. core는 패키지 여러 개다: `core/Core`, `core/Features/{LoggedOut, Terminal, Archive, Settings, LoggedIn}`, `core/App`. 패키지마다 `swift test`를 돈다.
2. `Core` 패키지는 `GrepDomain`(값·규칙·Repository 계약), `GrepCore`(플랫폼 포트, GrepDomain을 다시 내보냄), `GrepData`(서버 API 클라이언트), `GrepCoreTesting`을 둔다.
3. 피처 패키지는 `Shared/Domain`(그 피처의 값·Repository 계약), `Shared/Data`(구현), `<피처>Main/{Interface, Sources, Testing, Tests}`(RIB)으로 나눈다. 제품 이름(`Feature<피처>`·`Feature<피처>Interface`·`Feature<피처>Testing`)은 그대로 둔다.
4. 보관함·설정 Interactor는 Repository 계약만 알고, 조립(`App`)이 구현을 넣는다.
5. 터미널은 화면이 하나라 하위 모듈이 RIB이 아니라 명령 모듈이다: `TerminalSave`·`TerminalBrowse`·`TerminalHandoff`·`TerminalCollections`·`TerminalConnections`. 명령 모듈은 `TerminalCommandKit`의 `TerminalContext`로 터미널 RIB을 쓰고, 확인 대기(COM-007)는 각 모듈이 갖는다. 터미널만 쓰는 API는 `Terminal/Shared/Data`(`TerminalData`)에 둔다.
6. 플랫폼(웹·Android `Package.swift`, iOS `Project.swift`)은 필요한 패키지를 각각 참조한다. iOS는 Tuist가 이 패키지들을 `.local(path:)`로 가져온다.

#### 고려한 대안

| 대안 | 기각 이유 |
| :--- | :--- |
| core를 Tuist `Project.swift`로 옮기기 | Tuist는 Apple 플랫폼만 빌드한다. 웹·Android가 core를 빌드하지 못한다 |
| `Package.swift`와 Tuist `Project.swift`를 둘 다 두기 | 모듈 목록을 두 곳에서 맞춰야 해서 어긋난다 |
| core 패키지 하나에 타깃만 잘게 나누기 | 피처끼리 경계가 매니페스트 한 파일에 섞이고, 피처 하나만 빌드·테스트할 수 없다 |
| 터미널 명령을 각각 RIB으로 | 터미널은 화면 하나·상태 하나다. 명령마다 화면이 없어 RIB의 Router·뷰가 쓸모없다 |

#### 결과

- 얻는 것: 피처마다 혼자 빌드·테스트한다. 터미널 Interactor가 838줄에서 521줄로 줄고 명령 묶음이 모듈 경계로 나뉜다. 플랫폼 제품 이름은 그대로다.
- 비용: 패키지마다 `.build`가 따로 생겨 처음 빌드가 느리다. 플랫폼 매니페스트에 패키지 목록이 늘었다. CI는 패키지를 돌며 테스트한다.

#### 관련

ADR-0015, ADR-0017(결정 6을 대체), `docs/planning/structure-cleanup-plan.md`
