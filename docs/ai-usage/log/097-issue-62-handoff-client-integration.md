# 2026-11-27 · #62·#64~#68 넘기기·첫 화면·기록 클라이언트 구현과 통합

- 작성자: @carti1108
- 이슈·PR: #62, #64, #65, #66, #67, #68
- 커밋: b8f4fad, 3a6037c, 07fc41d, bc5fcb0, 03a14e5, 5e500bd, e9fa95a, 4d75853, 2600c8c

> **요약** 클라이언트 갈래(`feat/62-client`)에서 `고르기`·`넘기기`·이어 쓰기·첫 화면·터미널 기록을 코어와 웹 브리지에 구현하고, 서버·뷰 갈래와 함께 `feat/62-integration`에 병합해 전체 검사를 돌렸다. 사람이 COM-009 값(200줄, 여러 탭)을 승인했고, 브라우저에서 본 뒤 자료가 있어도 터미널 맨 위에 두더지와 자료 건수를 보이도록 정책을 바꿨다.

## 사용 도구

Claude Code(데스크톱 앱), Claude Fable 5.2, `docs:policy-manager`, `docs:ai-usage`, 읽기 전용 서브에이전트 2개(코드·동시성 리뷰, 정책 대조), 앱 안 브라우저.

## 요청

- `feat/62-client` 핸드오프를 확인하고 #62·#64·#65·#66·#67·#68 클라이언트 몫을 순서대로 구현
- 다른 62 갈래(서버·뷰) 파악과 통합 브랜치 병합
- 브라우저 확인, 터미널 머리(두더지) 표시 수정, PR 준비

## AI 산출물

- 코어 `core/Features/Terminal/Sources/`: `Commands/PickCommand.swift`, `Commands/PipeCommand.swift`, `HandoffAPI.swift`, `Terminal+Pick.swift`, `Terminal+Handoff.swift`, `Terminal+Pipe.swift`, `Terminal+History.swift`, `TerminalHistory.swift`, `Terminal.swift` 수정
- 코어 테스트: `TerminalFixture.swift`, `TerminalPickTests`·`TerminalHandoffTests`·`TerminalPipeTests`·`TerminalGuideTests`·`TerminalHistoryTests`
- 웹: `web/support/local-history-store.ts`와 테스트, `web/app.ts`에 연결, 빈 구현 삭제
- 통합: `feat/62-integration`에 server·view·client 병합, 갈래 핸드오프 파일 삭제
- 뷰: 첫 화면 줄이 없을 때 출력 맨 위에 터미널 머리, `· 자료 N건`, `· 명령 전체: 도움말`(`web/features/logged-in/view.tsx`)
- 정책: COM-009 값 칸(남기는 줄 수, 여러 창·탭), 규칙 5와 사용자 문구, 명령어 설명서 6절 행
- 범위 제안: `고르기 빼기·비우기`, `넘기기 <묶음 이름>`은 결과 줄이 계약에 없어 받지 않음

## 사람의 판단

- COM-009 값 "최근 200줄", "여러 탭은 마지막에 쓴 것이 남음"을 AI 제안대로 승인
- 통합 브랜치 병합 진행을 결정
- 검색용 칸(`search_text`)을 채우는 일과 시드 넣기는 "이 이슈에서 할 일이 아니다"라며 제외
- 로그아웃 뒤 재로그인하면 두더지가 사라지는 흐름이 이상하다고 지적하고, 자료가 있어도 두더지를 보이도록 수정 지시
- 시안 `web-07`을 가리켜 자료 건수 줄도 넣도록 지시하고, 결과 화면을 보고 확정

## 검증

- `cd core && swift test`: 통과(터미널 149건 포함)
- `swift package --swift-sdk swift-6.4.2-RELEASE_wasm js`: Wasm 브리지 빌드 통과
- `cd web && npm test`: 171건 통과, `npm run build`: 통과
- `cd server && ./gradlew test`: 통과(통합 브랜치)
- `bash Scripts/check-docs.sh`: 통과
- 읽기 전용 서브에이전트 리뷰 2건(코드·동시성, 정책 SSOT 대조)
- 앱 안 브라우저(통합 브랜치, 로컬 서버): 번호 클릭 → `고르기`, `넘기기` 뒤 화면 299자와 클립보드 299자 일치, `도움말`, 새로고침 뒤 출력·치던 글·선택 유지, 터미널 머리와 자료 건수

## 검증하지 못한 것

1. Safari의 클립보드 거부(#65)
2. `로그아웃` 뒤 기록이 비는지, 계정 A → B 전환(#68). 계정 B가 없다
3. `찾기 … | 넘기기`의 바로 복사와 6건·11건 확인(#66). 로컬 자료가 찾기에 걸리지 않아 0건 경로만 봤다
4. 자료 0건 첫 화면(#67)을 브라우저에서 직접 보지 않았다
5. 서버·뷰 갈래의 작업 과정은 다른 세션이라 이 기록의 범위 밖이다

## AI의 오류와 정정

1. 첫 푸시 전에 `origin/main`이 한 커밋 앞선 것을 확인하고도 리베이스 없이 푸시했다. 강제 푸시는 권한에서 막혔고, 통합 브랜치를 최신 main에서 만들어 해소했다
2. #66은 테스트와 구현을 한 번에 써서 실패하는 테스트를 먼저 확인하지 않았다
3. 리뷰에서 결함 5건이 나와 테스트와 함께 고쳤다: 인자 첫 낱말이 낱자 `ㅣ`일 때 이어 쓰기로 받지 않음, 되살린 목록의 `→ 더 보기`가 동작하지 않음, 되살리기 전에 로그아웃하면 기록이 다시 남음, 이어 쓴 찾기가 겹치면 확인이 취소 없이 덮임, 확인 줄이 마지막이 아니면 되살릴 때 취소 표시가 빠짐
4. 자료가 있는 계정에서 두더지가 안 나오는 것을 정책대로라고만 설명했다. 사용자가 흐름이 어색하다고 지적해 정책과 뷰를 고쳤다
5. 터미널 머리를 처음에는 두더지만 넣었다. 사용자가 시안 `web-07`을 가리켜 자료 건수 줄을 더했다

## 발견 사항

1. 서버의 `search_text`를 채우는 코드가 없어, 저장한 자료가 `찾기`에 걸리지 않는다(#59·#69 쪽)
2. 이 Mac에서 Wasm 빌드는 `TOOLCHAINS`를 `swift-6.4.2-RELEASE`로, 서버 테스트는 `JAVA_HOME`을 Homebrew `openjdk@21`로 지정해야 돈다
3. 웹(wasm32)은 `Int`가 32비트라 2,147,483,648 이상 자료 번호를 읽지 못한다

## 근거 링크

이슈 #62, #64, #65, #66, #67, #68. 커밋 b8f4fad, 3a6037c, 07fc41d, bc5fcb0, 03a14e5, 5e500bd, e9fa95a, 4d75853, 2600c8c
