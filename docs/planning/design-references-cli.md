# 디자인 레퍼런스 2: CLI 도구에서 빌려올 화면 조각

조사일 2026-11-25. PO가 "명령 프롬프트, 터미널 같은 CLI 도구들의 디자인을 차용한다"고 정했다. 화면 시안을 만들기 전에 차용할 요소를 넓게 모았다. 1차 조사인 [디자인 레퍼런스](design-references.md)를 보완하며, 거기서 다룬 항목은 새로 알게 된 것만 적었다.

읽는 법:

- 세 갈래(AI 코딩 CLI·TUI 앱 / 고전 셸·프롬프트·레트로 / 웹·모바일 터미널풍 제품)로 나눠 조사하고, 출처별이 아니라 **화면 조각별**로 다시 묶었다.
- "열람"은 공식 페이지나 README를 직접 열어 글을 읽은 것이다. "검색"은 검색 결과 요약만 본 것이다. 화면 모습은 페이지 글이나 이미지 설명에 적힌 것만 옮겼다. **눈으로 본 것이 아니다.** 시안 전에 9절의 스크린샷 링크를 직접 열어 본다.
- 이 조사는 재검증(evidence-verifier)을 거치지 않았다.
- "옮기면"은 조사에서 나온 제안이며 결정이 아니다. 명령어 이름(`add`, `ls` 등)은 예시이고, 이름은 [기획서](PRD.md) 8절대로 화면 시안 뒤에 정한다.
- 로고, 스플래시 이미지, 제품 이름 같은 브랜드 자산은 빌리지 않는다. 구조와 패턴만 빌린다(8절).

## 1. 먼저 볼 것: 시안에 넣을 후보 10개 (제안)

| 번호 | 요소 | 빌려 올 곳 | 그렙에서 |
|---|---|---|---|
| 1 | 치는 대로 좁혀지는 목록, 여러 개 담기, 옆 미리보기 | fzf | 아카이브에서 자료를 골라 묶는 핵심 화면 |
| 2 | `@`를 치면 저장 자료 후보가 뜨고, 고른 자료는 칩으로 들어감 | Claude Code, GitHub Copilot CLI | `@`로 자료 부르기, `[PDF #2]` 같은 칩 |
| 3 | 입력창 위 탭 가능한 후보 줄, 후보마다 한 줄 설명 | T-UI Launcher 제안 바, Fig 자동 완성 | 휴대폰 키보드 위 명령 칩 줄 |
| 4 | 성공하면 초록, 실패하면 빨강으로 바뀌는 `❯` | Starship, Pure | 명령 결과를 색과 기호로 함께 알림 |
| 5 | 입력창 아래 상태줄(값 하나 + 도움말 힌트), 누를 수 있는 키 힌트 | Claude Code 상태줄, Codex 푸터, Textual Footer | `담은 것 5 · 보낼 곳 Claude · ? 도움말` |
| 6 | 번호 붙은 확인 질문 | GitHub Copilot CLI | `1 예 / 2 이번엔 묻지 않기 / 3 아니요`. 휴대폰에서는 번호가 곧 버튼 |
| 7 | 실행 결과를 접히는 블록으로 남기고 블록마다 복사 | shadcn AI Elements Terminal, Warp 블록 | "묶음을 넘길 글로 복사함" 기록 |
| 8 | 첫 화면에 명령 몇 개만 나열, 도움말이 곧 첫 화면 | Codex CLI 환영 화면, hack.todo | 빈 화면 대신 쓸 수 있는 명령 5~7개 |
| 9 | 탭과 새 탭 드롭다운 | Windows Terminal | 탭 = 묶음, 드롭다운 = 어느 AI로 넘길지 |
| 10 | 테마 바꾸는 명령, 밝은 테마 포함, 레트로 테마는 선택 | Gemini CLI `/theme`, 커서 모양 설정, 앰버·그린 형광체 | `theme` 명령. 기본은 밝은·어두운 두 가지 |

1차 조사와 같은 방향: 치는 것과 고르는 것을 함께 둔다(2·3·6번), 출력 끝에 다음 명령을 알려 준다(5·8번), 밝은 화면을 함께 설계한다(10번).

## 2. 화면 조각별 레퍼런스

### 2-1. 첫 화면과 시작 배너

| 이름 | 빌릴 것 | 옮기면 | 조심할 점 | 확인 |
|---|---|---|---|---|
| [OpenAI Codex CLI](https://github.com/openai/codex) | 문서 예시의 환영 화면에 `/init /status /permissions /model /review` 다섯 개만 나열. 모델 이름 옆에 "/model to change" 힌트 | 첫 화면에 명령 5개와 바꾸는 방법 한 줄 | 스플래시 이미지는 상표물. 형식만 참고. Apache-2.0 | 열람 |
| [hack.todo](https://apps.apple.com/app/id6769958914) (iOS 할 일 앱) | 명령 7개(add, ls, done, undone, rm, clean, help). 앱스토어 미리보기가 `--help` 화면. 유료 전환도 `unlock` 명령 | 명령 7개 이하. 도움말을 첫 화면처럼 | $1.99 일회성 결제 앱 | 열람 |
| 터미널 포트폴리오 사이트들([CmdFolio](https://github.com/Sigmakib2/CmdFolio), [freeCodeCamp 튜토리얼](https://www.freecodecamp.org/news/how-to-create-an-interactive-terminal-portfolio-website/)) | 공통 명령 help, whoami, about, clear. 탭 자동 완성. `gui`로 일반 화면 전환. 비개발자는 help를 모르니 첫 화면에 안내를 두라는 댓글 | 환영 문구에 쓸 수 있는 명령 3개를 미리 보여 줌 | 저장소마다 라이선스 다름 | 검색 |
| [FIGlet](https://github.com/cmatsuoka/figlet) | 큰 글자 ASCII 배너. 기본 폰트 standard, 그 밖에 big, banner, block, slant, small, mini | 시작 화면 로고 배너(영문) | **한글 미지원.** 프로그램은 BSD-3-Clause, 폰트 라이선스는 개별 확인 | 열람 |
| [k9s](https://github.com/derailed/k9s) | 상단 로고를 ASCII 아트로 바꿀 수 있음 | 상단에 서비스 ASCII 로고 | Apache-2.0 | 열람 |
| [cmd 시작 배너](https://learn.microsoft.com/windows-server/administration/windows-commands/cmd) | 인자 없이 실행하면 OS 버전과 저작권 줄을 출력 | `[Version 0.1]` 같은 버전 줄 | 정확한 문자열은 확인 못 함. Microsoft 문구를 그대로 쓰면 상표·사칭 위험 | 검색 |

### 2-2. 프롬프트 줄

| 이름 | 빌릴 것(문서 기본값) | 옮기면 | 조심할 점 | 확인 |
|---|---|---|---|---|
| [cmd `prompt`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/prompt) | 기본 `$p$g` → `C:\>`(경로 + `>`). `$t` 시간, `$d` 날짜, `$_` 줄바꿈 | 아카이브 위치를 경로처럼: `archive:\읽을거리>` | 진짜 경로처럼 보이면 파일 시스템으로 오해할 수 있음 | 열람 |
| macOS zsh ([Apple](https://support.apple.com/en-au/HT208050)) | macOS 10.15부터 zsh 기본. zsh 기본 프롬프트 기호는 일반 사용자 `%` | Mac 느낌 테마의 기호 `%` | `user@host ~ %` 형식은 공식 문서에서 확인 못 함 | 검색 |
| [Starship](https://starship.rs/config/) | 성공 `❯` bold green, 실패 `❯` bold red. 경로 bold cyan, 3단계까지. 2초 넘은 명령에 `took 3s`(bold yellow) | 성공·실패 `❯`. 요약이 오래 걸리면 `took 3s` | 색만으로 알리면 색각 이상 사용자가 놓침. 기호나 문구를 함께 | 열람 |
| [Pure](https://github.com/sindresorhus/pure) | `❯`(성공 magenta, 실패 red). 경로 파랑. 브랜치 뒤 `*`(미커밋 변경). 5초 넘으면 시간 표시 | 묶음 이름 + `*`(아직 넘기지 않은 변경) + `❯` | MIT | 열람 |
| [powerlevel10k](https://github.com/romkatv/powerlevel10k) | Lean·Classic·Rainbow·Pure 스타일. 개수 기호 `⇣42 ⇡42 +42 !42 ?42`. 실행한 뒤 지난 프롬프트를 짧게 줄이는 transient prompt. 문서도 배경색 없는 Lean을 권함 | 묶음 상태 `+3`(담음) `!1`(실패) `?2`(요약 없음). 지난 명령 줄은 짧게 | MIT. 폰트 MesloLGS NF는 Apache | 열람 |
| [oh-my-posh](https://ohmyposh.dev/docs/configuration/segment) | 세그먼트 스타일 powerline, plain, diamond(앞뒤 장식이 배경색을 이어받음), accordion. 좌·우 정렬 블록 | 왼쪽 = 위치, 오른쪽 = 시간·담은 수. diamond를 칩 모양으로 | 라이선스 저장소에서 따로 확인 | 열람 |

### 2-3. 입력과 자동 완성

| 이름 | 빌릴 것 | 옮기면 | 조심할 점 | 확인 |
|---|---|---|---|---|
| [Claude Code 입력](https://code.claude.com/docs/en/interactive-mode) | `@` 경로 자동 완성, 입력 중간의 `/` 명령 완성, 붙인 이미지를 `[Image #N]` 칩으로, 응답 뒤 다음 입력 제안을 Tab으로 채움, 제안 목록을 마우스로 클릭 | `@`로 자료 부르기, `[링크 #3]` 칩, Tab으로 추천 명령 채우기 | Shift+Tab 모드 순환은 입문자에게 헷갈림. 모드는 두 개 이하 | 열람 |
| [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli) | `@` 경로를 치면 입력창 아래 후보, 화살표·Tab으로 고름. `?`로 명령 목록. 드래그 앤 드롭과 이미지 붙여 넣기 | 끌어다 놓기로 저장(F1)과 같은 입력창 | 색·배치 설명 없음 | 열람 |
| [Fig 자동 완성](https://github.com/withfig/autocomplete) (지금은 Amazon Q) | 치는 동안 하위 명령·옵션·인자를 제안, 제안마다 설명과 아이콘 | 입력창 바로 위 후보와 한 줄 한국어 설명(기획서 8절의 한국어 설명과 맞음) | MIT | 열람 |
| [T-UI Launcher](https://github.com/fandreuz/TUI-ConsoleLauncher) (Android 런처) | 입력 위 탭 가능한 제안 바, 누르면 바로 실행되는 단축 버튼, `theme -preset` 6종 | 키보드 위 칩 줄 `add` `ls` `pick` `copy` | MIT. 마지막 F-Droid 빌드 2019년 | 열람 |
| [Aider](https://aider.chat/docs/usage/commands.html) | `/add` `/drop` `/ls`로 대화에 넣고 빼고 보기. `/ls`는 넣은 것과 안 넣은 것을 나눠 보여 줌. Ctrl-R 기록 검색 | 묶음에 담기·빼기·보기를 동사 세 개로 | — | 열람 |

### 2-4. 목록과 고르기

| 이름 | 빌릴 것 | 옮기면 | 조심할 점 | 확인 |
|---|---|---|---|---|
| [fzf](https://github.com/junegunn/fzf) | 치는 대로 좁혀지는 퍼지 필터. Tab 다중 선택. 옆·위 미리보기 창. 테두리 라벨 "N matches". 고급 문법 `'정확히` `^앞` `뒤$` `!제외` | 1번 후보의 기본 모델. 테두리에 "12개 일치", 오른쪽에 요약 미리보기 | 고급 문법은 숨기고 기본은 퍼지 검색만. MIT | 열람 |
| [lazygit](https://github.com/jesseduffield/lazygit) | Tab으로 패널 이동, `/` 필터, `space` 선택, `z` 되돌리기 | `space` 담기, `z` "방금 뺀 것 되살리기"(기획서 F14 지우기와 연결) | 레이아웃은 영상으로만 있음. MIT | 열람 |
| [k9s](https://github.com/derailed/k9s) | `:` 뒤에 이름이나 별칭으로 화면 전환(`:pod`). `/` 필터, `/!` 반대. 표에서 `space`로 표시, 선택 행 색 | `:links` `:pdf` `:images`로 자료 종류별 보기 | 명령이 늘면 입문자가 길을 잃음. Apache-2.0 | 열람 |
| [gh CLI 출력](https://cli.github.com/manual/gh_help_formatting) | 정렬된 열(번호, 제목, 브랜치, 상대 시간). 잘라 쓰기, "3일 전" 표기, 누를 수 있는 링크. 터미널일 때만 색 | `ls` 결과 `#12  제목…  youtube.com  3일 전`. 제목은 링크 | — | 열람 |
| [`tree`](https://en.wikipedia.org/wiki/Tree_(command)) | `├──` `│` `└──` 연결선, 끝에 "N directories, M files" 요약 | 묶음 구조와 "3 묶음, 12 자료" 요약 줄 | 깊으면 휴대폰 폭을 넘음. 접기 필요 | 열람 |

### 2-5. 확인 질문과 알림

| 이름 | 빌릴 것 | 옮기면 | 조심할 점 | 확인 |
|---|---|---|---|---|
| [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli) | 번호 선택 `1. Yes` / `2. 이번 세션 동안 허용` / `3. No, and tell Copilot what to do differently (Esc)` | 지우기·전부 넘기기 확인을 번호 선택으로. 휴대폰에서는 번호가 버튼 | 시각 디테일은 확인 못 함 | 열람 |
| [Crush](https://github.com/charmbracelet/crush) | 실행 전 허락 받기. 터미널이 뒤에 있으면 데스크톱 알림. `ctrl+p` 명령 팔레트 | 요약이 끝나면 "묶음 준비됨" 알림 | **라이선스 FSL-1.1-MIT라 코드는 쓰지 않고 패턴만** | 열람 |
| [Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/appearance) | 여러 탭을 닫을 때 확인이 기본값 | 묶음 여러 개를 닫을 때 확인 | — | 열람 |

### 2-6. 상태줄과 키 힌트

| 이름 | 빌릴 것 | 옮기면 | 조심할 점 | 확인 |
|---|---|---|---|---|
| [Claude Code 상태줄](https://code.claude.com/docs/en/statusline) | 입력창 아래 별도 줄. 문서 예시: 1행 모델·폴더·브랜치, 2행 `▓░` 10칸 막대로 사용량 %, 비용, 경과 시간. ANSI 초록·노랑 | 1행 `자료 1,284 · 담은 것 5 · 보낼 곳 Claude`, 2행 `▓▓▓░░░░░░░ 32%` 넘길 글 길이 | 휴대폰은 1행으로. `▓░`는 글꼴마다 다르게 보일 수 있음 | 열람 |
| [Codex CLI](https://learn.chatgpt.com/docs/codex/cli) | 푸터 `100% context left · ? for shortcuts`: 값 하나 + 힌트 하나 | 휴대폰용 한 줄 상태 | — | 열람 |
| [Textual 위젯](https://textual.textualize.io/widget_gallery/) | Footer가 키 바인딩을 보여 주고 **클릭할 수 있음**. Header 제목·부제, SelectionList 다중 선택 | 하단 키 힌트를 누를 수 있는 버튼으로(휴대폰 대응) | 라이선스는 이 페이지에서 확인 못 함 | 열람 |
| [btop](https://github.com/aristocratos/btop) | 영역을 박스로 나눔, 둥근 모서리 설정, 강조된 키 글자를 클릭하면 버튼처럼 동작 | 라벨의 단축키 글자를 강조하고 탭 가능하게 | Apache-2.0 | 열람 |
| [Norton Commander](https://en.wikipedia.org/wiki/Norton_Commander) | 두 패널, 하단 기능키 줄 | 왼쪽 아카이브 / 오른쪽 묶음, 하단 `F1 도움 F5 담기` | 상표. 이름은 쓰지 않고 구조만 | 열람 |
| [Raycast](https://www.raycast.com/) | 목록 하단 "Open · Actions Ctrl K" 힌트 줄, 키를 한 칸씩 그린 단축키 | 목록 하단에 `Enter 열기 · Ctrl K 동작` 고정 | — | 열람 |

### 2-7. 창, 탭, 테두리

| 이름 | 빌릴 것(문서 기본값) | 옮기면 | 조심할 점 | 확인 |
|---|---|---|---|---|
| [Windows Terminal 창](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/appearance) | 제목 표시줄 안의 탭. 탭 폭 `equal`/`titleLength`/`compact`(비활성 탭은 아이콘 폭). 새 탭 드롭다운에 폴더와 구분선 | 탭 = 묶음, 드롭다운 = 넘길 AI 선택. 휴대폰은 compact | 아크릴은 Windows 전용 재질. 웹은 흐림으로 흉내만 | 열람 |
| [Windows Terminal 프로필](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance) | 글꼴 Cascadia Mono 12pt(없으면 Consolas). 커서 6종 bar `┃`(기본), vintage `▃`, underscore `▁`, filledBox `█`, emptyBox `▯`, doubleUnderscore `‗`. 안쪽 여백 8 | 커서 모양을 설정으로. 기본 bar, 레트로는 `█` | — | 열람 |
| [kitty 탭 바](https://sw.kovidgoyal.net/kitty/conf/) | 탭 바 기본 위치 아래. 스타일 fade·slant·separator·powerline | 휴대폰은 엄지가 닿는 아래에 탭 | — | 열람 |
| [WezTerm 탭 바](https://wezterm.org/config/lua/config/use_fancy_tab_bar.html) | fancy(시스템 글꼴)와 retro(본문 고정폭 글꼴) | 탭 이름도 고정폭으로 통일 | — | 열람 |
| [iTerm2](https://iterm2.com/documentation-preferences-appearance.html) | Compact 테마(제목 표시줄 없음), 포커스 없는 분할 창 흐리게 | 휴대폰은 제목 표시줄 생략. 쓰지 않는 패널은 흐리게 | — | 열람 |
| [Lip Gloss](https://github.com/charmbracelet/lipgloss) | 테두리 6종(normal, rounded, thick, double, markdown, ASCII), 밝은·어두운 화면에 맞춰 바뀌는 색, 표·목록·트리 | 카드와 블록의 테두리 사전 | Go 라이브러리라 모양만 참고. MIT | 열람 |
| [Box-drawing characters](https://en.wikipedia.org/wiki/Box-drawing_characters) | 상자 그리기 128자 + 블록 32자 `░▒▓█` | 카드 테두리 `┌─┐`, 진행 막대 | 고정폭 글꼴이 아니면 줄이 어긋남. 한글이 섞이면 폭 문제(5절) | 열람 |

### 2-8. 기다림과 진행

| 이름 | 빌릴 것 | 옮기면 | 조심할 점 | 확인 |
|---|---|---|---|---|
| [cli-spinners](https://github.com/sindresorhus/cli-spinners) | 70종 이상. `dots` 80ms `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`, `line` 130ms `- \ \| /`, `arc` 100ms `◜◠◝◞◡◟` | 요약 만들기·본문 가져오기 대기 | MIT. 느린 Android에서 80ms 갱신 부담 | 열람 |
| [Rich](https://github.com/Textualize/rich) | 진행률 열(%, 크기, 속도, 남은 시간), 가이드 선 있는 트리, 유니코드 상자 표 | 여러 파일 올리기 진행 막대 + 남은 시간 | MIT | 열람 |
| [Bubbles](https://github.com/charmbracelet/bubbletea) | 텍스트 입력, 스피너 등 조각과 데모 GIF | 입력창·스피너 움직임 참고 | MIT | 열람 |

### 2-9. 실행 결과 블록

| 이름 | 빌릴 것 | 옮기면 | 조심할 점 | 확인 |
|---|---|---|---|---|
| [shadcn AI Elements Terminal](https://ui.shadcn.com/docs/ai-elements/radix/terminal) | 명령 하나를 접고 펴는 블록, 제목("Ran pnpm build"), 실행 중·오류 상태, 헤더 옆 복사·지우기, 출력 높이 제한 | "묶음 3개를 넘길 글로 복사함" 블록. 다시 복사 버튼 | 라이선스 표기는 저장소에서 확인 | 열람 |
| [Glow](https://github.com/charmbracelet/glow) | 인자 없이 실행하면 문서 목록, less식 읽기 화면, 배경을 보고 밝은·어두운 스타일 자동 선택 | 저장한 자료의 요약을 읽는 화면 | MIT | 열람 |
| [Yazi](https://github.com/sxyazi/yazi) | 영상·PDF 미리보기, 이미지를 못 쓰는 환경은 ASCII로 대체 | 이미지·PDF 미리보기 | MIT, 아이콘은 별도 라이선스 | 열람 |

### 2-10. 색과 테마

| 이름 | 빌릴 것 | 옮기면 | 조심할 점 | 확인 |
|---|---|---|---|---|
| [Gemini CLI 테마](https://geminicli.com/docs/cli/themes/) | `/theme`에서 화살표로 고름. 어두운 10종, 밝은 7종. 색 토큰을 `background.primary`, `border.default`, `border.focused`, success·warning·error로 나눔 | 이 토큰 구조를 시안의 색 이름 체계로 | Apache-2.0 | 열람 |
| [daisyUI 트렌드: Terminal/CLI UI](https://trends.daisyui.com/trend/terminal-cli-ui/) | 활성 프롬프트는 한 곳에 고정, 출력은 시간순, 로그는 접기, 모서리 0~0.25rem, 형광색 한 가지 + 오류용 색, 움직임은 커서·타자·출력에만 | 시안의 디자인 원칙 뼈대 | — | 열람 |
| PowerShell 옛 파랑([Microsoft 블로그](https://devblogs.microsoft.com/commandline/new-experimental-console-features/)) | 배경 `#012456`. Windows Terminal에는 "Campbell Powershell"로 남음 | "클래식 파랑" 테마 | 지금 Windows 11 기본은 아님 | 검색 |
| [cmd `color`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/color) | 16색 코드 0~f, 두 자리(앞 글자색, 뒤 배경) 예 `color 0a` | 숨은 재미 명령 `color 0a` | RGB 값은 문서에 없음 | 열람 |
| 단색 모니터 형광체([위키백과](https://en.wikipedia.org/wiki/Monochrome_monitor)) | P1 녹색, P3 앰버(눈부심이 덜하다는 평), P4 흰색. 잔광 | 앰버·그린 테마. 잔광은 짧은 사라짐 효과로 | hex 값 없음. 색은 직접 정한다 | 열람 |
| [cool-retro-term](https://github.com/Swordfish90/cool-retro-term) | CRT 효과, 프로필 Default Amber, IBM DOS, Default Green | 레트로 테마 이름과 주사선 | **GPL 계열이라 코드는 쓰지 않음** | 열람 |
| [Windows Terminal 레트로 효과](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance) | 주사선과 흐린 글자 가장자리(실험 기능) | 레트로 모드 켜기·끄기 | 문서도 유지 보장 없다고 함 | 열람 |
| [CSS로 만든 레트로 CRT](https://dev.to/ekeijl/retro-crt-terminal-screen-in-css-js-4afh) | 그라디언트 주사선, 지나가는 밝은 띠, 글자 번짐. 화면 깜박임은 눈이 피로해 뺐다고 함 | 레트로 테마 구현 방법 | 움직임 줄이기 설정 미대응. 라이선스 표기 없음 | 열람 |
| [Glitchtype](https://uiverse.io/ui-kits/bad-dolphin-14-186e4d54) | 밝은 바탕의 레트로 터미널(VT323, 얇은 잉크 테두리) | **밝은 터미널 테마**의 참고 | 페이지 열람 실패 | 검색 |

## 3. 웹으로 만들 때 쓸 재료

| 이름 | 무엇 | 쓸 곳 | 라이선스·주의 | 확인 |
|---|---|---|---|---|
| [WebTUI](https://github.com/webtui/webtui) | 터미널 모양 CSS 컴포넌트 20종(Dialog, Popover, Tooltip, Table, Input, Progress, Spinner 등), 테마 플러그인(Catppuccin, Gruvbox, Nord 등), Nerd Font 플러그인 | 시안과 시제품의 기본 부품 | MIT. CSS만이라 동작은 직접 만듦 | 열람 |
| [terminal.css](https://github.com/Gioni06/terminal.css) | `terminal` 클래스 하나로 적용, CSS 변수로 테마, 약 3KB | 도움말·소개 페이지 | MIT. 앱 부품은 부족 | 열람 |
| [BOOTSTRA.386](https://github.com/kristopolous/BOOTSTRA.386) | Bootstrap을 DOS 화면처럼 | 레트로 테마 참고 | Apache-2.0, 글꼴은 CC BY-SA. JS 없으면 안 보임 | 열람 |
| [Termynal](https://github.com/ines/termynal) | 한 글자씩 치는 연출, 진행 막대, 커서. 프롬프트를 CSS로 넣어 복사할 때 빠짐. JS가 없으면 정적 글 | 소개·발표 데모의 자동 재생 | MIT | 열람 |
| [Magic UI Terminal](https://magicui.design/docs/components/terminal) | 타자 연출과 순차 등장, 화면에 들어오면 시작 | React 소개 화면 | MIT | 열람 |
| [Aceternity Terminal](https://ui.aceternity.com/components/terminal) | Mac 창 모양, bash 문법 색, 타자 연출, 키 소리(기본 켜짐) | 명령·인자 색 구분 | 라이선스·무료 여부 표기 없음. 소리는 끈다 | 열람 |
| [react-terminal-ui](https://github.com/jonmbake/react-terminal-ui) | 빨강·노랑·초록 창 버튼에 기능 연결, 밝은·어두운, 프롬프트 문자 지정 | 창 버튼에 실제 기능 | MIT. 마지막 배포 약 1년 전 | 열람 |
| [xterm.js](https://github.com/xtermjs/xterm.js) | 진짜 터미널 엔진(VS Code, Replit 등) | **그렙에는 과함.** 진짜 명령줄이 아니므로 일반 입력창 + 화면 출력이 한글·휴대폰에 유리 | MIT | 열람 |
| [Charm VHS](https://github.com/charmbracelet/vhs) | 스크립트로 터미널 시연을 GIF·MP4로 녹화 | 발표 대비용 녹화(12/1 데모가 안 될 때) | MIT. 진짜 터미널용이라 웹 화면에는 브라우저 녹화를 쓴다 | 열람 |
| [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) | 아이콘 글리프 1만 개 이상 | 링크·이미지·PDF 종류 아이콘 | 글꼴마다 라이선스 다름. 없으면 네모로 깨짐. 웹 용량 | 열람 |

## 4. 비슷한 앱과 교훈 (1차 조사 5절에 더함)

| 이름 | 무엇 | 교훈 | 확인 |
|---|---|---|---|
| [hack.todo](https://apps.apple.com/app/id6769958914) | 명령 7개짜리 iOS 할 일 앱, 테마 5종, 타자 속도 설정 | 일반 사용자 대상 터미널 앱도 명령은 7개 안팎 | 열람 |
| [T-UI Launcher](https://github.com/fandreuz/TUI-ConsoleLauncher) | Android 홈 화면을 터미널로 | 휴대폰은 제안 바가 핵심 | 열람 |
| [Quick.Notes](https://apps.apple.com/us/app/-/id6753643973) | 레트로 터미널 스타일 노트, 기기에만 저장 | — | 열람 |
| [My Line Notes](https://apps.apple.com/us/app/my-line-notes-command-space/id6754385390) | 명령 프롬프트 같은 중앙 화면, 방을 밀어서 전환 | 묶음 사이 밀어서 전환 | 검색 |
| [Unlock Portfolio](https://news.hada.io/topic?id=20159) (GeekNews) | 한국어·영어 터미널 게임형 포트폴리오 | 채용 담당자가 "빨리 훑어볼 수 없다"고 해 일반 페이지와 건너뛰기 명령을 더했다. **터미널을 거치지 않고 볼 길을 함께 둔다** | 열람 |
| [Mobile Terminal](https://apps.apple.com/app/id6748270612), [MobileCLI](https://apps.apple.com/app/id6757689455) | 휴대폰에서 AI 코딩 CLI 세션 실행 | 개발자 대상이라 직접 경쟁은 아님 | 검색 |

## 5. 한글과 휴대폰에서 조심할 것

- **한글 입력 조합:** xterm.js v6에서 조합이 끝난 글자가 늦게 들어가 "이런 문제"가 "이 런문제"로 섞이는 문제가 있었다. 고친 방법: 조합 중(`isComposing`, keyCode 229)에는 keydown을 무시하고, 조합이 끝난 글자의 중복을 없애고, 입력 순서를 차례대로 처리한다([Wave Terminal PR #3264](https://github.com/wavetermdev/waveterm/pull/3264)). 직접 만드는 입력창에도 같은 세 가지를 넣는다.
- **xterm.js의 휴대폰 문제:** 터치 처리 부족, Android WebView 입력 지연, 선택 불편 이슈가 있다([#1059](https://github.com/xtermjs/xterm.js/issues/1059) 등). 일반 입력창 + 화면 출력 방식을 권한다.
- **ASCII 그림과 한글:** FIGlet은 한글을 지원하지 않는다. 상자 선 문자는 고정폭 글꼴이 아니면 어긋나고, 한글은 영문 두 칸 폭이라 표·상자 안에서 정렬을 따로 맞춰야 한다. D2Coding은 한글 폭이 영문의 정확히 2배다(1차 조사 4절).
- **색만으로 알리지 않는다:** 성공·실패 `❯`에는 기호나 문구를 함께 둔다.
- **움직임:** 타자 연출, 주사선, 깜박이는 커서는 움직임 줄이기 설정을 따른다. 화면 깜박임은 넣지 않는다.

## 6. 색 명암 대비 계산 (1차 조사의 "다음에 할 것")

1차 조사에서 원문으로 확인한 색 값으로 계산했다. 기준은 WCAG 2.2: 본문 4.5:1, 큰 글자 3:1.

| 조합 | 글자 / 배경 | 대비 | 판정 |
|---|---|---|---|
| Windows Terminal Campbell 글자 | `#CCCCCC` / `#0C0C0C` | 12.18:1 | 본문 통과 |
| Campbell 초록 | `#13A10E` / `#0C0C0C` | 5.71:1 | 본문 통과 |
| Catppuccin Latte(밝은 화면) | `#4c4f69` / `#eff1f5` | 7.06:1 | 본문 통과 |
| Catppuccin Mocha(어두운 화면) | `#cdd6f4` / `#1e1e2e` | 11.34:1 | 본문 통과 |
| Dracula 글자 | `#F8F8F2` / `#282A36` | 13.36:1 | 본문 통과 |
| Dracula 초록 | `#50FA7B` / `#282A36` | 10.38:1 | 본문 통과 |
| Dracula 보라 | `#BD93F9` / `#282A36` | 5.90:1 | 본문 통과 |
| Dracula 주석색 | `#6272A4` / `#282A36` | 3.03:1 | **큰 글자만** |

흐린 회색·파랑은 힌트나 보조 설명에 쓰기 쉬운데, Dracula 주석색은 본문 기준을 넘지 못한다. 키 힌트·상태줄 문구에는 쓰지 않는다.

## 7. 기획서와 부딪히는 지점

- **명령 수:** 일반 사용자 대상 터미널 앱(hack.todo)은 명령 7개 안팎이다. 기획서 8절의 예시 명령(`grep`, `ls`, `pick`, `copy`, `keep`, `help`)은 6개라 범위 안이다. 늘리지 않는다.
- **터미널을 거치지 않는 길:** 포트폴리오 사례는 일반 화면을 함께 두라고 말한다. 컨셉(터미널 느낌의 화면)과 부딪히지 않게, 별도 일반 화면 대신 "누르면 입력되는 명령 버튼"(기획서 F5)과 제안 칩 줄(1절 3번)로 같은 효과를 낼 수 있다. 정하는 것은 PO다.
- **`@` 멘션과 명령어:** `@`로 자료를 부르는 방식은 명령어를 몰라도 쓸 수 있어 입문자에게 쉽다. 반면 "명령어로 직접 골라 묶는다"는 차별점(기획서 6절)과 겹치지는 않는지 화면 시안에서 본다.

## 8. 라이선스 정리

| 구분 | 대상 |
|---|---|
| 코드·자산을 써도 되는 것(MIT, Apache-2.0, BSD) | WebTUI, terminal.css, Termynal, Magic UI, react-terminal-ui, xterm.js, cli-spinners, Rich, fzf, lazygit, Lip Gloss, Bubble Tea, Glow, VHS, Pure, powerlevel10k, BOOTSTRA.386(글꼴은 CC BY-SA), k9s, btop, Codex CLI, Gemini CLI, FIGlet 프로그램 |
| 패턴만 참고(코드 쓰지 않음) | Crush(FSL-1.1-MIT), cool-retro-term(GPL 계열) |
| 쓰기 전에 확인 | Aceternity, shadcn AI Elements, oh-my-posh, FIGlet 개별 폰트, Nerd Fonts 개별 폰트, Textual |
| 쓰지 않음 | 로고, 스플래시, 제품 이름, Microsoft 배너 문구, Norton Commander 이름, SF Mono(웹 배포 불가) |

## 9. 눈으로 확인할 페이지

시안 전에 직접 열어 화면을 본다.

- AI CLI: [Claude Code 상태줄 그림 4장](https://code.claude.com/docs/en/statusline), [Codex 스플래시](https://github.com/openai/codex/raw/main/.github/codex-cli-splash.png), [Crush 데모 GIF](https://github.com/charmbracelet/crush), [Gemini CLI 테마 18장](https://geminicli.com/docs/cli/themes/)
- TUI: [fzf 미리보기](https://raw.githubusercontent.com/junegunn/i/master/fzf-preview.png), [k9s 화면](https://github.com/derailed/k9s/blob/master/assets/screen_po.png), [btop 화면](https://github.com/aristocratos/btop/raw/main/Img/normal.png), [lazygit 영상](https://github.com/jesseduffield/lazygit), [Ratatui 위젯](https://ratatui.rs/showcase/widgets/), [Lip Gloss 예시](https://github.com/charmbracelet/lipgloss)
- 셸·프롬프트: [Windows Terminal 프로필 외형](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance), [Windows Terminal 창 외형](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/appearance), [Pure](https://github.com/sindresorhus/pure), [powerlevel10k](https://github.com/romkatv/powerlevel10k), [cool-retro-term](https://github.com/Swordfish90/cool-retro-term), [Nerd Fonts 치트시트](https://nerdfonts.com/cheat-sheet), [Norton Commander](https://en.wikipedia.org/wiki/Norton_Commander)
- 웹 부품: [WebTUI](https://webtui.ironclad.sh/), [Magic UI Terminal](https://magicui.design/docs/components/terminal), [Aceternity Terminal](https://ui.aceternity.com/components/terminal), [shadcn AI Elements Terminal](https://ui.shadcn.com/docs/ai-elements/radix/terminal), [Termynal](https://github.com/ines/termynal), [daisyUI 트렌드 데모](https://trends.daisyui.com/trend/terminal-cli-ui/), [charm.land](https://charm.land/)
- 휴대폰: [hack.todo](https://apps.apple.com/app/id6769958914), [T-UI Launcher](https://github.com/fandreuz/TUI-ConsoleLauncher)

찾지 못한 것: Dribbble, Behance, Figma Community는 자동 열람이 막혀 구체적인 시안을 확인하지 못했다. 직접 "terminal ui", "CLI app design", "retro terminal app"으로 찾아본다. Alacritty, Tabby, `[y/N]` 확인·`--help` 배치·npm 진행 막대의 공식 자료는 열지 못했다.
