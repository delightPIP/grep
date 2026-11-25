# 디자인 레퍼런스

조사일 2026-11-25. 컨셉 "터미널 느낌의 화면과 쉬운 명령어 몇 개로, 개발자가 된 듯한 경험으로 자료를 아카이브에 모으고 꺼낸다"([기획서](PRD.md) 6절)에 쓸 참고 자료다.

읽는 법:

- "열람"은 공식 페이지를 직접 열어 글을 읽은 것이다. "검색"은 검색 결과 요약만 본 것이라 실재와 내용을 확인하지 못했다.
- 페이지를 글로 바꿔 읽었기 때문에 화면 모양, 색, 글꼴은 대부분 눈으로 보지 못했다. 시안을 만들기 전에 각 링크를 직접 열어 화면을 확인해야 한다.
- 이 조사는 재검증(evidence-verifier)을 거치지 않았다.
- "가져올 점"은 조사에서 나온 제안이며 결정이 아니다.

## 먼저 볼 것: 조사에서 나온 설계 방향 (제안)

1. 치는 것과 고르는 것을 함께 둔다. 일반 사용자에게 명령어를 쓰게 한 제품(Slack, Notion, Telegram)은 모두 입력하면 목록이 뜨고 눌러서 고를 수 있게 했다. 명령줄은 기억해 내야 하고 메뉴는 알아보면 된다는 차이 때문이다(NN/g).
2. 휴대폰에서는 버튼과 공유가 먼저다. 명령 바 제품인 Raycast도 iOS에서는 자주 쓰는 동작을 올린 홈 화면, 공유 시트, 키보드로 옮겼다. 모바일 터미널 앱은 키보드 위에 추가 키 줄을 둔다.
3. 저장 한 건을 블록 하나로 본다. Warp는 명령과 출력을 한 덩어리로 묶고 덩어리마다 복사·공유를 붙인다. 그렙에서는 "저장 한 건 = 블록 하나, 블록마다 복사와 넘기기"로 옮길 수 있다.
4. 출력 끝에 다음에 칠 명령을 알려 준다. 빈 화면에는 예시 명령을, 오타에는 가장 가까운 명령을 제안한다(clig.dev).
5. 밝은 화면을 함께 설계한다. 정상 시력에서는 밝은 바탕이 읽기 성적이 좋고 글자가 작을수록 차이가 커진다는 정리가 있다(NN/g). 터미널이라고 어두운 화면만 두지 않는다.
6. 긴 글은 고정폭 글꼴로 두지 않는 쪽을 검토한다. 고정폭은 명령어와 목록에, 요약 본문은 읽기 쉬운 글꼴에 쓰는 방법이 있다. 고정폭이 읽기에 불리하다는 주장과 차이가 작다는 연구가 엇갈린다.
7. 한글 고정폭 글꼴은 따로 골라야 한다. 영문 고정폭 글꼴 대부분은 한글 포함 여부를 확인하지 못했다.

기획서와 부딪히는 지점:

- 명령어 이름: 기획서 8절의 예시 이름 `grep`, `ls`는 유닉스를 모르면 뜻을 알 수 없다. "명령 이름은 동사로 시작하고 찾아봐야 아는 이름을 피한다"는 지침(NN/g)과 어긋난다. 반면 "개발자가 된 듯한 경험"에는 진짜 명령어 이름이 재료다. 쉬운 이름을 별칭으로 함께 두는 방법이 있다(Superhuman은 별칭을 정식 이름 옆에 보여 준다). 화면 시안 검증에서 정한다.
- 비슷한 서비스: 터미널 느낌의 화면으로 일반 사용자가 링크·파일·메모를 저장·검색하고 AI 도구에 넘기는 서비스는 찾지 못했다. 가장 가까운 것은 1 Bit Notes(아래 5번)다. 검색 2회와 앱스토어 페이지 범위의 결과이고 Android·웹·국내는 따로 찾지 못했다. 없다는 증명이 아니다(STATE 13절 공백 16).

## 1. 터미널 느낌을 제품에 쓴 사례

| 이름 | 무엇 | 가져올 점 | 조심할 점 | 대상 | 확인 |
|---|---|---|---|---|---|
| [terminal.shop](https://www.terminal.shop/) | `ssh` 한 줄로 원두 커피를 주문하는 가게 | 첫 화면 전체를 "복사할 명령어 한 줄"로 만드는 구성. 메뉴 이름을 명령어·파일명처럼 짓는 방식 | 진짜 SSH가 필요해 비개발자는 못 씀 | 개발자 | 열람 |
| [Warp 블록](https://docs.warp.dev/terminal/blocks) | 명령과 출력을 한 덩어리로 묶는 터미널 | 덩어리 단위의 복사, 다시 실행, 공유, 북마크, 검색 | 지금 홈페이지는 에이전트 개발 플랫폼으로 소개 | 개발자 | 열람 |
| [Charm, gum](https://github.com/charmbracelet/gum) | 터미널용 도구 모음. gum은 고르기·입력·걸러내기 조각 | "명령어를 치면 고르는 화면이 뜬다"의 재료: 목록에서 고르기, 치는 대로 걸러내기, 예·아니오 확인, 진행 표시. 장난스러운 말투 | — | 개발자 | 열람 |
| [opencode](https://opencode.ai/) | 터미널·데스크톱·모바일에서 도는 코딩 에이전트 | 같은 작업을 터미널, 데스크톱, 휴대폰에서 이어 쓰는 구성. 되돌리기 명령 | 코딩 전용 | 개발자 | 열람 |
| [Claude Code](https://code.claude.com/docs/en/overview) | 터미널·데스크톱·웹·모바일에서 도는 코딩 에이전트 | 슬래시 명령으로 기능을 여는 방식. 문서가 흔한 오류 문구를 그대로 적고 해결법을 붙이는 방식 | 명령 목록이 길어 처음 쓰는 사람에게는 많음 | 개발자 | 열람 |
| [Ghostty](https://ghostty.org/docs) | macOS·Linux용 터미널 | 설정 없이 바로 동작. 밝은 모드와 어두운 모드에 테마를 따로 지정 | Windows 미지원(문서 기준) | 개발자 | 열람 |
| [Poolsuite FM](https://apps.apple.com/us/app/poolsuite-fm/id1514817810) | 레트로 미감의 음악 앱(iOS, macOS) | 레트로 컴퓨팅 미감이 일반 사용자에게 받아들여진 사례. 테마 바꾸기 | 터미널이 아니라 레트로 화면 | 일반 | 열람 |
| Buttons CLI, RetroTerminal | 일반인용 터미널 앱, 레트로 터미널 모양의 AI 챗봇이라고 소개됨 | 명령어를 버튼으로도 내놓는 방향 | 실재와 현황 확인 못 함 | 일반 | 검색 |

## 2. 명령어 입력을 쉽게 만든 패턴

| 이름 | 가져올 점 | 조심할 점 | 확인 |
|---|---|---|---|
| [Superhuman의 명령 팔레트 글](https://blog.superhuman.com/how-to-build-a-remarkable-command-palette/) | 어디서나 같은 단축키로 열림. 명령 옆에 단축키를 보여 줘 쓰면서 배우게 함. 모든 동작을 명령·버튼·단축키 세 길로 제공. 대소문자 무시, 오타 허용, 별칭. 지금 화면에 맞는 명령을 위로 | 컴퓨터 키보드가 전제 | 열람 |
| [Slack 슬래시 명령](https://slack.com/help/articles/201259356-Slash-commands-in-Slack) | `/`를 치거나 아이콘을 누르면 목록이 뜨고 최근 쓴 것이 위. 인자가 필요한 명령은 목록에 형식을 보여 줌 | 일부 명령은 모바일에서 안 됨. 플랫폼마다 명령이 다르면 헷갈림 | 열람 |
| [Notion 슬래시 명령](https://www.notion.com/help/keyboard-shortcuts) | 짧은 별칭. 명령을 묶음으로 나눠 보여 줌 | 명령이 수십 개라 "쉬운 명령어 몇 개"와 규모가 다름 | 열람 |
| [Telegram 봇 명령](https://core.telegram.org/bots/features) | `/`를 치면 명령과 설명 목록. 입력창 옆 메뉴 버튼으로 치지 않고 고름. 대화 속 명령을 누르면 다시 실행. 처음에는 시작 버튼. 공통 명령 `/start`, `/help`, `/settings` | 고르는 즉시 전송되는 방식은 인자가 필요한 명령에 맞지 않음 | 열람 |
| [Discord 명령(개발자 문서)](https://docs.discord.com/developers/interactions/application-commands) | 인자마다 종류가 있어 입력 중에 검증. 고정 선택지와 자동 완성 | 사용자 화면은 확인 못 함 | 열람 |
| [VS Code 명령 팔레트](https://code.visualstudio.com/docs/getstarted/userinterface) | 한 곳에서 모든 기능에 접근. `?`를 치면 쓸 수 있는 명령 종류 안내 | 개발자용 | 열람 |
| [Raycast](https://www.raycast.com/) | 키워드를 치면 저장해 둔 글이 들어가는 Snippets, 링크 바로가기 Quicklinks. "키워드 하나로 저장물 꺼내기"의 직접 사례 | Mac 중심 | 열람 |
| [Command Line Interface Guidelines](https://clig.dev/) | 인자 없이 실행하면 설명과 예시를 보여 줌. 도움말은 예시 먼저. 출력 끝에 다음에 칠 명령 제안. 오타는 고친 명령을 제안하되 묻고 실행. 오류는 해결 방법으로 다시 써서 보여 줌. 빨간색은 아껴 씀 | 개발자용 지침 | 열람 |
| [NN/g, UI Copy](https://www.nngroup.com/articles/ui-copy/) | 명령 이름은 동사로 시작, 짧고 분명하게. 같은 동작은 어디서나 같은 이름 | 유닉스식 이름과 어긋남(위 "부딪히는 지점") | 열람 |
| Linear 명령 메뉴 | 선택한 항목에 동작 실행, 단축키 연습 방식이 있다고 함 | 문서 주소가 열리지 않아 지금 동작 확인 못 함 | 검색 |

## 3. 휴대폰에서 명령어를 쓰게 하는 방법

| 이름 | 가져올 점 | 조심할 점 | 확인 |
|---|---|---|---|
| [Raycast for iOS](https://www.raycast.com/ios) | 명령 바 대신 자주 쓰는 동작을 올린 홈 화면. 공유 시트에서 불러 선택한 글에 명령 실행. 키보드로 어디서나 저장한 글 넣기. 위젯·잠금 화면 진입. "공유로 저장"과 가장 가까운 구조 | 컴퓨터의 타이핑 중심 화면을 휴대폰에서는 사실상 내려놓은 사례 | 열람 |
| [Termius](https://termius.com/) | 자주 쓰는 명령을 저장해 한 번 눌러 실행. 명령·기록 자동 완성. 특수 키를 담은 키보드 | 흔들기 같은 제스처는 찾기 어려움 | 열람 |
| [Blink Shell](https://blink.sh/) | 키보드 위 보조 키 줄. 밀어서 전환, 벌려서 글자 크기 조절 | 메뉴가 없어 제스처를 모르면 못 씀 | 열람 |
| [Termux](https://github.com/termux/termux-app) | 키보드 위 추가 키 한 줄이 기본으로 켜짐 | 설정이 파일 편집 방식이라 일반 사용자에게 맞지 않음. 세부는 비공식 안내 기준 | 열람 |
| [1 Bit Notes](https://apps.apple.com/us/app/id6756234025) | 터미널 모양 앱에 공유 확장, Siri·단축어, 탭 자동 완성을 더한 사례 | 아래 5번 참고 | 열람 |

## 4. 시각 언어의 재료

화면 기본 모습:

| 이름 | 확인한 것 | 확인 못 한 것 | 확인 |
|---|---|---|---|
| [Windows 터미널 색 구성](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/color-schemes) | 기본 포함: Campbell, Campbell Powershell, Vintage, One Half Dark·Light, Tango Dark·Light. Campbell은 배경 `#0C0C0C`, 글자 `#CCCCCC`, 커서 `#FFFFFF`, 초록 `#13A10E`. 색 구성을 16색과 배경·글자·커서·선택 영역으로 정의하는 형식 | 색 조합별 명암 대비(직접 계산 필요) | 열람 |
| [macOS 터미널 프로필](https://support.apple.com/guide/terminal/profiles-change-terminal-windows-trml107/mac) | 프로필이 색·글꼴·배경·커서 모양을 묶어 관리 | 기본 프로필 이름, 기본 글꼴, 색 값, 프롬프트 형태 | 열람 |

색 구성:

| 이름 | 내용 | 조심할 점 | 확인 |
|---|---|---|---|
| [Catppuccin](https://catppuccin.com/palette/) | 밝은 Latte(바탕 `#eff1f5`, 글자 `#4c4f69`)와 어두운 Mocha(바탕 `#1e1e2e`, 글자 `#cdd6f4`) 등 네 가지. 밝은 테마와 어두운 테마가 같은 이름 체계 | 라이선스 확인 못 함 | 열람 |
| [Dracula](https://draculatheme.com/spec) | 배경 `#282A36`, 글자 `#F8F8F2`, 초록 `#50FA7B`, 보라 `#BD93F9` 등 | 주석색 `#6272A4`를 본문에 쓰면 대비가 부족할 수 있음. 라이선스 확인 못 함 | 열람 |
| [Solarized](https://ethanschoonover.com/solarized/) | 16색. 밝은 모드와 어두운 모드가 같은 명도 차이를 갖도록 설계 | 일부러 대비를 낮춘 설계라 기준 미달 조합이 있을 수 있음 | 열람 |
| [Tokyo Night](https://github.com/folke/tokyonight.nvim) | 네 가지 변형, Apache-2.0 | 색 값 확인 못 함 | 열람 |
| [Gruvbox](https://github.com/morhetz/gruvbox) | 레트로 느낌의 색 구성, 밝은·어두운 모드, MIT/X11 | 색 값 확인 못 함 | 열람 |

글꼴:

| 이름 | 한글 | 라이선스 | 메모 | 확인 |
|---|---|---|---|---|
| [D2Coding](https://github.com/naver/d2codingfont) | 한글 11,172자. 한글 폭이 영문의 정확히 2배 | OFL | 페이지에 최신 버전 1.4.0, 2026-10-03으로 표시됨. 릴리스 페이지에서 다시 확인 권장 | 열람 |
| [Sarasa Gothic](https://github.com/be5invis/Sarasa-Gothic) | 한국어 변형 있음 | SIL OFL 1.1 | Inter, Iosevka, Source Han Sans 합성. 파일 용량이 클 수 있어 웹 로딩 확인 필요 | 열람 |
| [Monoplex KR](https://github.com/y-kim/monoplex) | IBM Plex Mono와 IBM Plex Sans KR 합성 | 확인 못 함 | — | 열람 |
| [나눔고딕코딩](https://github.com/naver/nanumfont) | 있음 | OFL | 2016년 이후 갱신 없음 | 열람 |
| [Cascadia Code·Mono](https://learn.microsoft.com/en-us/windows/terminal/cascadia-code) | 확인 못 함 | SIL OFL | Windows 터미널 기본 글꼴은 Cascadia Mono | 열람 |
| [JetBrains Mono](https://www.jetbrains.com/lp/mono/) | 확인 못 함 | OFL-1.1 | 소문자 높이를 키운 설계 | 열람 |
| [Geist Mono](https://vercel.com/font) | 확인 못 함 | SIL OFL 1.1 | 같은 계열에 제목용으로 쓸 만한 Geist Pixel | 열람 |
| [Commit Mono](https://commitmono.com/) | 확인 못 함 | SIL OFL 1.1 | 글자 폭에 따라 간격을 조정해 단어가 덩어리로 읽히게 함. 고정폭 가독성 문제의 완화책 | 열람 |
| Berkeley Mono | — | — | 페이지 열람 실패 | 실패 |

## 5. 이미 있는 비슷한 것

| 이름 | 무엇 | 가져올 점 | 그렙과 다른 점 | 대상 | 확인 |
|---|---|---|---|---|---|
| [1 Bit Notes](https://apps.apple.com/us/app/id6756234025) | 초록 글자와 어두운 배경의 터미널 풍 노트 앱(iPhone, iPad, Mac). 내장 셸에 찾기·정렬·내보내기 명령, 명령 기록, 탭 자동 완성, 장난 명령. 공유 확장, 위젯, iCloud 동기화 | 이 컨셉과 가장 가까운 사례. 장난 명령으로 재미를 주는 방식 | 노트 전용. 링크·파일 보관과 AI 도구로 넘기기는 페이지에 없음. Android·웹·Windows 없음. 평가 5건이라 수요의 증거로는 약함 | 일반 | 열람 |
| [Terminal Notes](https://apps.apple.com/ca/app/terminal-notes/id6745132734) | iPhone용 노트·리마인더 앱. 브라운관 주사선, DOS식 프롬프트, 호박색 테마 | 겉모습 참고 | 터미널은 겉모습뿐이고 치는 명령은 확인 못 함 | 일반 | 열람 |
| [shiori](https://github.com/go-shiori/shiori) | 북마크 관리자. 명령줄과 웹 화면을 둘 다 제공 | 같은 보관함을 명령줄과 일반 화면 두 방식으로 여는 구성 | 직접 서버에 설치해 쓰는 방식 | 개발자 | 열람 |
| [buku](https://github.com/jarun/buku) | 명령줄 북마크 관리자 | 주소만 주면 제목·설명을 채우는 저장 동작. 중복 거부 | 한 글자 옵션은 일반 사용자에게 맞지 않음 | 개발자 | 열람 |
| [nb](https://github.com/xwmx/nb) | 명령줄과 로컬 웹 방식의 노트·북마크 도구 | — | 명령 예시 확인 못 함 | 개발자 | 열람(소개만) |
| My Line Notes, Dos Notes, Hacker Notes Pro, DevNoty 등 | 터미널·레트로 풍 노트 앱이라고 소개됨 | — | 실재와 내용 확인 못 함 | — | 검색 |

## 6. 조심할 점

| 자료 | 내용 | 컨셉에 주는 뜻 | 방향 | 확인 |
|---|---|---|---|---|
| [NN/g, Recognition vs. Recall](https://www.nngroup.com/articles/recognition-and-recall/) | 명령줄은 기억해 내기에, 메뉴는 알아보기에 기댄다. 대책: 기능을 보이게 두기, 최근 항목 보여 주기, 제안으로 "쓰기"를 "고르기"로 바꾸기 | 명령어만 있는 화면은 처음 쓰는 사람에게 불리. 제안과 버튼이 필요 | 반대 | 열람 |
| [NN/g, Dark Mode vs. Light Mode](https://www.nngroup.com/articles/dark-mode/) | 정상 시력에서는 밝은 바탕이 읽기 성적이 좋고 글자가 작을수록 차이가 큼. 일부 저시력에는 어두운 바탕이 유리. 어두운 모드는 기본값이 아니라 선택지로 | 밝은 테마를 함께 설계 | 반대 | 열람 |
| [WCAG 2.2, 명암 대비](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) | 본문 4.5:1, 큰 글자 3:1. 가는 글꼴은 더 높게 권장 | 터미널 테마의 흐린 회색·주석색·파랑을 본문에 쓸 때 직접 점검 | 기준 | 열람 |
| [Practical Typography, Monospaced fonts](https://practicaltypography.com/monospaced-fonts.html) | 본문에 고정폭을 쓸 이유가 없다는 입장. 읽기 어렵고 가로 공간을 더 차지 | 요약 본문에는 다른 글꼴을 검토 | 반대 | 열람 |
| 고정폭과 가변폭 읽기 속도 연구 | 가변폭이 약간 빠르지만 차이가 작고 연구마다 엇갈린다고 함 | 고정폭이 반드시 불리하다고 단정하지 않는다 | 엇갈림 | 검색(원문 미열람) |
| [UX Magazine, Command Lines: Alive & Kicking](https://uxmag.com/articles/command-lines-alive-kicking) | 깜빡이는 커서는 할 수 있는 일을 알려 주지 않는다는 약점을 인정. 입력 중 결과 미리 보기, 자연어에 가까운 문법, 동의어로 보완하면 쓸 만하다는 주장 | 보완책 목록으로 쓸 수 있음. 2010년 글 | 조건부 찬성 | 열람 |
| [NN/g, AI: First New UI Paradigm in 60 Years](https://www.nngroup.com/articles/ai-paradigm/) | 초기 명령줄은 지금 상태를 보여 주지 않았다는 지적. 자연어 프롬프트도 글로 의도를 써야 하는 장벽이 있다고 봄 | 명령을 실행한 뒤 결과와 상태를 반드시 보여 준다. 짧은 정해진 명령어가 긴 프롬프트보다 쉬울 수 있다는 해석의 여지 | 양쪽 | 열람 |

찾지 못한 것: 터미널 미감이 비개발자에게 주는 진입 장벽만을 직접 다룬 글이나 사용자 조사. 위 자료는 간접 근거다(STATE 13절 공백 15).

## 다음에 할 것

- 2차 조사(2026-11-25): CLI 도구에서 빌려올 화면 조각은 [디자인 레퍼런스 2](design-references-cli.md)에 정리했다. 색 명암 대비 계산도 거기 있다.

- 위 링크를 직접 열어 화면을 보고, 시안에 쓸 장면을 모은다(이번 조사는 글만 읽었다).
- 1 Bit Notes를 직접 써서 명령어 수, 처음 화면, 휴대폰에서의 입력 방식을 확인한다.
- 색 조합 후보의 명암 대비를 계산한다.
- 한글 고정폭 글꼴 후보(D2Coding, Sarasa Gothic, Monoplex KR)를 같은 화면에 놓고 비교한다. 웹에서의 용량도 본다.
- Android, 웹, 국내에서 터미널 느낌의 저장 서비스가 있는지 더 찾는다.
