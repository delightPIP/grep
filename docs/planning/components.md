# 공통 컴포넌트

- 작성일: 2026-11-26
- 상태: 시안 기준표. 색·글꼴·부품을 한 곳에서 보는 곳은 [그렙 웹 화면 시안](https://claude.ai/artifact/J6XT7UcSDvuPC2quoSsaRm)의 **4. 공통 컴포넌트** 페이지다. 이 문서는 그 페이지의 목록과 고치는 규칙을 적는다
- 근거: 디자인 시스템 "그렙 터미널"(시안 안의 `ds/grep/` 사본: `tokens.json`, `tokens.css`, `components/bundle.js`, `components/bundle.css`)과 시안의 모든 화면 파일을 직접 조회해 만들었다

## 1. 고치는 규칙

1. 부품은 원본 파일 한 곳에만 있다. 화면은 원본을 가져다 쓴다(`Grep.*`는 디자인 시스템 부품, 나머지는 시안의 `<이름>.dc.html`을 `dc-import`로).
2. 부품 모양을 바꾸려면 원본만 고친다. 쓰는 화면은 모두 함께 바뀐다. 화면 파일 안에서 부품을 다시 그리지 않는다.
3. 같은 모양을 두 화면 이상에서 쓰게 되면 부품으로 뺀다.
4. 색은 토큰(`var(--이름)`)으로만 쓴다. 토큰 밖 색은 4절 표에 있는 것뿐이다.
5. 전파는 2026-11-26에 시험했다: UiButton 한 파일을 바꾸자 모바일·데스크톱·웹 화면의 버튼이 함께 바뀌었고, 되돌리자 함께 돌아왔다.
6. 수정 요청은 4. 공통 컴포넌트 페이지의 그 부품 카드에 댓글로 남긴다. 카드마다 이름, 고칠 곳, 속성, 쓰는 화면이 있다.

## 2. 페이지 구성

| 보드 | 내용 |
|---|---|
| C0 읽는 법 | 수정 요청하는 법, 화면 안에 남은 것(부품 아님), 원칙 |
| C1 색 | 토큰 14개의 어두운·밝은 값, surface 위 글자 대비, 두 테마 비교, 토큰 밖 색 |
| C2 글꼴 | mono·read 두 가족, 글자 크기 9가지, 플랫폼별 글자 규칙 |
| C3 간격·모서리·아이콘·움직임 | 간격 5단계, 모서리 2가지, 아이콘 5개, 저절로 닫히는 시간 |
| C4 터미널 출력 | Prompt, Line(ALERT), Hint, Next, ResultList, Preview, HelpList, ManPage |
| C5 입력·창·확인 | Window, Input, Confirm(POPUP 대신), StatusBar·Key, Chip, DropZone |
| C6 두더지 | Banner, Mascot, Burrow |
| C7 알림·확인·시트 | ALERT·POPUP·SHEET·TOAST·버튼을 플랫폼마다 무엇으로 쓰는지(5절), UiButton(quiet 포함), UiCard, UiSettingRow |
| C8 모바일 | MTopBar, MList, MCommandBar, MTabBar, MSheet(메뉴·입력·확인), MPickBar, MShareSheet, MOtherApp, MOsShareSheet, UiChoiceList |
| C9 데스크톱 | DWallpaper, DAppWindow, DMole, DMoleHover, DDropHint, DDropTarget, DTaskbar, DTitleBar, DTrayMenu, 로그 카드 |
| C10 넓은 웹 | WSidebar, WRail, WConsentCard, ItemDetailPanel, ItemDetail, UiSettingRow |
| 부품 원본 | 아래 3절 플랫폼 부품 27개의 원본 아트보드 |

## 3. 부품 목록

쓰는 화면 수는 2026-11-26 시안 파일을 조회한 값이다. 부품 안의 부품까지 따라가 센다(예: ItemDetailPanel 안의 UiButton은 10 · 28 · M6에 셈). 그 부품을 고치면 바뀌는 화면 수와 같다.

### 디자인 시스템 부품 (`ds/grep/components/bundle.js`)

| 부품 | 쓰는 화면 | 부품 | 쓰는 화면 |
|---|---|---|---|
| Grep.Line | 42 | Grep.Mascot | 20 |
| Grep.Input | 38 | Grep.Burrow | 11 |
| Grep.Prompt | 35 | Grep.Banner | 11 |
| Grep.Hint | 33 | Grep.Confirm | 3 |
| Grep.Window | 27 | Grep.Chip | 2 |
| Grep.ResultList | 25 | Grep.ManPage | 2 |
| Grep.Next | 23 | Grep.DropZone | 1 |
| Grep.HelpList | 16 | Grep.Key | 1 |
| Grep.Preview | 15 | | |

### 플랫폼 부품 (시안의 `.dc.html`, 27개)

| 부품 | 무엇 | 플랫폼 | 쓰는 화면 |
|---|---|---|---|
| UiButton | 버튼(primary · secondary · danger · ghost · quiet, 32·44·48px, 공유 아이콘·개수) | 모두 | 24 |
| UiCard | 카드형 알림(안내, 로그 카드, 공유 시트 결과) | 모바일·데스크톱 | 11 |
| UiSettingRow | 설정 한 줄 | 모두 | 10 |
| UiChoiceList | 낱말 선택지(누르면 그 낱말을 친 것과 같음, COM-007) | 모바일·터치 | 1 |
| ItemDetailPanel | 자세히 보기 칸(보관함 오른쪽, 휴대폰은 전체) | 웹·모바일 | 3 |
| ItemDetail | 자세히 보기 블록(터미널 출력 안) | 웹 | 1 |
| MTopBar | 휴대폰 머리줄(뒤로 가기 포함) | 모바일 | 12 |
| MCommandBar | 명령 버튼 4칸과 입력줄(＋ 올리기 포함) | 모바일 | 11 |
| MTabBar | 하단 탭 3개(MOB-001) | 모바일 | 10 |
| MList | 휴대폰 결과 목록(누름·고르기·줄 메뉴) | 모바일 | 9 |
| MSheet | 시트(메뉴 · 입력 · 확인) | 모바일 | 8 |
| MShareSheet | 다른 앱에서 공유했을 때 그렙 시트 | 모바일·iOS | 8 |
| MOtherApp | 다른 앱 화면 자리 | 모바일 | 8 |
| MPickBar | 고른 것 줄(칩 · 넘기기 · 모두 해제) | 모바일 | 2 |
| MOsShareSheet | OS 공유 시트 자리 | 모바일 | 1 |
| DWallpaper | 바탕화면 | 데스크톱 | 11 |
| DTaskbar | 작업 표시줄과 트레이 두더지 | 데스크톱 | 11 |
| DMole | 오른쪽 아래 두더지 땅굴(Grep.Burrow를 감쌈) | 데스크톱 | 7 |
| DAppWindow | 다른 앱 창 자리 | 데스크톱 | 5 |
| DTitleBar | 창 제목줄 | 데스크톱 | 3 |
| DDropHint | 끌고 올 때 두더지 위 안내 글 | 데스크톱 | 2 |
| DDropTarget | 놓는 곳(점선 칸) | 데스크톱 | 1 |
| DMoleHover | 두더지에 마우스 올림 카드 | 데스크톱 | 1 |
| DTrayMenu | 트레이 메뉴(DSK-001) | 데스크톱 | 1 |
| WSidebar | 넓은 웹 사이드바(누르는 동작 포함) | 웹 1008px 이상 | 2 |
| WRail | 아이콘 레일 | 웹 600~1007px | 1 |
| WConsentCard | AI 도구 연결 승인 카드 | 웹 | 1 |

## 4. 토큰 밖 색

| 색 | 어디 | 판단 |
|---|---|---|
| 두더지 팔레트 10색 | Mascot, Burrow | 두더지 전용, 테마와 무관(디자인 시스템 9절) |
| `#3a4350`, `#1d2128` | 데스크톱 바탕화면, 작업 표시줄 | OS 화면 자리. DWallpaper · DTaskbar에 모음 |
| `#f4f4f2` 계열 | 다른 앱·브라우저 자리, PDF 미리보기 자리 | 그렙이 그리지 않는 곳의 자리 표시. MOtherApp · MOsShareSheet · DAppWindow · ItemDetailPanel에 모음 |
| `rgba(0,0,0,.55)` | 모바일 시트 뒤 | iOS가 정함. MSheet 한 곳에 모음 |

## 5. ALERT · POPUP · SHEET 플랫폼 대응

| 요소 | 웹(터미널) | 모바일 | 데스크톱 |
|---|---|---|---|
| ALERT | Grep.Line 한 줄(✓ · ! ✗) | Grep.Line, 화면 밖 결과는 UiCard | 빠른 창은 Grep.Line, 두더지 옆은 UiCard 로그 카드 |
| POPUP(확인) | 두지 않음. 물음 줄 + 낱말 답(COM-007) | MSheet 확인형 | 빠른 창은 웹과 같음 |
| SHEET | 두지 않음(입력은 출력 안 칸, 20 고치기) | MSheet 메뉴형·입력형·선택형 | 두지 않음 |
| TOAST | 두지 않음 | 공유 시트 결과 2초 | 로그 카드 3초, 복사 링크 알림 8초 |
| 버튼 | 터미널 안은 Next 칩·번호, 밖은 UiButton | UiButton 44px(시트 48px) | UiButton 32px |

## 6. 화면 안에 남은 것 (부품 아님)

버튼·시트·머리줄·사이드바·레일·카드·바탕은 모두 부품으로 뺐다(2026-11-26). 화면 파일에 남은 것은 그 화면의 배치와 내용이다. 아래는 한 화면에서만 쓰는 모양이라 화면에 둔다. 두 화면 이상에서 쓰게 되면 부품으로 뺀다.

- M2 명령 버튼 설명판의 버튼 칸(설명이 붙은 56px 칸)
- 10 보관함 이미지 묶음 보기의 그림 칸
- D5 체험판의 번호 붙은 동작 버튼(체험용)
- 텍스트 링크(‹ 보관함, → 더 보기, 휴지통 n건): 부품이 아니라 글자 색 규칙(C1 `command`)을 따른다
