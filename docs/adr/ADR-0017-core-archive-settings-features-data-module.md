### ADR-0017 공유 코어는 보관함·설정을 피처로 따로 두고, 서버 API 클라이언트를 GrepData 모듈로 모은다
- 상태: 일부 대체됨 (결정 6 → ADR-0018)
- 날짜: 2026-11-28
- 영역: 공통

> **요약** 공유 코어에 `Archive`·`Settings` 피처를 두어 `LoggedIn` 컨테이너의 자식으로 붙이고, `Terminal`에서 보관함·설정 상태를 뺀다. 피처들이 같이 쓰는 서버 API 클라이언트는 `GrepData`로, 그 클라이언트가 쓰는 값 타입은 `GrepCore`로 옮긴다. RIB은 Builder·Interactor·Router를 파일 하나씩으로 나눈다.

#### 배경

#168에서 보관함·설정 탭 상태를 `TerminalViewState`에 넣었다. 그 결과 탭을 열려면 터미널 RIB이 있어야 했고, 탭 상태가 바뀔 때마다 터미널 상태와 기록 저장을 다시 탔다. ADR-0015가 `LoggedIn`을 쪼갠 이유(한 파일이 계속 커진다)가 `Terminal.swift`(838줄)에서 다시 생겼다. 또 API 클라이언트가 `FeatureTerminal` 안에 있어 다른 피처가 쓸 수 없었고, iOS·Android가 같은 요청을 각자 다시 만들었다(정리 계획 `docs/planning/structure-cleanup-plan.md`).

#### 결정

1. `Archive`·`Settings`는 각자 Interface·Sources·Testing·Tests를 가진 피처다. `LoggedIn`이 `Terminal`과 함께 자식으로 붙인다.
2. 터미널은 자료·연결이 바뀌면 `TerminalListener`(`didChangeItems`·`didChangeConnections`)로 알린다. 보관함·설정을 다시 받게 하는 것은 컨테이너가 한다.
3. 서버 API 클라이언트(요청을 만들고 응답을 해석하는 것)는 `GrepData` 모듈에 둔다. 피처 Impl이 같이 쓴다. 그 클라이언트가 쓰는 값 타입(`ItemRef`, `SearchQuery`, `CommandFailure` 등)과 찾기 해석(`SeekCommand`·`PeriodParser`), `DeviceTime`은 `GrepCore`에 둔다.
4. `FeatureTerminalInterface`는 `GrepCore`를 다시 내보내(`@_exported`) 플랫폼 코드의 import를 바꾸지 않는다.
5. 보관함·설정 화면을 아직 core 상태로 그리지 않는 플랫폼은 `GrepAppViewFactory` 기본 구현(빈 뷰)을 쓴다. 웹은 세 RIB의 상태를 브리지에서 한 객체로 합쳐 지금의 `LoggedInState` 모양 그대로 넘긴다.
6. RIB은 역할마다 파일 하나(`XBuilder`·`XInteractor`·`XRouter`)로 `Sources/RIBs/` 아래에 둔다.

#### 고려한 대안

| 대안 | 기각 이유 |
| :--- | :--- |
| 보관함·설정을 `Terminal` 안에 그대로 두기 | 탭이 터미널 RIB에 묶이고, 터미널 Interactor와 상태가 계속 커진다 |
| 보관함·설정을 `LoggedIn` Interactor에 직접 넣기 | 컨테이너가 화면 상태를 갖게 되어 ADR-0015 결정 1(컨테이너는 계정에 딸린 일만)과 어긋난다 |
| API 클라이언트를 피처마다 복사 | iOS·Android에서 이미 생긴 중복을 core 안에서도 만든다 |
| `GrepData`가 `FeatureTerminalInterface`를 의존 | 데이터 계층이 피처 계약에 기대 계층이 거꾸로 된다 |

#### 결과

- 얻는 것: 탭마다 혼자 붙여 테스트할 수 있다. 터미널 상태에서 탭 필드가 빠진다. 보관함·휴지통 HTTP를 iOS·Android에서 지울 준비가 된다.
- 비용: 웹 브리지에 상태를 합치는 코드(`LoggedInComposer`)가 생긴다. iOS·Android는 core 보관함·설정 뷰를 잇기 전까지 빈 뷰를 쓴다. `@_exported import`는 밑줄 붙은 기능이다.

#### 관련

ADR-0015, ADR-WEB-007, 이슈 #168, `docs/planning/structure-cleanup-plan.md`
