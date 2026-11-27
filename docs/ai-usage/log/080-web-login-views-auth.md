# 2026-11-26 · #31 웹 로그인 화면·터미널 껍데기·로그인 모듈

- 작성자: Kiseok
- 이슈·PR: #31
- 커밋: 없음(커밋 전)

> **요약** 핸드오프를 이어받아 로그인 화면, 터미널 화면 뷰와 supabase-js 로그인 모듈을 TDD로 만들었다. 사람은 팝업 방식, 동의 거부를 `로그인 취소됨`으로 보는 기준, 시안대로 다시 그리기를 정했다.

## 사용 도구

Claude Code(Claude Opus 5.5). 스킬: core-dev:handoff(recall), docs:adr-manager, docs:policy-manager, docs:ai-usage, core-dev:commit-rules.

## 요청

`.handoff-latest.md`로 #31 C 갈래(웹 뷰·로그인 모듈) 작업을 이어서 진행.

## AI 산출물

- `web/features/logged-out/view.tsx`, `web/features/logged-in/view.tsx`와 테스트
- `web/ui/grep.tsx`, `web/styles/grep.css`: 시안 디자인 시스템(`project/ds/grep/components`)의 Window·StatusBar·Prompt·Line·입력줄·Banner·버튼을 React로 옮김
- `web/auth/supabase-auth.ts`와 테스트, `web/public/auth-callback.html`
- ADR-WEB-012 초안, ACC-001 비고 문구 초안
- Google 로그인 페이지의 COOP 헤더를 curl로 확인하고, 팝업 닫힘을 알 수 없다는 문제 제기

## 사람의 판단

- 로그인 방식: 전체 페이지 이동 대신 팝업 + BroadcastChannel(AI 추천안 수용)
- 동의 화면 거부(`access_denied`)는 `✗ 로그인 취소됨`(AI 추천안 수용)
- "뷰 그리는데 당연히 시안대로 하는게 맞지 않냐": 토큰만 쓴 첫 구현을 시안 기준으로 다시 그리게 함
- 미리보기 화면을 보고 승인

## 검증

- `npm test`(vitest): 41개 통과. 가짜 Supabase 클라이언트로 성공·취소·실패·시간 초과·토큰 갱신 실패 확인
- `tsc --noEmit` 통과, `bash Scripts/check-docs.sh` 통과
- 한글 조합 중 엔터 막기 테스트는 해당 조건을 지운 코드에서 실패하는 것을 확인
- 사용자가 브라우저 미리보기로 화면 확인

## 검증하지 못한 것

1. 실제 Google·GitHub 로그인. Supabase Redirect URLs에 `/auth-callback.html` 등록 여부를 확인하지 않음
2. 시안 화면과 픽셀 단위 비교는 하지 않음
3. `npm run build`(wasm 빌드는 B 갈래 작업 뒤에 가능)

## AI의 오류와 정정

1. 핸드오프에 시안 출처가 적혀 있었는데 열어 보지 않고 토큰만으로 뷰를 그림. 사용자가 지적한 뒤 시안 Login·Main·Errors·Logout 아트보드와 bundle.css·bundle.js를 읽고 다시 그림

## 발견 사항

1. 시안의 만료 화면 `치던 줄 남겨 둠: <글>`과 상태줄 `선택 N`은 계약(`LoggedOutState`, `LoggedInState`)에 값이 없어 그리지 못함. #31에 계약 추가 요청이 필요함

## 근거 링크

#31, ADR-WEB-012, ACC-001. 커밋 없음(커밋 전)
