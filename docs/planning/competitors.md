# 경쟁 서비스 조사

조사일 2026-11-24. 모두 공개 자료 기준이며 앱을 직접 써 보지 않았다. "검증" 열의 `확인`은 evidence-verifier가 원문을 다시 열어 확인한 것이고, `조사`는 리서치 단계에서 공식 페이지를 열어 본 것이며 재검증은 하지 않았다. 서비스 기능은 자주 바뀌므로 날짜를 함께 본다. 이 문서는 [기획 상태 문서](STATE.md)의 9절을 자세히 적은 것이다.

## 비교 기준: 세 개의 결정적 순간

1. 저장하는 순간: 분류를 요구하는가, 자동으로 하는가, 맥락 정보(출처·시점·조사 주제)를 남기는가
2. 다시 찾는 순간: 검색·필터·자동 묶음·다시 보여 주기
3. 쌓인 자료를 처리하는 순간: 미열람 자료를 어떻게 다루는가

## 직접 경쟁: 링크·나중에 읽기·자료 저장 앱

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

## 국내

| 서비스 | 플랫폼 | 저장 순간 | 다시 찾는 순간 | 자동 태깅 | 가격 | 검증 | 근거 |
|---|---|---|---|---|---|---|---|
| 카카오톡 나와의 채팅·톡서랍 | 모바일(PC는 미확인) | 입력하면 메모로 저장. 메모·사진·파일·링크 유형별 분류 | 유형별 모아보기, 최신순 | 유형 분류만 | 무료 | 조사(공식 자료 2019년) | [카카오](https://www.kakaocorp.com/page/detail/8643) |
| 링포미 | iOS, 웹 | 공유 시트로 저장. AI가 태그 약 20개(앱 표현 "해시태그")를 만들고 자동 분류. 수동 지정 시 AI 분류 해제 | 연관어로 검색 범위 확장 | 자동 | 무료 월 50개, ₩2,500~₩7,500 | 조사 | [앱스토어](https://apps.apple.com/us/app/id6754228991) |
| 딸깍 | iPhone | 링크·스크린샷·메모·이미지 저장, 폴더로 분류, AI 태깅 | 검색 | 자동 | 무료, 월 ₩2,900 | 조사 | [앱스토어](https://apps.apple.com/kr/app/id6670229348) |
| 블링크 | iPhone | 링크를 붙여넣으면 AI가 분류·요약 | 확인 못 함 | 자동 | 무료 | 조사 | [앱스토어](https://apps.apple.com/kr/app/id6605930254) |
| 링픽(링크루트) | iOS, Android | 흩어진 링크를 저장하면 AI 자동 분류 | 확인 못 함 | 자동 | 무료(포인트 보상) | 조사 | [linkroute.im](https://linkroute.im/) |
| 링크브레인 | 크롬 확장, 모바일 웹 | AI가 대·중·소 3단계로 분류 | AI 챗봇 검색 | 자동 | 확인 못 함 | 조사 | [linkbrain.kr](https://www.linkbrain.kr/) |

## 간접 경쟁

| 서비스 | 유형 | 저장 순간 | 맥락 정보 | 자동 태깅 | 검증 | 근거 |
|---|---|---|---|---|---|---|
| Notion 웹 클리퍼 | 노트 | 저장 위치(페이지·DB)를 고름. DB 저장 시 URL 속성 자동 생성. 저장 중 태그 입력 가능 여부는 공식 문서끼리 모순 | URL | 클리퍼 자체는 없음. Notion AI Autofill(Business 이상)로 DB 속성 자동 입력 | 확인(E-32, 모순 포함) | [웹 클리퍼](https://www.notion.com/help/web-clipper) |
| Capacities | 노트 | 링크를 객체로 저장, AI가 속성 채움 | 그날 만든 객체를 캘린더 Day 뷰의 "Created today"에 모아 보여 줌 | AI 속성 채우기 | 확인(E-30, 데일리 노트 아님) | [날짜 문서](https://docs.capacities.io/reference/dates-and-daily-notes) |
| Obsidian Web Clipper | 노트 | URL·페이지 정보로 템플릿 자동 선택, 데일리 노트에 덧붙이기 가능 | 템플릿으로 직접 설계 | 사용자 API 키로 LLM 처리 | 조사 | [템플릿](https://obsidian.md/help/web-clipper/templates) |
| Zotero | 논문 | 커넥터로 논문 서지 정보 자동 수집 | 서지 정보 | 자동완성만 | 조사 | [Zotero 8](https://www.zotero.org/blog/zotero-8/) |
| Eagle | 이미지 | 브라우저 확장으로 저장, 태그 | 추가 시간 조건 스마트 폴더 | 폴더 규칙 | 조사 | [스토어](https://en.eagle.cool/store) |
| Arc 브라우저 | 탭·세션 | 탭이 쌓이면 사이드바에서 자동으로 묶음(Tidy Tabs. 공식 도움말은 열람 실패, 검색 요약 기준) | 공간(Spaces) | 탭 수준 | 조사 | 기능: 공식 페이지 미확인. 현황: [TechCrunch, Atlassian 인수 발표 2025-09-04](https://techcrunch.com/2025/09/04/atlassian-to-buy-arc-developer-the-browser-company-for-610m) |

## 종료·철수 사례

| 서비스 | 내용 | 검증 | 근거 |
|---|---|---|---|
| Mem | AI 자동 분류 노트. 2026-11-16 종료 발표, 2026-12-18 읽기 전용, 2027-01-15 종료 | 확인(E-25) | [공식 공지](https://get.mem.ai/blog/mem-is-shutting-down) |
| Pocket | 2025-07-08 종료. 내보내기 마감은 2025-10-08로 공지됐다가 2025-11-06으로 연장됐다는 보도 | 확인(E-26, 연장은 2차 보도) | [Mozilla](https://blog.mozilla.org/en/mozilla/building-whats-next/), [VICE 연장 보도](https://develop.vice.com/en/article/mozilla-pocket-gets-one-month-reprieve/) |
| Omnivore | 2024-10-29 팀이 ElevenLabs로 이동, 서비스 종료 | 조사 | [TechCrunch](https://techcrunch.com/2024/10/29/elevenlabs-has-hired-the-team-behind-omnivore-a-reader-app/) |
| Supermemory 소비자 앱 | 2026-09-09 종료, 개발자용 엔진만 유지 | 조사 | [공식 블로그](https://supermemory.ai/blog/unified-memory-that-works-where-you-work-your-second-brain-with-supermemory/) |

## 대응 유형으로 묶기 (초안)

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

## 관찰 (가설, 포지셔닝은 4단계에서 확정)

- (가설) 원문 재검증까지 한 해외 서비스 4곳(Raindrop, Readwise Reader, mymind, Glasp) 중 모든 저장에 AI 자동 태깅을 하는 곳은 mymind 1곳이고, Raindrop은 제안 방식, Readwise는 설정해야 적용, Glasp는 수동이다. 공식 페이지만 본 서비스(Fabric, Recall, Karakeep)와 국내 앱 여럿도 자동 태깅을 내세운다(국내 앱 출시 시점은 확인하지 못함). 제안·설정형까지 포함하면 자동 태깅은 흔한 편이라, 이것만으로는 차별점이 되기 어려울 수 있다.
- 사용자가 컬렉션·속성·템플릿으로 조사 주제를 직접 남길 수 있는 서비스는 있다. 공개 자료에서 "어떤 조사 중이었는지"가 사용자 입력 없이 자동으로 남는 서비스는 찾지 못했다. 찾지 못한 것이 없다는 증명은 아니므로 직접 사용으로 확인한다.
- AI로 노트·자료를 자동 분류하던 Mem은 종료를 발표했다(확인). Supermemory 소비자 앱도 종료했으나(조사 수준) 자동 분류 기능을 내세웠는지는 확인하지 않았다. 원인은 확인하지 못했고 경향으로 해석하지 않는다.

## 직접 사용으로 확인할 것

- Raindrop, mymind, Readwise Reader, 링포미, 딸깍을 직접 써서 저장 순간에 남는 맥락 정보 확인
- Notion 웹 클리퍼에서 저장 중 태그 입력이 되는지 확인
- 국내 앱의 Android·Windows 지원 여부
