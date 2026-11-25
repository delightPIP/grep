# 2026-11-25 · 클라이언트 스택과 Supabase 결정

- 작성자: @carti1108
- 이슈·PR: #4
- 커밋: 6cd4022

> **요약** 웹 클라이언트를 React 뷰와 carti-RIBs-Swift 공유 코어로 만들고 데스크톱은 Tauri로 감싸기로 했다(ADR-WEB-007). DB·인증·파일 저장소는 Supabase로 정하고, 다른 서비스로 옮길 수 있도록 Supabase 전용 기능에 묶이지 않는 규칙을 함께 정했다(ADR-BCK-006).

## 사용 도구

Claude Code(Claude Opus 5.5), docs 플러그인(adr-manager, ai-usage).

## 요청

발표까지의 개발 계획을 세우고, Tauri로 감쌀 때 쓰기 좋은 웹 스택, Supabase의 대체제, Supabase나 AWS로 옮기는 비용을 알려 달라고 했다.

## AI 산출물

- 발표일(12/1)에서 거꾸로 짠 6일 개발 계획, 밀릴 때 버리는 순서(F15 → F7 → F8 → F6 → F16)
- Tauri에 맞는 웹 스택 비교(React, Svelte, SolidJS, Next.js)
- Supabase 대체제 비교(Neon+Clerk+R2, Nhost, AWS 등)와 이전 비용 추정
- Supabase 종속을 줄이는 규칙 7개
- ADR-BCK-006, ADR-WEB-007

## 사람의 판단

- 웹 뷰는 React로 정함
- 데스크톱은 Tauri로 감싸기로 함
- 뷰를 뺀 코드는 carti-RIBs-Swift로 공유하는 방식을 유지함
- DB·인증·파일 저장소는 Supabase로 정함
- 개발 계획은 레포가 아니라 개인 작업 공간에 따로 만들기로 함

## 검증

`bash Scripts/check-docs.sh`를 실행했고 통과했다. 문서 작업만 했다.

## 검증하지 못한 것

1. Supabase 저장소의 S3 호환 API 지원
2. AWS RDS의 PGroonga 지원 여부
3. 이전 비용 추정(반나절~5일)은 실제로 옮겨 본 결과가 아니라 작업량 추정이다
4. 터미널 에뮬레이터 라이브러리의 한국어 입력 문제는 기억에 기댄 판단이다

## AI의 오류와 정정

1. carti-RIBs-Swift를 웹에서 쓰는 방식(WebAssembly 컴파일)을 React의 대안처럼 표에 넣어 혼란을 줬다. 개발자가 "왜 자꾸 Wasm 얘기를 하냐"고 물었다. Wasm은 Swift 공유 코어를 브라우저에서 돌리는 방법 그 자체이고 React 뷰와 함께 쓰는 구조라고 정정했다. ADR-WEB-007에 그렇게 적었다.

## 근거 링크

PR #4, 커밋 6cd4022.
