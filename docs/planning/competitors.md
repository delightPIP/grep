# 경쟁 서비스 조사

조사일 2026-11-25. 조사 당시 대상은 개발자였고 같은 날 AI 활용자(개발자 포함)로 넓혀졌다. 문제는 "저장해 둔 자료를 AI 도구에 넘기지 못한다"([기획 상태 문서](STATE.md) 1~3절)이다. 모두 공개 자료 기준이며 앱을 직접 써 보지 않았다. 서비스 기능은 자주 바뀌므로 날짜를 함께 본다. 이 문서는 STATE 9절을 자세히 적은 것이다.

읽는 법:

- "검증" 열의 `확인(E-번호)`은 evidence-verifier가 공식 페이지를 다시 열어 확인한 것이다. `조사`는 리서치 단계에서 공식 페이지를 열어 본 것이며 재검증은 하지 않았다.
- 검증도 페이지를 요약해 읽는 도구로 했다. 인용 구절을 글자 단위로 대조한 것은 아니다.
- "찾지 못함"은 공개 자료에서 보지 못했다는 뜻이다. 없다는 증명이 아니다.
- 2026-11-24의 이전 조사(저장 앱의 저장 순간 비교)는 맨 아래 부록에 그대로 둔다.

## 비교 기준: 세 개의 결정적 순간

1. 자료를 넣는 순간: 어떤 자료를 받는가, 사용자가 직접 올리는가, 다른 저장 수단에서 가져오는가
2. AI 도구가 읽는 순간: 무엇으로 넘기는가(붙여 넣기·올리기, 연결, 프롬프트에 끼워 넣기), 원문·일부·요약 중 무엇을 주는가
3. 대화나 AI 도구가 바뀌는 순간: 넣어 둔 자료가 유지되는가, 다른 회사 AI 도구에서도 쓸 수 있는가

## 직접 경쟁: 자료·기억을 모아 여러 AI 도구에 넘겨주는 서비스

| 서비스 | 내세우는 대상 | 넣는 순간 | 읽는 순간 | 바뀌는 순간 | 가격·실행 | 검증 | 근거 |
|---|---|---|---|---|---|---|---|
| Supermemory | 에이전트용 메모리("personal agents, knowledge agents and coding agents") | 텍스트·URL·PDF·이미지·영상·코드를 받음. Google Drive·Gmail·Notion·OneDrive·GitHub에서 자동으로 가져옴 | 연결(MCP). 검색은 일치하는 메모리를, 문서 읽기는 요약과 내용을 돌려줌. 브라우저 확장이 Claude·Gemini 입력창에서 저장된 맥락을 제안(2026-07-22) | MCP를 지원하는 AI 도구 전반에서 같은 메모리를 씀 | Free $0(월 $5 크레딧), Pro 월 $19. 모바일·데스크톱 앱은 확인 못 함 | 확인(E-71) | [README](https://github.com/supermemoryai/supermemory), [MCP 문서](https://supermemory.ai/docs/supermemory-mcp/introduction), [가격](https://supermemory.ai/pricing) |
| MyMemory | 명시 없음("everything you save") | 링크·노트·파일·음성 메모. Chrome 확장, 휴대폰 공유. X·Reddit·Chrome 북마크 일괄 가져오기는 조사 수준 | 연결(MCP). 넘기는 범위는 확인 못 함 | Claude·ChatGPT·Cursor 등에 연결 | 무료 플랜 있음. 유료 가격·운영사 확인 못 함 | 확인(E-76) | [mymemory.dev](https://mymemory.dev) |
| MemoryPlugin | 일반 AI 사용자("21+ AI tools") | AI가 대화 중 저장, 선택 영역 수동 저장, 대화 기록 가져오기 | 브라우저 확장이 프롬프트에 끼워 넣음, 연결(MCP) | ChatGPT·Claude 등 여러 AI 도구가 하나의 메모리를 씀 | Core 연 $89 | 확인(E-77) | [memoryplugin.com](https://www.memoryplugin.com) |
| OpenMemory (Mem0) | MCP를 지원하는 코딩 에이전트 사용자 | 개발 도구에서 작업하는 동안 코딩 선호·패턴·설정을 자동 수집. 링크·파일 저장은 확인 못 함 | 연결(MCP). 관련 메모리를 검색해 넣음 | Cursor·VS Code·Claude 등에서 공유 | 로컬 실행 여부 확인 못 함 | 확인(E-72) | [mem0.ai/openmemory](https://mem0.ai/openmemory) |
| Basic Memory | 팀과 에이전트의 공유 메모리 | 지식을 Markdown 파일로 저장. AI가 쓰고 사용자가 고침 | 연결(MCP). 검색 결과에 일치한 본문 조각 포함(조사) | Claude·Codex·Cursor·ChatGPT 등에서 이어 씀 | 오픈소스(AGPL-3.0), 로컬 무료. Cloud 가격은 공식 출처 두 곳이 월 $19와 $15로 다름 | 확인(E-74) | [저장소](https://github.com/basicmachines-co/basic-memory), [basicmemory.com](https://basicmemory.com) |
| knowsme | 여러 AI 에이전트를 오가는 사용자 | AI가 사용 중 결정·프로젝트 상태·작업 선호를 자동 기록. 링크·파일 저장은 확인 못 함 | 연결(MCP) | 여러 AI 에이전트가 같은 메모리를 읽음 | Free는 노트 200개 | 확인(E-78) | [knowsme.dev](https://knowsme.dev) |
| Pieces | "modern work"(홈 제목). 이전의 개발자 대상 문구는 홈에서 보지 못함(조사) | 쓰는 앱에서 2초마다 자동으로 메모리를 만듦. 수동 저장은 확인 못 함 | 연결(MCP, PiecesOS 필수). 넘기는 범위 확인 못 함 | Claude·Cursor 등 MCP 지원 도구 | Pro 사용자당 월 $18.99(월 결제). 기본은 기기 안 저장. Windows·macOS·Linux(조사) | 확인(E-73) | [pieces.app](https://pieces.app), [MCP 문서](https://docs.pieces.app/products/mcp/get-started) |
| Screenpipe | 명시 없음 | 화면·오디오·앱 이력을 자동 기록(기본은 로컬) | 연결(MCP). AI 도구가 화면 이력을 조회 | MCP 지원 도구 | macOS·Windows 지원, Linux는 환경에 따라 다름. 가격은 조사 수준(Free, Basic 월 $21) | 확인(E-79) | [screenpipe.com](https://screenpipe.com) |

인접 서비스(개인 자료가 아닌 것을 넘김):

| 서비스 | 넘기는 것 | 방식 | 검증 | 근거 |
|---|---|---|---|---|
| Context7 | 공개 라이브러리의 최신 문서와 코드 예시. 개인 자료 저장소가 아님 | 연결(MCP) 또는 CLI. Free는 월 API 1,000회 | 확인(E-75) | [context7.com](https://context7.com), [저장소](https://github.com/upstash/context7) |
| Ref | 공개 문서와 비공개 자료(저장소, PDF)를 코딩 에이전트에 검색으로 제공 | 연결(MCP). 가격 확인 못 함 | 조사 | [저장소](https://github.com/ref-tools/ref-tools-mcp) |
| ByteRover | 올린 문서(PDF, DOCX, 코드 등)에서 해당 구절을 찾아 줌. 지금은 자신을 메모리가 아니라 에이전트용 문서 검색으로 소개 | 연결(MCP), API | 확인(E-81) | [byterover.ai](https://www.byterover.ai) |
| Cognee | Slack·GitHub·Notion 등을 연결한 메모리. 대상에 개인 개발자 포함 | 연결(MCP) | 조사 | [cognee.ai](https://www.cognee.ai) |

## 간접 경쟁 1: AI 도구의 자체 자료 기능

| AI 도구 | 넣는 순간 | 읽는 순간 | 바뀌는 순간 | 외부 연결 | 검증 | 근거 |
|---|---|---|---|---|---|---|
| ChatGPT | 프로젝트에 파일 올리기, 텍스트 붙여 넣기, Google Drive·Slack 링크. 프로젝트당 파일 Free 5개, Go·Plus 25개, Pro 이상 40개 | 올린 파일을 전체로 읽는지 일부만 읽는지 확인 못 함. 메모리는 대화의 모든 세부를 보존하지 않는다고 적음 | 같은 프로젝트 안의 대화에서 유지. 다른 회사 도구로 내보내기는 찾지 못함 | 사용자 정의 MCP 연결은 전체 기능이 Business·Enterprise/Edu 한정, Pro는 읽기·가져오기만 | 확인(E-49) | [프로젝트](https://help.openai.com/en/articles/10169521-projects-in-chatgpt), [MCP](https://help.openai.com/en/articles/12584461-developer-mode-apps-and-full-mcp-connectors-in-chatgpt-beta) |
| Claude | 프로젝트 지식에 문서·코드 등 파일 올리기. 파일당 30MB, 전체가 컨텍스트 창에 들어가야 함 | 한도에 가까워지면 관련 부분만 검색해 읽음(유료 플랜) | 프로젝트 안의 대화에서 유지 | 사용자 정의 MCP 연결 가능. 무료 사용자는 1개 | 확인(E-50) | [프로젝트](https://support.claude.com/en/articles/9517075-what-are-projects), [커넥터](https://support.claude.com/en/articles/11176164-pre-built-web-connectors-using-remote-mcp) |
| Claude Code | 로컬 파일을 `@`로 가리킴 | 가리킨 파일의 내용을 넣음 | 세션마다 새로 시작. CLAUDE.md와 자동 메모리가 세션 사이를 이음 | MCP | 확인(E-51) | [문서](https://code.claude.com/docs/en/memory) |
| Cursor | 파일·폴더·과거 대화를 `@`로 가리킴(조사). 외부 문서를 미리 색인하던 @Docs는 3.14.2에서 종료(2026-08 포럼 글, 답글 작성자의 직원 여부는 확인 못 함) | 규칙 내용은 적용될 때 그대로 들어감(조사) | 규칙(Project Rules, User Rules, Team Rules, AGENTS.md)이 유지 수단 | MCP(stdio, SSE, Streamable HTTP) | 확인(E-52) | [규칙](https://cursor.com/docs/context/rules), [포럼](https://forum.cursor.com/t/cursor-3-14-2-sunsetting-docs/167423) |
| GitHub Copilot | Spaces에 저장소·코드·PR·이슈·자유 텍스트·이미지·파일 올리기. Copilot Free 포함 | 개별 파일은 전체를 싣고 저장소는 전체를 싣지 않음(조사) | Spaces는 Copilot 안에서 유지 | MCP. 개인·저장소 설정을 합쳐 서버 50개까지 | 확인(E-53) | [Spaces](https://docs.github.com/en/copilot/concepts/context/spaces), [MCP](https://docs.github.com/en/copilot/concepts/context/mcp) |
| Devin Desktop(2026-06-02에 Windsurf에서 이름 변경) | 로컬 코드베이스 색인(조사) | 검색해서 일부를 읽음(조사) | 메모리를 규칙과 스킬로 대체(조사) | MCP(조사) | 확인(E-54, 이름 변경만) | [FAQ](https://docs.devin.ai/desktop/devin-desktop-faq.md) |
| Gemini, Gemini Notebook | 노트북 소스로 PDF·웹 URL·공개 YouTube URL 등. 무료는 노트북당 소스 50개 | 웹페이지는 텍스트만, YouTube는 자막만 가져옴(조사) | 다른 AI 플랫폼의 메모리·대화 기록을 가져오는 기능 있음. 내보내기는 찾지 못함 | 확인 못 함 | 확인(E-55) | [소스](https://support.google.com/notebooklm/answer/16215270?hl=en), [가져오기](https://support.google.com/gemini/answer/16868299?hl=en) |

도구 사이를 잇는 공통 수단: Codex·GitHub Copilot·Cursor의 공식 문서가 모두 저장소의 AGENTS.md 파일을 지원한다고 적는다(확인, E-56). 이것은 지침 파일이며 저장해 둔 자료를 옮기는 수단은 아니다.

## 간접 경쟁 2: 기존 저장 수단의 AI 도구 연결

"자사 MCP"는 자사 도메인 문서에 실린 MCP 서버를 뜻한다. 원문이 "official"이나 "first-party"라고 쓴 곳은 GitHub와 Karakeep뿐이다.

| 서비스 | AI 도구 연결 | AI 도구가 할 수 있는 일 | 조건 | 플랫폼(조사) | 검증 | 근거 |
|---|---|---|---|---|---|---|
| Raindrop.io | 자사 MCP(베타) | 북마크 검색, 북마크 전문과 메타데이터 읽기, 하이라이트, 저장 | 개발자 문서는 Pro 대상, 도움말은 무료 플랜에서 검색이 빠진 제한된 형태 | iOS, Android, macOS, Windows, 브라우저 확장 | 확인(E-57) | [개발자 문서](https://developer.raindrop.io/mcp/mcp.md), [도움말](https://help.raindrop.io/integrations/mcp.md) |
| Readwise(Reader 포함) | 자사 MCP | 하이라이트와 Reader 문서 접근 | 플랜 제한은 페이지에서 보지 못함 | 웹, iOS, Android, Mac·Windows, 브라우저 확장 | 확인(E-58) | [readwise.io/mcp](https://readwise.io/mcp) |
| Notion | 자사 원격 MCP | 검색, 페이지 읽기·쓰기 | 모든 플랜. 일부 기능은 플랜에 따라 다름 | Windows, macOS, 웹, 모바일 | 확인(E-59) | [개발자 문서](https://developers.notion.com/docs/get-started-with-mcp) |
| Fabric | 자사 MCP | 항목 찾기·읽기, 노트·북마크 만들기(조사) | 모든 플랜. 일부 동작은 AI 크레딧 소모 | 웹, iOS, Android, 웹 클리퍼, 데스크톱 | 확인(E-60) | [MCP](https://fabric.so/features/mcp) |
| Recall | 자사 원격 MCP | 읽기 전용(쓰기는 예정이라고 적음) | 확인 못 함 | iOS, Android, 브라우저 확장 | 확인(E-61) | [문서](https://docs.recall.it/public-api) |
| Glasp | 자사 MCP | 하이라이트·북마크·요약 읽기. 북마크 저장만 쓰기 | Glasp 계정 | 확인 못 함 | 확인(E-62) | [glasp.co/mcp](https://glasp.co/mcp) |
| Capacities | 자사 MCP(서버를 직접 운영) | 읽기·쓰기 | 플랜 요건 확인 못 함 | Windows, macOS, Linux, iOS, Android, 웹 | 확인(E-63) | [문서](https://docs.capacities.io/developer/model-context-protocol) |
| Evernote | 자사 MCP(베타) | 노트 읽기·검색·만들기 | 확인 못 함 | Windows, Mac, iOS, Android, 웹 | 확인(E-64) | [evernote.com/mcp](https://evernote.com/mcp) |
| Karakeep(오픈소스) | first-party MCP(npx 또는 Docker로 실행) | 북마크 검색, 내용 읽기, 저장, 목록·태그 관리 | 셀프호스팅 무료 | iOS, Android, Chrome·Firefox·Safari | 확인(E-65) | [문서](https://docs.karakeep.com/mcp) |
| mymind | API만. 해당 페이지에 MCP 언급 없음 | "AI 에이전트에 연결"하는 용도를 언급 | 확인 못 함 | iPhone, Android, macOS, 브라우저 확장 | 확인(E-69) | [API](https://access.mymind.com/api) |
| Obsidian | CLI(1.12 이상). 해당 페이지에 MCP 언급 없음. 커뮤니티 MCP는 여럿(조사, 비공식) | 터미널에서 검색·읽기·만들기 | 데스크톱 앱 필요(조사) | iOS, Android, Windows, Mac, Linux | 확인(E-70) | [CLI](https://obsidian.md/help/cli) |
| Zotero | Web API만. 자사 MCP는 찾지 못함. 커뮤니티 MCP는 여럿(비공식) | — | — | Windows, macOS, Linux, iOS, Android | 조사 | [API](https://www.zotero.org/support/dev/web_api/v3/) |
| Instapaper | 확인 못 함(공식 페이지 본문 열람 실패) | — | — | — | — | — |

개발자가 쓰는 저장 수단:

| 서비스 | AI 도구 연결 | AI 도구가 할 수 있는 일 | 조건 | 검증 | 근거 |
|---|---|---|---|---|---|
| GitHub(별표, Gist) | official MCP 서버 | 별표한 저장소 목록, Gist 읽기·목록 | 확인 못 함 | 확인(E-68) | [저장소](https://github.com/github/github-mcp-server) |
| massCode(코드 조각) | 앱에 내장된 MCP(2026-09-27 공지는 "MCP support") | 저장한 코드 조각·노트 검색, 읽기, 저장 | 무료, 오픈소스. macOS·Windows·Linux(조사) | 확인(E-66) | [공지](https://opencollective.com/masscode/updates/masscode-v6-is-here), [문서](https://masscode.io/documentation/) |
| Raycast(Snippets, Notes) | 로컬 MCP 서버(v2.13, 2026-11-18) | 공유된 Snippets·Quicklinks·Notes를 연결된 앱에 제공 | Raycast Pro. Mac·Windows(조사) | 확인(E-67) | [변경 기록](https://www.raycast.com/changelog/macos/2-13.md), [매뉴얼](https://manual.raycast.com/ai/model-context-protocol) |

## 국내

| 서비스 | 유형 | AI 도구 연결 | 내용 | 검증 | 근거 |
|---|---|---|---|---|---|
| 틸노트 | 노트 | 자사 원격 MCP(`https://tilnote.io/mcp`) | AI 도구에서 노트를 만들고, 조회하고, 키워드로 검색하고, 고침. Claude·ChatGPT·Claude Code·Cursor 등을 언급. 강조점은 AI 도구에서 쓴 글을 노트·블로그로 내보내는 쪽이며(조사), 링크·파일을 모으는 기능은 확인 못 함 | 확인(E-89) | [틸노트 MCP](https://tilnote.io/pages/69b79859cf3e342625b8de36.md) (2026-03-16) |
| 카카오 PlayMCP | MCP 플랫폼 | 2025-08-13 공개 때 "카카오톡 나와의 채팅방" MCP 서버를 테스트용으로 공개. 2025-11-24 도구함 발표는 ChatGPT·Claude 같은 외부 AI 서비스에서도 쓴다고 소개 | 두 발표의 예시는 나와의 채팅방으로 보내기뿐이다. 나와의 채팅방에 저장된 내용을 AI가 읽어 가는 기능은 두 발표 모두 언급하지 않음. 톡서랍 언급 없음 | 확인(E-90) | [2025-08-13](https://www.kakaocorp.com/page/detail/11674), [2025-11-24](https://www.kakaocorp.com/page/detail/11817) |
| 링포미 | 링크 저장 | 앱스토어 설명에 외부 AI 연결 문구 없음 | 대상 문구는 "마케터, 리서처, 콘텐츠 플래너". iOS·웹 | 조사 | [앱스토어](https://apps.apple.com/us/app/id6754228991) |
| 딸깍 | 링크·스크린샷 저장 | 앱스토어 설명에 외부 AI 연결 문구 없음 | iPhone 전용 | 조사 | [앱스토어](https://apps.apple.com/kr/app/id6670229348) |
| 블링크 | 링크 저장 | 앱스토어 설명에 외부 AI 연결 문구 없음 | 모바일·웹 | 조사 | [앱스토어](https://apps.apple.com/kr/app/id6605930254) |
| 링크브레인 | 링크 저장 | 공식 페이지에 외부 AI 연결 문구 없음. 앱 안의 AI 챗봇 검색만 있음 | 대상 문구는 연구자·학생, 직장인·전문가, 콘텐츠 크리에이터 | 조사 | [linkbrain.kr](https://linkbrain.kr) |

찾지 못한 것: 네이버 Keep·클로바노트의 AI 도구 연결, 국내에서 만든 북마크·메모용 MCP 서버(틸노트 제외). 링픽은 이번 조사에서 앱 자체를 찾지 못했다.

## 종료·철수·전환 사례

| 서비스 | 내용 | 검증 | 근거 |
|---|---|---|---|
| Limitless(Rewind 앱) | Meta에 인수. Rewind 앱의 화면·오디오 기록은 2025-12-19부터 중단. 한국을 포함한 일부 지역 서비스 중단은 조사 수준 | 확인(E-80) | [limitless.ai](https://www.limitless.ai) |
| Mem | AI 자동 분류 노트. 2026-11-16 종료 발표, 2027-01-15 종료 | 확인(E-25) | [공식 공지](https://get.mem.ai/blog/mem-is-shutting-down) |
| Supermemory | 부록에 적은 "소비자 앱 2026-09-09 종료"와 이번에 확인한 현재 운영 상태(브라우저 확장, 무료 플랜)의 관계는 확인하지 못함 | — | 직접 확인 필요 |
| ByteRover | 코딩 에이전트용 메모리로 소개됐다가(2차, 미열람) 지금은 문서 검색으로 소개 | 확인(E-81, 현재 문구만) | [byterover.ai](https://www.byterover.ai) |
| Cursor @Docs | 외부 문서를 미리 색인해 두는 기능을 종료 | 확인(E-52) | [포럼](https://forum.cursor.com/t/cursor-3-14-2-sunsetting-docs/167423) |

원인은 확인하지 못했고 경향으로 해석하지 않는다.

## 대응 유형으로 묶기

검증 열이 `조사`인 서비스는 이름 뒤에 `*`를 붙였다.

| 대응 유형 | 하는 서비스 | 원인 후보(STATE 6-1)와의 관계 |
|---|---|---|
| 사용자가 올려 둔 자료만 읽음(AI 도구 하나 안에서) | ChatGPT 프로젝트, Claude 프로젝트, Copilot Spaces, Gemini Notebook | N5(다시 넣기)를 그 AI 도구 안에서만 줄임. 다른 AI 도구로는 이어지지 않음 |
| 저장 수단 하나를 AI 도구에 연결 | Raindrop, Readwise, Notion, Fabric, Recall, Glasp, Capacities, Evernote, Karakeep, GitHub, massCode, Raycast | N2(다시 찾기)와 N5를 그 저장 수단에 한해 줄임. N1(흩어짐)은 저장 수단마다 따로 연결해야 함 |
| 여러 출처에서 가져와 한곳에 모으고 여러 AI 도구에 연결 | Supermemory(Drive·Notion·GitHub 등), MyMemory(북마크 가져오기는 조사 수준), Cognee\* | N1을 직접 겨냥 |
| 자동 수집(화면, 개발 도구) | Pieces, Screenpipe, OpenMemory | 저장하는 수고 자체를 없앰. 사용자가 고른 자료가 아니라 본 것 전체 |
| AI가 대화 중 기록 | knowsme, Basic Memory, MemoryPlugin | N5를 겨냥. 넘기는 것은 저장해 둔 자료가 아니라 대화에서 나온 결정·선호 |
| 프롬프트에 끼워 넣기(브라우저 확장) | Supermemory, MemoryPlugin, OpenMemory\*(확장은 조사 수준) | 연결을 설정하지 않아도 넘김 |
| 요약을 만들어 넘김 | Supermemory(문서 요약), Glasp(요약 목록), Karakeep\*(AI 요약 생성은 조사 수준) | N4(양이 많음)와 관련. 요약이 넘기는 기본 형태인지는 확인 못 함 |
| 기기 안에서만 실행 | Basic Memory(로컬), Pieces(기본 기기 안 저장), Screenpipe(기본 로컬), Karakeep(셀프호스팅), massCode | N6(회사 자료라 꺼려짐)과 관련 |
| 지침 파일로 도구 사이 이동 | AGENTS.md(Codex, Copilot, Cursor) | 지침만 옮김. 자료는 아님 |

### 공개 자료에서 찾지 못한 것 (빈 칸 후보)

- 국내 서비스 가운데 링크·파일을 저장해 두고 외부 AI 도구에 연결하는 것. 확인한 국내 링크 저장 앱 네 곳에는 그런 문구가 없었다(조사 수준).
- 국내에서 많이 쓰는 저장 수단(카카오톡 나와의 채팅 등)에 쌓인 자료를 가져와 AI 도구에 넘기는 것.
- 개발자를 대상으로 내세우면서, 사용자가 직접 고른 자료(링크·문서·코드 조각·스크린샷)의 저장과 AI 도구 연결을 함께 하는 것. 가까운 것: massCode(코드 조각·노트만), OpenMemory(자동 수집한 선호·설정), Supermemory(대상이 에이전트 개발 전반).
- Android·iOS·Web·Windows 네 곳 모두에서 저장하고 AI 도구에 연결하는 것은 빈 칸이 아니다. Raindrop.io와 Readwise가 공개 자료 기준으로 해당한다.

## 관찰과 포지셔닝

- (가설) AI 도구에 연결하는 것(MCP) 자체는 차별점이 되기 어렵다. 확인한 저장 수단 12곳과 AI 코딩 도구 대부분이 이미 지원한다.
- (가설) "저장해 두고, 여러 AI 도구에 넘긴다"는 조합도 해외에는 이미 있다(Supermemory, MyMemory). 두 곳 모두 대상을 개발자로 좁히지 않았고 국내 저장 수단은 다루지 않는다.
- (가설) 빈 칸 후보는 기능이 아니라 대상과 자료의 조합에 있다: 국내 개발자, 국내 저장 수단, 개발 자료 형식.
- 이 관찰은 "있는 서비스로 충분한가"를 말해 주지 않는다. 개발자가 실제로 이 서비스들을 쓰는지, 써도 남는 불편이 무엇인지는 인터뷰로 확인한다(STATE 13절 공백 10·12).

### 확정한 포지셔닝 (2026-11-25, PO 확정, 효과는 검증 전)

대상이 AI 활용자(개발자 포함)로 넓어지고 터미널 컨셉이 정해진 뒤에 확정했다(STATE 9절, 12절).

- 차별점 문장: AI가 알아서 찾아 읽는 연결형 서비스와 달리, 그렙은 사용자가 명령어로 자료를 직접 골라 묶어 어떤 AI 도구에든 넘기게 해서, 흩어짐(N1)과 매번 다시 넣기(N5)를 해결한다.
- 첫 시장은 국내 AI 활용자와 한국어다. 차별점으로 내세우지 않는다.
- 요약은 넘기는 형태다. 차별점으로 내세우지 않는다.
- 겹치는 서비스: Supermemory와 MemoryPlugin의 브라우저 확장이 AI 도구 입력창에 저장된 맥락을 끼워 넣는다. "사용자가 골라 넘긴다"는 차이가 실제로 얼마나 되는지는 직접 써서 확인한다.

조사 당시 적은 차별점 문장 후보(대상이 개발자일 때, 참고용):

1. 기존 서비스는 저장 수단 하나를 AI 도구에 연결하는 데 머물러 있고, 그렙은 개발자가 여러 곳에 흩어 둔 자료를 한 아카이브에 모아 넘겨서 "흩어짐"(N1)을 해결한다.
2. 기존 서비스는 해외 저장 수단과 영어권 사용자를 기준으로 만들어졌고, 그렙은 국내 개발자가 실제로 쓰는 저장 수단에서 자료를 받아 AI 도구에 넘긴다.
3. 기존 서비스는 자료를 통째로 검색해 넘기고, 그렙은 개발 작업에 맞게 요약해 넘겨서 "양이 많아 고르지 못함"(N4)을 해결한다.

## 직접 사용으로 확인할 것

- Supermemory, MyMemory, Raindrop MCP를 직접 써서 저장부터 AI 도구에서 읽기까지 걸리는 단계와 실제로 넘어오는 내용(원문·일부·요약) 확인
- Supermemory의 모바일·데스크톱 저장 수단과 소비자용 기능의 현재 상태
- 한국어 자료를 저장했을 때 검색과 요약의 품질
- AI 코딩 도구(Claude Code, Cursor)에 저장 앱 MCP를 연결했을 때 개발 작업 중에 실제로 불러 쓰게 되는지
- 국내 링크 저장 앱의 AI 연결 여부(앱 안에서 확인)

## 부록: 이전 조사 (2026-11-24, 저장 앱의 저장 순간 비교)

이전 문제 정의(다시 찾기 실패) 기준으로 조사한 내용이다. 저장 순간의 비교 자료로만 쓴다. 조사일은 2026-11-24이며 검증 열의 E-25~E-32는 이때 붙인 번호다.

### 비교 기준: 세 개의 결정적 순간

1. 저장하는 순간: 분류를 요구하는가, 자동으로 하는가, 맥락 정보(출처·시점·조사 주제)를 남기는가
2. 다시 찾는 순간: 검색·필터·자동 묶음·다시 보여 주기
3. 쌓인 자료를 처리하는 순간: 미열람 자료를 어떻게 다루는가

### 직접 경쟁: 링크·나중에 읽기·자료 저장 앱

| 서비스 | 플랫폼 | 저장 순간 | 다시 찾는 순간 | 쌓인 자료 처리 | 자동 태깅 | 가격 | 검증 | 근거 |
|---|---|---|---|---|---|---|---|---|
| Raindrop.io | iOS, Android, Windows, macOS, 웹, 브라우저 확장 | 분류 없이 "Unsorted"로 저장 가능. AI가 컬렉션·태그를 제안 | 의미 기반 검색(AI 어시스턴트 Stella, 2026-02, 베타·웹 전용·Pro). 유료 리마인더로 지정 시각에 다시 알림 | Stella가 "Unsorted" 폴더의 분류안을 제안하고 사용자가 승인 | 제안 방식 | 무료, Pro 월 $2.99(미국 앱스토어) | 확인(E-27) | [리마인더](https://help.raindrop.io/reminders), [Stella](https://blog.raindrop.io/meet-stella-your-ai-powered-second-brain-b34482fb003f/) |
| Readwise Reader | 웹, iOS, Android, Mac·Windows, 브라우저 확장 | 받은 문서함(Inbox)에 저장. 자동 태깅은 설정해야 하고 새 문서에만 적용 | 필터 뷰(쿼리 검색), AI 채팅 | 2026-08 AI가 받은 문서함 처리(triage)를 돕는 스킬 추가 | 설정 시 | 연간 결제 기준 월 $7.99~$9.99 | 확인(E-28) | [2026-08 업데이트](https://readwise.io/reader/update-aug2026) |
| mymind | 웹, macOS, iOS, Android (Windows 앱 없음) | 폴더 없음. 저장하면 AI가 자동으로 태그 | 기억나는 단어·색·주제로 검색 | Serendipity: 예전 저장물을 다시 보여 주고 남길지 버릴지 고르게 함 | 자동(강제) | $4.99~$12.99/월, 무료 플랜 없음 | 확인(E-29) | [작동 방식](https://mymind.helpscoutdocs.com/article/68-how-mymind-works), [Serendipity](https://mymind.helpscoutdocs.com/article/44-rediscovering-things-with-serendipity) |
| Glasp | 브라우저 확장, iOS, Android | 하이라이트할 때 출처·저자·날짜를 함께 저장. PDF는 페이지 번호, 영상은 타임스탬프 | 태그와 전문 검색 | Kindle 하이라이트 일일 복습 메일 | 수동 | 무료, Pro 월 $15 | 확인(E-31) | [기능](https://glasp.co/features) |
| Fabric | 웹, 데스크톱, iOS, Android, 클리퍼 | 어디 둘지 정하지 않고 저장. AI가 태그와 내용 간 관계를 추출(공식 표현 "Tags, metadata, and content relationships") | 내용 기반 검색, 조건형 스마트 컬렉션 | 확인 못 함 | 자동 | 월 $8~$54 | 조사 | [quick-capture](https://fabric.so/features/quick-capture) |
| Recall | 웹, 브라우저 확장, iOS, Android | 저장하면 요약 후 자동 태그 | 지식 그래프 연결 | 간격 반복 퀴즈로 다시 보여 줌 | 자동(Plus) | 무료~월 $38 | 조사 | [가격](https://www.recall.it/pricing) |
| Instapaper | iOS, Android, 웹 | 저장 시 태그·폴더 지정 가능 | 전문 검색(Premium) | 확인 못 함 | 없음 | 무료, Premium 월 $5.99 | 조사 | [블로그](https://blog.instapaper.com/) |
| Karakeep(오픈소스) | 웹, 확장, iOS, Android, 셀프호스팅 | LLM 자동 태깅·요약, 규칙 엔진 | 전문·의미 검색 | 확인 못 함 | 자동(셀프호스팅 시 LLM 설정 필요) | 셀프호스팅 무료 | 조사 | [README](https://raw.githubusercontent.com/karakeep-app/karakeep/main/README.md) |

### 국내

| 서비스 | 플랫폼 | 저장 순간 | 다시 찾는 순간 | 자동 태깅 | 가격 | 검증 | 근거 |
|---|---|---|---|---|---|---|---|
| 카카오톡 나와의 채팅·톡서랍 | 모바일(PC는 미확인) | 입력하면 메모로 저장. 메모·사진·파일·링크 유형별 분류 | 유형별 모아보기, 최신순 | 유형 분류만 | 무료 | 조사(공식 자료 2019년) | [카카오](https://www.kakaocorp.com/page/detail/8643) |
| 링포미 | iOS, 웹 | 공유 시트로 저장. AI가 태그 약 20개(앱 표현 "해시태그")를 만들고 자동 분류. 수동 지정 시 AI 분류 해제 | 연관어로 검색 범위 확장 | 자동 | 무료 월 50개, ₩2,500~₩7,500 | 조사 | [앱스토어](https://apps.apple.com/us/app/id6754228991) |
| 딸깍 | iPhone | 링크·스크린샷·메모·이미지 저장, 폴더로 분류, AI 태깅 | 검색 | 자동 | 무료, 월 ₩2,900 | 조사 | [앱스토어](https://apps.apple.com/kr/app/id6670229348) |
| 블링크 | iPhone | 링크를 붙여넣으면 AI가 분류·요약 | 확인 못 함 | 자동 | 무료 | 조사 | [앱스토어](https://apps.apple.com/kr/app/id6605930254) |
| 링픽(링크루트) | iOS, Android | 흩어진 링크를 저장하면 AI 자동 분류 | 확인 못 함 | 자동 | 무료(포인트 보상) | 조사 | [linkroute.im](https://linkroute.im/) |
| 링크브레인 | 크롬 확장, 모바일 웹 | AI가 대·중·소 3단계로 분류 | AI 챗봇 검색 | 자동 | 확인 못 함 | 조사 | [linkbrain.kr](https://www.linkbrain.kr/) |

### 간접 경쟁

| 서비스 | 유형 | 저장 순간 | 맥락 정보 | 자동 태깅 | 검증 | 근거 |
|---|---|---|---|---|---|---|
| Notion 웹 클리퍼 | 노트 | 저장 위치(페이지·DB)를 고름. DB 저장 시 URL 속성 자동 생성. 저장 중 태그 입력 가능 여부는 공식 문서끼리 모순 | URL | 클리퍼 자체는 없음. Notion AI Autofill(Business 이상)로 DB 속성 자동 입력 | 확인(E-32, 모순 포함) | [웹 클리퍼](https://www.notion.com/help/web-clipper) |
| Capacities | 노트 | 링크를 객체로 저장, AI가 속성 채움 | 그날 만든 객체를 캘린더 Day 뷰의 "Created today"에 모아 보여 줌 | AI 속성 채우기 | 확인(E-30, 데일리 노트 아님) | [날짜 문서](https://docs.capacities.io/reference/dates-and-daily-notes) |
| Obsidian Web Clipper | 노트 | URL·페이지 정보로 템플릿 자동 선택, 데일리 노트에 덧붙이기 가능 | 템플릿으로 직접 설계 | 사용자 API 키로 LLM 처리 | 조사 | [템플릿](https://obsidian.md/help/web-clipper/templates) |
| Zotero | 논문 | 커넥터로 논문 서지 정보 자동 수집 | 서지 정보 | 자동완성만 | 조사 | [Zotero 8](https://www.zotero.org/blog/zotero-8/) |
| Eagle | 이미지 | 브라우저 확장으로 저장, 태그 | 추가 시간 조건 스마트 폴더 | 폴더 규칙 | 조사 | [스토어](https://en.eagle.cool/store) |
| Arc 브라우저 | 탭·세션 | 탭이 쌓이면 사이드바에서 자동으로 묶음(Tidy Tabs. 공식 도움말은 열람 실패, 검색 요약 기준) | 공간(Spaces) | 탭 수준 | 조사 | 기능: 공식 페이지 미확인. 현황: [TechCrunch, Atlassian 인수 발표 2025-09-04](https://techcrunch.com/2025/09/04/atlassian-to-buy-arc-developer-the-browser-company-for-610m) |

### 종료·철수 사례

| 서비스 | 내용 | 검증 | 근거 |
|---|---|---|---|
| Mem | AI 자동 분류 노트. 2026-11-16 종료 발표, 2026-12-18 읽기 전용, 2027-01-15 종료 | 확인(E-25) | [공식 공지](https://get.mem.ai/blog/mem-is-shutting-down) |
| Pocket | 2025-07-08 종료. 내보내기 마감은 2025-10-08로 공지됐다가 2025-11-06으로 연장됐다는 보도 | 확인(E-26, 연장은 2차 보도) | [Mozilla](https://blog.mozilla.org/en/mozilla/building-whats-next/), [VICE 연장 보도](https://develop.vice.com/en/article/mozilla-pocket-gets-one-month-reprieve/) |
| Omnivore | 2024-10-29 팀이 ElevenLabs로 이동, 서비스 종료 | 조사 | [TechCrunch](https://techcrunch.com/2024/10/29/elevenlabs-has-hired-the-team-behind-omnivore-a-reader-app/) |
| Supermemory 소비자 앱 | 2026-09-09 종료, 개발자용 엔진만 유지 | 조사 | [공식 블로그](https://supermemory.ai/blog/unified-memory-that-works-where-you-work-your-second-brain-with-supermemory/) |

### 대응 유형으로 묶기 (초안)

위 표에 적은 서비스만 이름을 적었다. 검증 열이 `조사`인 서비스는 이름 뒤에 `*`를 붙였다(원문 재검증 전). 확인하지 못한 서비스는 "확인 못 함" 열에 둔다.

| 대응 유형 | 하는 서비스 | 하지 않는 서비스 | 확인 못 함 |
|---|---|---|---|
| 분류 없이 저장 가능 | Raindrop, Readwise Reader, mymind, Fabric\*, Recall\*, 블링크\*, 링픽\* | Notion 클리퍼(저장 위치 선택 필수) | 카카오톡 나와의 채팅은 유형별 분류만 있어 해당 여부 판단 보류 |
| AI 자동 태깅(모든 저장에 적용) | mymind, Fabric\*, 링포미\*(수동 지정 전까지) | Instapaper\*, Glasp | 블링크·딸깍·링픽·링크브레인의 적용 범위(모든 저장인지) |
| AI 자동 태깅(유료 플랜·설정 시) | Recall\*(Plus), Readwise Reader(설정), Karakeep\*(셀프호스팅 시 LLM 설정) | — | — |
| AI 자동 분류 + 수동 지정 시 덮어쓰기 | 링포미\* | — | — |
| AI 분류 제안 + 사용자 승인 | Raindrop(Stella, 베타) | mymind | — |
| 출처·저자·날짜를 저장물과 함께 표시 | Glasp(하이라이트 단위), Zotero\*(논문 서지 정보), Notion 클리퍼(URL 속성만, 부분 해당) | — | 나머지 서비스(URL·저장 시각 자동 기록 여부를 화면으로 확인하지 않음) |
| 저장 당시 조사 주제·목적을 사용자가 직접 남길 수 있음 | Raindrop(컬렉션 지정), Notion 클리퍼(DB 속성), Obsidian\*(템플릿) | — | 다른 서비스 |
| 저장 당시 조사 주제·목적이 사용자 입력 없이 자동으로 남음 | 공개 자료에서 찾지 못함 | — | 직접 사용으로 확인 필요 |
| 조사 중 주제에서 벗어나 모은 자료 구분 | 공개 자료에서 찾지 못함. 가장 가까운 것은 탭 수준 자동 묶기(Arc Tidy Tabs) | — | 직접 사용으로 확인 필요 |
| 쌓인 자료를 다시 보여 주고 처리 | mymind Serendipity, Readwise 문서함 처리 스킬, Raindrop 리마인더(Pro), Recall\* 복습 퀴즈 | — | 국내 서비스 |

### 관찰 (가설, 포지셔닝은 4단계에서 확정)

- (가설) 원문 재검증까지 한 해외 서비스 4곳(Raindrop, Readwise Reader, mymind, Glasp) 중 모든 저장에 AI 자동 태깅을 하는 곳은 mymind 1곳이고, Raindrop은 제안 방식, Readwise는 설정해야 적용, Glasp는 수동이다. 공식 페이지만 본 서비스(Fabric, Recall, Karakeep)와 국내 앱 여럿도 자동 태깅을 내세운다(국내 앱 출시 시점은 확인하지 못함). 제안·설정형까지 포함하면 자동 태깅은 흔한 편이라, 이것만으로는 차별점이 되기 어려울 수 있다.
- 사용자가 컬렉션·속성·템플릿으로 조사 주제를 직접 남길 수 있는 서비스는 있다. 공개 자료에서 "어떤 조사 중이었는지"가 사용자 입력 없이 자동으로 남는 서비스는 찾지 못했다. 찾지 못한 것이 없다는 증명은 아니므로 직접 사용으로 확인한다.
- AI로 노트·자료를 자동 분류하던 Mem은 종료를 발표했다(확인). Supermemory 소비자 앱도 종료했으나(조사 수준) 자동 분류 기능을 내세웠는지는 확인하지 않았다. 원인은 확인하지 못했고 경향으로 해석하지 않는다.

### 직접 사용으로 확인할 것

- Raindrop, mymind, Readwise Reader, 링포미, 딸깍을 직접 써서 저장 순간에 남는 맥락 정보 확인
- Notion 웹 클리퍼에서 저장 중 태그 입력이 되는지 확인
- 국내 앱의 Android·Windows 지원 여부
