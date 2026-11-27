# 2026-11-27 · #77 코어 Terminal 피처 분리(M)

- 작성자: Kiseok
- 이슈·PR: #77 (PR 없음, 브랜치 `feat/77-terminal`)
- 커밋: 2d97e25, 78f285a

> **요약** AI가 공유 코어의 터미널 로직을 `LoggedIn`에서 `Terminal` 피처로 옮기고 `LoggedIn`을 컨테이너로 바꿨다. 동작은 바꾸지 않았다. 사람은 테스트 검사 5곳의 표기 변경을 승인하고, #61보다 #77을 먼저 머지하기로 정했다.

## 사용 도구

Claude Code(Claude Fable 5.2). swift, npm, git, gh, 내장 브라우저. 스킬: docs:ai-usage.

## 요청

`feat/77-terminal` 브랜치 확인, #77 시작, 커밋, 이어서 #61보다 #77을 먼저 올리라는 요청.

## AI 산출물

- `core/Features/Terminal/`(Interface·Sources·Testing·Tests): 화면 상태, 명령, 저장, 최근·더 보기, 폴링, 연결 확인을 `LoggedIn`에서 옮김
- `LoggedIn.swift`: 컨테이너. `GET /me`, 계정(`sub`), 만료 전 치던 줄 되살리기, 만료, 로그아웃. 자식 `Terminal`을 붙이고 그 화면을 자기 화면으로 씀
- 경계 계약: `TerminalListener`(`didRequestSignOut`, `didExpire(input:)`), `TerminalHandle`(`input`, `restoreInput`, `showItemCount`, `observeReachability`)
- `ObservedTransport`를 `GrepCore`로 옮김(`/me`와 터미널 요청이 같은 연결 끊김 표시를 씀)
- `core/Package.swift`: `feature("Terminal")`, 부모 피처가 자식 Interface에 의존하는 `children`
- 웹 Swift: `FeatureTerminalWeb`, `TerminalStateValue.swift`. JS로 가는 이름과 `view-state.ts`는 그대로
- 테스트: `LoggedInTests`를 컨테이너 테스트(14개)와 `TerminalTests`로 나누고 `LoggedInBrowseTests`를 `TerminalBrowseTests`로 옮김(Terminal 66개). 새 테스트 8개
- ARC-005·COM-010 근거의 구현 위치를 옮긴 경로로 고침

## 사람의 판단

- TDD 무결성 훅이 테스트 이동과 검사 표기 변경을 막은 뒤, 전후 비교(125개 중 120개 그대로, 5개 표기 변경, 16개 추가)를 보고 커밋을 지시해 승인
- #61 브랜치를 합치기 전에 #77을 먼저 머지하는 순서를 고름

## 검증

- 코어 `swift test` 전체 통과(Terminal 66개, LoggedIn 14개, App 10개 포함)
- 웹 `npm test` 111개 통과, `npm run build` 통과, Wasm 빌드 통과
- 브라우저(서버 없이): 터미널이 그려지고, `/me` 실패가 컨테이너를 거쳐 상태줄 `연결 끊김`으로 나오고, `최근`이 실패 줄을 찍음
- `Scripts/check-docs.sh` 통과

## 검증하지 못한 것

1. 서버를 붙인 정상 경로(`/me` 자료 수, 저장, 최근)와 로그아웃·만료는 브라우저에서 보지 않음. 테스트로만 확인
2. 읽기 전용 리뷰(코드·동시성, 정책 대조)는 돌리지 않음
3. CI는 PR을 열지 않아 돌지 않음

## AI의 오류와 정정

1. 처음에는 `/me`를 컨테이너로 옮기면서 그 요청의 네트워크 오류가 터미널의 `연결 끊김`에 잡히지 않게 됐다. 기존 테스트를 떠올려 `ObservedTransport`를 공유하고 `TerminalHandle.observeReachability`를 더해 맞췄다
2. `Package.swift`의 한 식이 길어 컴파일러가 형 검사 시간 초과를 냈다. 식을 나눠 고쳤다
3. 터미널 단독 테스트에서 `/me`가 첫 요청이라고 가정한 인덱스 한 곳이 실패했다. 첫 요청을 보도록 고쳤다
4. 테스트 이동과 검사 표기 변경을 승인받기 전에 작업 트리에 넣어 훅에 막혔다. 전후 비교를 보고하고 승인을 받았다

## 근거 링크

#77, ADR-0015, 커밋 2d97e25·78f285a
