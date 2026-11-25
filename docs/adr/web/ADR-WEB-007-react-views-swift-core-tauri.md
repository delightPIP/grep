### ADR-WEB-007 웹 클라이언트는 React 뷰와 carti-RIBs-Swift 공유 코어로 만들고, 데스크톱은 Tauri로 감싼다
- 상태: 채택
- 날짜: 2026-11-25
- 영역: 웹

> **요약** 뷰는 React, TypeScript, Vite SPA로 만들고, 뷰를 뺀 코드(RIB 트리, 명령어 해석, 화면 상태, API 호출)는 carti-RIBs-Swift 공유 코어에 둔다. 공유 코어는 Swift를 WebAssembly로 컴파일해 브라우저에서 실행한다. 데스크톱 앱은 같은 웹 빌드를 Tauri로 감싼다.

#### 배경

팀은 네 플랫폼을 원하고, 클라이언트는 플랫폼마다 네이티브 뷰를 만들되 뷰를 뺀 코드는 carti-RIBs-Swift로 공유한다. 첫 클라이언트는 웹이다.

- 브라우저는 Swift를 직접 실행하지 못하므로 공유 코어는 WebAssembly로 컴파일해 돌린다.
- carti-RIBs-Swift는 이 방식으로 웹을 지원한다. JavaScriptKit과 BridgeJS로 연결하고, React 뷰와 Swift 코어를 묶은 샘플(TodoModular)과 웹 E2E 테스트가 있다.
- 실측 릴리스 크기는 10.2MB, gzip 2.81MB다.

데스크톱 앱도 원하고, 별도로 만들지 않고 웹 빌드를 재사용하려 한다.

#### 결정

1. 뷰는 React, TypeScript, Vite로 만든 SPA다. 서버 렌더링은 쓰지 않는다.
2. RIB 트리, 명령어 해석(한글·영문 명령, `|` 이어 쓰기, [명령어 설명서](../../planning/commands.md)), 화면 상태, API 호출은 carti-RIBs-Swift 공유 코어에 둔다. 뷰와 코어는 화면 상태와 사용자 행동 계약(ViewState, ViewAction)으로만 연결한다.
3. 네트워크 요청, 클립보드, 파일 선택과 끌어다 놓기 같은 플랫폼 기능은 뷰 쪽에서 구현해 코어에 주입한다.
4. 터미널 화면은 일반 DOM(입력창과 출력 목록)으로 그린다. 터미널 에뮬레이터 라이브러리는 쓰지 않는다.
5. 데스크톱 앱은 같은 웹 빌드를 Tauri로 감싼다. 전역 단축키 같은 데스크톱 기능은 Tauri 플러그인으로 붙인다.
6. API 타입은 OpenAPI 스펙(ADR-0001)에서 생성하는 방향으로 간다. 생성 도구는 첫 스파이크에서 정한다.

#### 고려한 대안

| 대안 | 기각 이유 |
| :--- | :--- |
| 공유 코어 없이 TypeScript만으로 웹 클라이언트 | 웹만 보면 가장 빠르지만, 나중에 iOS와 Android에서 같은 로직을 다시 만들어야 한다 |
| Svelte, SolidJS 뷰 | 가볍지만 생태계가 작다. carti-RIBs-Swift와 React 뷰 조합은 샘플로 검증되어 있다 |
| Next.js | 서버 렌더링 중심이라 Tauri에서는 정적 내보내기로만 써야 해서 장점이 사라진다 |
| 터미널 에뮬레이터(xterm.js 등)로 화면 구성 | 한국어 입력 조합, 버튼·링크 클릭, 접근성을 따로 처리해야 한다 |

#### 결과

- 얻는 것: 나중에 만들 iOS와 Android 앱이 같은 공유 코어를 쓴다. 웹과 데스크톱이 같은 빌드다. 화면 동작이 플랫폼 사이에서 같다.
- 비용: 첫 로딩에 Wasm 약 2.8MB(gzip)가 더해진다. 그렙에 필요한 API 호출, 클립보드, 파일 연결을 Swift 코어와 React 사이에 새로 만들어야 하므로 첫날 스파이크로 확인한다. 디버깅을 두 언어에서 해야 한다. Tauri는 OS마다 다른 웹뷰(Windows WebView2, macOS WKWebView 등)를 써서 화면 차이가 생길 수 있다.

#### 관련

ADR-0001, carti-RIBs-Swift 레포의 웹 연결 결정(JavaScriptKit, BridgeJS, React 뷰 샘플)
