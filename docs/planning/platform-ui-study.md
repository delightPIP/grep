# 플랫폼별 UI/UX 학습 노트 (웹·모바일 앱·데스크톱 앱)

2026-11-26. 디자이너·개발자·PO 역할 에이전트 셋이 각각 조사한 내용을 하나로 합쳤다. **정책이 아니라 정책을 세우기 위한 학습 자료다.** 여기서 고른 것은 PO가 확정한 뒤 [정책](../policies/README.md)이나 [ADR](../adr/README.md)로 옮긴다.

**개발 판단은 개발 의견을 따른다(PO 결정, 2026-11-26).** 플랫폼 순서, 기술 구조, 구현 방식, 개발 순서는 개발 안을 기본으로 둔다. 이 노트의 개발 안은 개발 역할 에이전트의 조사이므로, 개발자가 확인하면 그 의견으로 바꾼다. PO 질문으로는 서비스 동작·문구·지표만 남긴다.

> 표기: **[확인]** 1차 출처를 직접 연 사실 · **[2차]** 검색 요약이나 서드파티 자료 · **[추정]** 판단이나 추측. 출처 번호는 맨 아래 목록을 가리킨다.

## 1. 한 장 요약

| 질문 | 세 역할이 모은 답 |
|---|---|
| 플랫폼마다 무엇을 맡기나 | **모바일 = 넣는 입구**(공유 시트, 스크린샷), **데스크톱 = 꺼내 넘기는 출구**(전역 단축키, 클립보드), **웹 = 어디서나 되는 기준 화면** [추정] |
| 모바일 탭바 | 탭 3개 **터미널 · 보관함 · 설정**으로 시작한다. 탭은 화면 이동에만 쓰고 동작(+, 넘기기)을 넣지 않는다 [확인①] |
| "폴더링 화면" | PRD 7절 제외 항목(사용자가 태그·폴더를 관리하는 화면을 중심에 두지 않음)과 **부딪힌다.** 이름은 "보관함", 내용은 **자동 묶음**(형식·출처·날짜·이름 붙인 묶음)으로 하면 풀린다 |
| 터미널 컨셉 | 터미널 화면 안에서는 진하게, 보관함·설정은 같은 글꼴·색 토큰만 쓰는 일반 GUI로 만든다. 모바일은 입력보다 **명령 칩 줄**(US-7)이 먼저다 |
| 우선순위를 가르는 법 | 설문 12명으로는 RICE·Kano 수치를 낼 수 없다. **순간 지도 + 북극성 경로 + 확신 할인** 규칙을 쓴다(5절) |
| 다음 플랫폼 | **개발 안을 따른다:** 웹 → 반응형 모바일 웹·PWA → Tauri 데스크톱 → iOS 네이티브 → Android 재검토. 모바일 웹·PWA가 두 번째라 "저장 입구"라는 PO 쪽 우려도 Android 공유 받기로 일부 채워진다 |
| 모바일 앱의 성립 조건 | **동기화(F6).** 휴대폰에서 저장한 자료가 데스크톱에서 나와야 북극성 지표(넘기기)가 움직인다 |

## 2. 플랫폼 특성과 가이드라인

### 2.1 디자인 가이드라인

| | 모바일(iOS·Android) | 데스크톱(macOS·Windows) | 웹(반응형·PWA) |
|---|---|---|---|
| 내비게이션 | iOS: 탭바는 이동용, 라벨은 한 단어, More 탭은 피하고 늘 보이게 둔다. iOS 26부터 탭바는 콘텐츠 위에 뜬 Liquid Glass이고 스크롤하면 작아질 수 있으며 검색 탭을 따로 둘 수 있다 [확인①]. Android: 같은 계층 목적지 3~5개, 큰 화면에서는 레일로 바꾼다 [확인②] | macOS 사이드바: 2단까지, 기본으로 숨기지 않는다 [확인③]. Windows NavigationView: 641px부터 아이콘 레일, 1008px부터 펼친 패널 [확인④] | 폭에 따라 하단 탭 → 레일 → 사이드바. Android 창 크기 구간 600 / 840 / 1200dp [확인⑤]. 설치형 PWA에는 브라우저 뒤로 가기가 없어 앱 안에 돌아갈 길을 둔다 [확인⑥] |
| 입력 | 터치 위주. 키보드가 화면 아래 절반을 덮는다. 한글은 IME 조합 | 키보드 우선. 메뉴에 있는 명령이어야 찾을 수 있고 단축키를 걸 수 있다 [확인⑦]. 커맨드 팔레트 관례(VS Code ⇧⌘P [확인⑧], Linear ⌘K [2차]) | 마우스·키보드·터치가 섞인다. 브라우저 단축키(Ctrl+N/T/W)는 가로챌 수 없다 [2차] |
| 터치 타깃 | iOS 44pt, Android 48dp [확인⑨⑩] | macOS 28pt [확인⑨] | WCAG 2.2 2.5.8(AA) 24px, 2.5.5(AAA) 44px [확인⑪] |
| 설정 관례 | 설정 수를 줄이고, 감지할 수 있는 값(다크 모드 등)은 묻지 않는다. 위치는 정해져 있지 않다 [확인⑫]. Readwise Reader는 하단 오른쪽 Account 탭 [확인⑬] | macOS: 앱 메뉴 > 설정, ⌘, [확인⑫]. Windows: 내비게이션 맨 아래 고정, 바꾸면 바로 반영 [확인⑭] | 관례가 약하다. 설정 경로를 화면에 보이게 둔다 [추정] |
| 금기 | 탭에 동작 넣기, 탭 5개 초과, 탭 숨기기·비활성화 [확인①] | 메뉴 막대 아이콘에만 기능 두기(시스템이 숨길 수 있음) [확인⑦] | 색으로만 상태 알리기, 브라우저 단축키 덮어쓰기 |

### 2.2 기술 특성

| 항목 | 웹(브라우저·PWA) | 모바일 앱 | 데스크톱(Tauri 2) |
|---|---|---|---|
| 저장 진입점 | 붙여 넣기, 끌어다 놓기. Web Share Target은 **Android Chrome에 설치한 PWA만** 된다 [확인⑮]. iOS Safari는 지원하지 않는다(WebKit 버그 194593, 2019년부터 열림) [확인⑯] | iOS Share Extension, Android `ACTION_SEND` 인텐트 [확인⑰] | 끌어다 놓기, 전역 단축키, 트레이 [확인⑱]. 클립보드 감시는 공식 플러그인에 없다 |
| 넘길 글 복사(F4) | Safari는 클릭 핸들러 안에서 바로 불러야 한다. 서버 응답을 `await`한 뒤 부르면 거부된다 [확인⑲] | 쓰기는 자유롭다. iOS 16부터 앱이 클립보드를 **읽으면** 허용 창이 뜬다 [확인⑳] | 읽기·쓰기 모두 된다 [확인⑱] |
| 배포 | 즉시 반영 | 스토어 심사 | updater 플러그인, 서명·공증 비용 [추정] |
| 웹뷰 | 사용자 브라우저 | — | Windows WebView2(자동 업데이트), macOS WKWebView(OS 업데이트 때만), Linux WebKitGTK(배포판마다 다름) [확인㉑] |

**Tauri로 모바일까지 갈지:** Tauri 팀이 2.0 RC 공지에서 모바일을 과하게 약속했다고 직접 인정했다 [확인㉒]. 공유 받기 기능도 공식으로는 없어서 결국 Xcode에서 Share Extension을 직접 만들어야 한다 [2차]. 그래서 개발 쪽 권장은 **Tauri는 데스크톱 전용, iOS는 네이티브 SwiftUI + 공유 코어(Swift 그대로 컴파일)**다. Android용 Swift SDK는 아직 nightly 프리뷰라 [확인㉓] Android 방식은 iOS 다음에 다시 본다.

### 2.3 모바일 터미널 입력의 함정

| 문제 | 사실 | 대응 |
|---|---|---|
| 키보드가 올라올 때 | Chrome Android 108부터 키보드는 visual viewport만 줄여 하단 고정 요소가 가려질 수 있다. `interactive-widget=resizes-content`는 iOS Safari에서 안 된다 [확인㉔] | `visualViewport` resize로 입력창 위치를 계산한다 |
| 하단 입력창 + 하단 탭바 | 둘 다 아래에 붙으면 겹치거나 같이 밀린다 [추정] | **입력창에 포커스가 가면 탭바를 숨기고 키보드 위에 명령 칩 줄을 띄운다.** Obsidian 모바일이 같은 방식 [2차] |
| 한글 조합 중 Enter | Safari는 조합을 확정하는 Enter를 `compositionend` 뒤에 `isComposing=false`로 보낸다(WebKit 버그 165004) [확인㉕] | `isComposing` 또는 keyCode 229면 무시, 조합 직후 Enter 한 번도 무시 |

## 3. 그렙 화면 구조 제안

### 3.1 모바일 탭 구성안

| 안 | 구성 | 장점 | 단점 |
|---|---|---|---|
| **① 3탭(권장)** | 터미널(홈) · 보관함 · 설정 | 요청한 구조와 같다. 연결(MCP)·계정 설정을 찾기 쉽다. Material 최소 기준(3개)에 맞다 | 자주 안 쓰는 설정이 탭 하나를 차지한다 |
| ② 묶음 중심 | 터미널 · 묶음 · 보관함, 설정은 오른쪽 위 | 넘기기 재사용(F12)과 가장 가깝다 | F12는 P1이라 데모 시점엔 탭이 비어 보인다 |
| ③ 최소 | 터미널 · 보관함, 설정은 오른쪽 위 | 단순하다 | 탭 2개는 Material 권장 범위 밖 |

①로 시작하고, 이름 붙인 묶음이 자리를 잡으면 ②로 옮기는 안이 디자이너·PO 공통 의견이다. HIG가 막는 것은 "동작을 탭으로 두는 것"이지 설정 탭이 아니다 [확인①].

**덧붙임(PO):** 모바일에서 가장 중요한 화면은 탭이 아니라 **앱 밖의 공유 시트**다. 탭보다 공유 시트 동작을 먼저 정한다.

### 3.2 화면 세 개의 역할

| 화면 | 역할 | 핵심 요소 |
|---|---|---|
| 터미널(홈) | 저장·찾기·고르기·넘기기. 데모 필수 범위 전부 | 프롬프트, 출력 블록, 명령 칩, 상태줄(`자료 128 · 고른 것 2`), 붙여 넣기·끌어다 놓기 영역. 출력의 번호를 눌러 고를 수 있게 한다 |
| 보관함 | 명령 없이 훑어보다 떠오르지 않던 자료를 다시 만난다 | 자동 묶음 칩, 리스트/그리드 전환, 여러 개 골라 `넘기기`, 자세히 보기(요약·출처·고치기·버리기) |
| 설정 | 자주 바꾸지 않는 값 | 연결(MCP), 계정·동기화, 테마(시스템 따름 기본), 넘길 글 기본 형식, 정보. 4~5묶음 이내 [확인⑭] |

**보관함과 터미널을 하나로 잇는 장치:** 보관함에서 고른 항목은 터미널의 `고르기`와 같은 선택 상태를 쓴다(공유 코어의 SelectionStore). 보관함에서 GUI로 한 동작은 터미널 기록에 같은 명령으로 남긴다(예: `고르기 1 3`). 그러면 보관함이 명령어를 가르치는 길이 된다 [추정].

### 3.3 데스크톱과 웹

| | 제안 |
|---|---|
| 데스크톱 사이드바 | 터미널 · 보관함 · 묶음 목록. 창이 좁으면 접힌다 |
| 데스크톱 설정 | macOS는 ⌘, 창 방식, Windows는 사이드바 맨 아래 고정. 같은 웹 빌드에서 OS에 따라 위치만 바꾼다 |
| 커맨드 팔레트 | 따로 두지 않는다. **터미널 입력창이 곧 팔레트**이고 ⌘K는 "입력창으로 이동"으로 쓴다. 입력 방식이 둘이면 차별점이 흐려진다 [추정] |
| 빠른 저장·찾기 | 전역 단축키로 작은 창을 띄운다. 클립보드는 **단축키를 눌렀을 때만** 저장한다(PRD "자동 기록 안 함"과 맞춤) |
| 웹 반응형 | 600px 미만 하단 3탭 · 600~1007px 아이콘 레일 · 1008px 이상 사이드바 + 터미널 + 오른쪽 미리보기 (Material 600, Windows 1008을 섞은 값) [추정] |

### 3.4 터미널 컨셉을 얼마나 살릴지

| 요소 | 웹·데스크톱 | 모바일 |
|---|---|---|
| 명령 직접 입력 | 주 방식 | 보조. 칩과 탭이 주 방식 |
| 명령 칩 | 첫 화면 예시 버튼(F5) | 입력창을 누르면 키보드 위에 늘 나온다(US-7) |
| 이어 쓰기 `\|` | 그대로 | 칩 `찾기 → 넘기기`를 이어 붙이는 방식 [추정] |
| 보관함·설정 모양 | 고정폭 글꼴 + 상자선 | 고정폭 머리말 + OS 기본 리스트·토글(터치 타깃, 접근성) |
| 레트로 효과 | 선택, 움직임 줄이기 설정을 따른다 | 기본 끔 |

## 4. "폴더링 화면"과 PRD 제외 항목

탭은 정의상 "중심 화면"이다. 사용자가 폴더를 만들고 옮기는 보관함을 탭으로 두면 PRD 7절 제외 항목에 그대로 걸리고, 저장할 때 분류를 묻지 않는다는 F1 원칙과도 어긋난다. 세 역할 모두 같은 풀이를 냈다.

| 묶는 축 | 사용자가 하는 일 | 사례 |
|---|---|---|
| 형식별(링크·이미지·PDF·글) | 없음 | Raindrop은 형식 필터를 자동으로 만들고 비면 숨긴다 [2차] |
| 출처별(유튜브·스레드·웹·캡처) | 없음 | — |
| 날짜별(오늘·이번 주·지난달·오래된 것) | 없음 | — |
| 이름 붙인 묶음(F12) | 넘기려고 고른 것에 이름만 붙인다 | 분류가 아니라 "넘기는 단위"라 원칙과 맞다 |
| 저장한 찾기(선택) | 검색어 저장 | mymind Smart Spaces [2차] |
| 상태(요약 중·본문 못 가져옴) | 없음 | US-2 |

하지 않을 것: 폴더 만들기, 끌어다 옮기기, 자동 태그를 보여 주고 편집하게 하기. 자동 주제 묶음은 PRD의 "자동 태그를 내세우지 않는다"와 부딪히므로 열린 질문으로 둔다.

**정책으로 정함(2026-11-26):** [ARC-007](../policies/archive/ARC-007-archive-auto-groups.md). 이 노트를 쓴 뒤 main에 ARC-002(태그는 자동으로 붙여 보여 줌)와 ARC-003(한 단계 묶음이 폴더 역할, 사용자가 넣기·빼기)이 먼저 확정됐다. ARC-007은 둘을 따르면서, 보관함을 형식·출처·날짜·태그 자동 묶음, 묶음, 저장한 찾기로 나눠 보여 준다. 위 표의 "이름 붙인 묶음은 이름만 붙인다"는 ARC-003으로 바뀌었다.

## 5. 기능 우선순위를 가르는 법

### 5.1 판단 규칙: 순간 지도 + 북극성 경로 + 확신 할인

RICE의 도달, Kano 분류, 기회 점수는 모두 사용자 수치가 있어야 한다. 응답 12명에 기기와 AI 사용을 묻지 않은 지금 쓰면 숫자를 지어내게 된다. 그래서 아래 순서로 가른다.

1. 기능을 네 순간(저장할 때 / AI에 요청할 때 / 또 저장할 때 / 대화를 새로 시작할 때) 중 하나에 놓고, 그 순간이 가장 자주 일어날 플랫폼에 배정한다.
2. "저장 → 찾기 → 넘기기" 경로가 그 기능 없이 끊기면 P0, 경로를 빠르게만 하면 P1, 경로 밖이면 이후.
3. 같은 등급 안에서는 근거 수준(확인 > 추정 > 없음)과 노력(개발자 1명)으로 순서를 정한다.
4. 원칙(AI와 경쟁하지 않음, 폴더 관리 화면 중심 금지, 자동 기록 안 함)에 걸리면 점수와 관계없이 뺀다.

### 5.2 네 순간과 플랫폼

| 순간 | 웹 | 모바일 | 데스크톱 | 주로 맡을 곳 · 근거 |
|---|---|---|---|---|
| 저장할 때 | 붙여 넣기·끌어다 놓기 | **공유 시트·스크린샷** | 단축키로 클립보드 저장 | 모바일 · 추정(Pocket 저장의 72%가 모바일이라는 2013년 회사 발언, 설문 캡처 7/12) |
| AI에 요청할 때 | 찾기 → 고르기 → 넘기기 | 보조 | **단축키 창 → 복사**, 연결(F7) | 데스크톱·웹 · 일부 확인(Similarweb 웹 방문 기준 Claude 데스크톱 88.9% [2차㉖]. 국내 ChatGPT 앱 월 2,125만 명이라는 반대 신호 [2차]) |
| 또 저장할 때 | `! 이미 저장됨` | 공유 시트 안에서 같은 알림 | 같음 | 모든 플랫폼(COM-001) |
| 대화를 새로 시작할 때 | `넘기기 <묶음>` | 묶음을 AI 앱으로 보내기 | 단축키 창에서 묶음 복사 | 데스크톱·웹 · 추정 |

### 5.3 플랫폼별 우선순위 (PO 안, 개발 안 반영)

| ID | 기능 | 웹 | 모바일 | 데스크톱 |
|---|---|---|---|---|
| F1 | 저장 | P0 | P0(공유 시트) | P0(단축키·끌어다 놓기) |
| F2 | 요약 | P0 | P0(서버) | P0 |
| F3 | 찾기 | P0 | P0 | P0 |
| F4 | 골라 넘기기 | P0 | P1 | P0 |
| F5 | 첫 사용 안내·명령 칩 | P0 | P0(칩 줄) | P0 |
| F6 | 계정·동기화 | P1 | **P0** | **P0** |
| F7 | 연결(MCP) | P1 | 이후(설정에 안내만) | P1 |
| F8 | 북마크 가져오기 | P1 | 이후 | P1 |
| F12 | 이름 붙인 묶음 | P1 | P1 | P1 |
| F14 | 지우기·고치기 | P0 | P0 | P0 |
| F15 | 뜻으로 찾기 | P1 | P1 | P1 |
| F16 | 이미지 글자 읽기 | P1 | **P0**(스크린샷이 주 입력) | P1 |
| F17 | 가까운 명령 제안 | P1 | 이후(칩이 오타를 줄임) | P1 |
| F18 | 오프라인 저장 | 이후 | P1 | 이후 |
| F20 | `start` 작업 이름으로 모으기 | 이후 | 이후 | P1 후보 |
| F21 | 또 저장 알림 | P0 | P0 | P0 |

F9·F10·F11·F13·F19는 세 플랫폼 모두 이후다. 웹 순서는 데모 필수(F1·F21·F2·F3·F4·F5) → F14 → F12 → F16 → F7이다(개발 안).

## 6. 개발 구조 메모

```
Root (세션·인증, 플랫폼 기능 주입: Clipboard / FilePicker / Share / DeepLink)
 └ Main   ViewState{ tabs:[home, archive, settings], selected, badges }
    ├ Terminal(홈)  ViewState{ lines, input, lastList, pendingChoice }
    ├ Archive       ViewState{ facets, filter, items, cursor, isLoading }
    │   └ ItemDetail
    └ Settings      ViewState{ account, mcp, theme, version }
공유 서비스: SelectionStore · ItemRepository · CommandInterpreter
```

- 코어는 탭 목록과 선택된 탭만 안다. 하단 탭·레일·사이드바 중 무엇으로 그릴지는 뷰가 화면 폭으로 정한다. SwiftUI `sidebarAdaptable`, Compose `NavigationSuiteScaffold`가 같은 방식이다 [확인①⑤].
- 데모 전에는 탭 화면을 만들지 않더라도 **Main RIB은 처음부터 두면** 나중에 다시 짤 일이 없다.
- 보관함에 필요한 API: `GET /items`에 `kind`·`source`·`bundle` 필터, `GET /items/facets`(묶음별 건수), 항목 썸네일. 링크 썸네일(`og:image`)을 서버가 가져오면 SSRF 방어 범위가 넓어진다.
- 연결(F7)은 원격 MCP(HTTP + OAuth 2.1)라 클라이언트 플랫폼과 무관하다 [확인㉗]. 클라이언트는 설정에 연결 주소와 상태만 보여 준다.
- 확인할 스파이크: 모바일에서 Wasm 2.8MB 첫 로딩 실측, WebKitGTK에서 Swift Wasm 동작, iOS Safari 키보드와 한글 Enter.

## 7. 정해야 할 것

### 7.1 정책 후보 (번호는 확정할 때 발급)

새 영역 접두어 MOB(모바일), DSK(데스크톱)를 [정책 목록](../policies/README.md)의 영역 표에 더해야 한다.

| 후보 | 제목 | 한 줄 내용 |
|---|---|---|
| 공통 1 | 플랫폼마다 반드시 있어야 하는 기능 | 저장·또 저장 알림·찾기·넘길 글 복사는 모든 플랫폼에 둔다 |
| 공통 2 | "넘기기"로 세는 동작 | 넘길 글 복사와 연결을 통한 읽기. 모바일에서 다른 앱으로 공유해 보내는 것도 셀지 정한다 |
| 공통 3 | 내 자료 내보내기 | 언제든 전체 자료를 내보낼 수 있다(Pocket 종료 사례 [2차]) |
| 공통 4 | 기기 간 반영 | 다른 기기에서 저장한 자료가 보이기까지의 목표 시간과 충돌 처리 |
| 모바일 1 | 탭 구성 | 탭 3개, 화면 이동에만 쓴다 |
| 모바일 2 | 보관함 구성 | ARC-007로 정함(모든 플랫폼 적용) |
| 모바일 3 | 공유 시트로 저장 | 분류 질문 없이 저장, 결과 한 줄, 자동으로 닫힘. 같은 자료면 COM-001 문구 |
| 모바일 4 | 명령 칩 줄 | 입력창 포커스 때 탭바를 숨기고 칩을 띄운다. 인자 없는 명령은 바로 실행 |
| 데스크톱 1 | 전역 단축키 빠른 찾기 창 | 기본 키, 찾기 → 고르기 → 복사, 창 닫힘 규칙 |
| 데스크톱 2 | 클립보드 저장 | 단축키를 눌렀을 때만 저장. 자동 수집하지 않는다 |

### 7.2 개발 영역: 개발 안을 따른다

개발 판단은 개발 의견을 따르므로 PO 질문으로 두지 않는다. 개발자가 확인하고 ADR로 남긴다.

| 항목 | 개발 안 |
|---|---|
| 플랫폼 순서 | 웹 → 반응형 모바일 웹·PWA → Tauri 데스크톱 → iOS 네이티브 → Android 재검토 |
| 내비게이션 구조(공통 ADR) | 탭 상태는 코어 Main RIB에 두고, 하단 탭·레일·사이드바 중 무엇으로 그릴지는 뷰가 정한다. 데모 전부터 Main RIB을 둔다 |
| iOS | Tauri가 아니라 네이티브 SwiftUI + Swift 공유 코어 + Share Extension |
| Android | Swift SDK가 프리뷰라 iOS 다음에 Swift SDK / WebView / PWA 중 다시 고른다 |
| 데스크톱 | Tauri 전용. global-shortcut, tray, deep-link, updater, single-instance 플러그인. 서명·업데이트 방식은 개발자가 정한다 |
| MCP | 원격(HTTP + OAuth)만. 로컬 stdio는 이후 |
| 데스크톱 전역 단축키 기본 키 | 개발자가 정한다 |
| 스파이크 | 모바일 Wasm 첫 로딩 실측, WebKitGTK에서 Swift Wasm, iOS Safari 키보드와 한글 Enter |

### 7.3 PO가 답할 질문 (서비스 동작·문구·지표)

1. ~~보관함을 "자동 묶음만, 사용자 폴더 없음"으로 정책에 적을 것인가~~ → ARC-007로 정함
2. ~~설정을 탭으로 둘 것인가, 오른쪽 위 아이콘으로 둘 것인가~~ → 탭으로 정함(MOB-001)
3. 모바일에서 다른 앱으로 공유해 보낸 것도 북극성의 "넘기기"로 셀 것인가
4. ~~보관함에 자동 주제 묶음을 보여 줄 것인가~~ → 태그 자동 묶음을 보여 준다(ARC-002, ARC-007)
5. 모바일 홈은 입력창 중심인가, 칩·버튼 중심인가
6. 보관함 기본 보기는 리스트인가 그리드인가(이미지·캡처 저장 7/12)
7. 데스크톱 트레이 아이콘을 기본으로 켤지

## 8. 근거의 한계

- 설문은 저장하는 기기와 AI 작업 기기를 묻지 않았다(STATE 공백 8). "모바일은 저장, 데스크톱은 AI 작업" 나눔은 **추정**이다.
- 국내에서 생성형 AI를 PC와 휴대폰 중 어디서 쓰는지 나눈 공개 수치는 찾지 못했다.
- Material 3 원문(m3.material.io)은 열지 못했고, 비교한 앱 화면은 직접 보지 않았다. 시안 전에 실제 앱으로 확인한다.
- 12/1 발표는 웹 데모 하나로 하고, 플랫폼 이야기는 "입구와 출구" 비전 한 장과 모바일 탭 시안 한 장으로 둔다(PO 제안).

## 출처

① [Apple HIG Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars), [SwiftUI sidebarAdaptable](https://developer.apple.com/documentation/swiftui/tabviewstyle/sidebaradaptable)
② [Android layout and navigation patterns](https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-and-nav-patterns)
③ [Apple HIG Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
④ [Microsoft NavigationView](https://learn.microsoft.com/en-us/windows/apps/design/controls/navigationview)
⑤ [Android window size classes](https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes), [Build adaptive navigation](https://developer.android.com/develop/adaptive-apps/guides/build-adaptive-navigation)
⑥ [web.dev PWA app design](https://web.dev/learn/pwa/app-design)
⑦ [Apple HIG The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)
⑧ [VS Code user interface](https://code.visualstudio.com/docs/getstarted/userinterface)
⑨ [Apple HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
⑩ [Android accessibility](https://developer.android.com/guide/topics/ui/accessibility/apps)
⑪ [WCAG 2.2 Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)
⑫ [Apple HIG Settings](https://developer.apple.com/design/human-interface-guidelines/settings)
⑬ [Readwise Reader navigation FAQ](https://docs.readwise.io/reader/docs/faqs/navigation)
⑭ [Microsoft app settings guidelines](https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings)
⑮ [Chrome Web Share Target](https://developer.chrome.com/docs/capabilities/web-apis/web-share-target)
⑯ [WebKit bug 194593](https://bugs.webkit.org/show_bug.cgi?id=194593)
⑰ [Android receiving shared data](https://developer.android.com/training/sharing/receive)
⑱ [Tauri plugins](https://v2.tauri.app/plugin/), [Tauri global shortcut](https://v2.tauri.app/plugin/global-shortcut/)
⑲ [WebKit async clipboard](https://webkit.org/?p=10855)
⑳ [UIPasteControl](https://developer.apple.com/documentation/uikit/uipastecontrol)
㉑ [Tauri webview versions](https://v2.tauri.app/reference/webview-versions/)
㉒ [Tauri 2.0 RC 공지](https://v2.tauri.app/blog/tauri-2-0-0-release-candidate/)
㉓ [Swift SDK for Android nightly](https://swift.org/blog/nightly-swift-sdk-for-android/)
㉔ [Chrome viewport resize behavior](https://developer.chrome.com/blog/viewport-resize-behavior)
㉕ [WebKit bug 165004](https://bugs.webkit.org/show_bug.cgi?id=165004)
㉖ [OfficeChai, Similarweb 인용](https://officechai.com/ai/the-split-between-desktop-and-mobile-traffic-for-top-ai-models)
㉗ [MCP authorization spec](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization)

그 밖의 2차 자료: [Raindrop 모바일](https://help.raindrop.io/mobile-app), [mymind 공유 패널](https://mymind.com/new-the-ios-share-panel), [Raycast iOS 공유 확장](https://manual.raycast.com/ios/share-extension), [Linear 모바일](https://linear.app/changelog/2024-09-19-introducing-linear-mobile), [Mozilla Pocket 종료 안내](https://support.mozilla.org/ml/kb/future-of-pocket)
