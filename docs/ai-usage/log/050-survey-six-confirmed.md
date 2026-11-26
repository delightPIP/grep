# 2026-11-26 · 설문 "8건 중 6건" 확인 반영

- 작성자: @delightPIP
- 이슈·PR: 없음
- 커밋: 없음(커밋 전)

> **요약** 설문 집계 검증(로그 [048](048-po-designer-agent-collab.md)의 02 문서)에서 "실패 8건 중 6건이 대략 언제를 기억"이 표로는 5건으로 세어진다고 적었다. PO가 응답 시트를 보고 6건이 맞다고 확인했다. AI가 표의 R06 단서 칸을 고치고 열린 항목을 닫았다.

## 사용 도구

Claude Code(Claude Opus 5.5). po-workflow 플러그인의 survey-tally(갱신 때 인용 문서 반영) 절차.

## 요청

PO가 설문 시트를 확인했고 6건이 맞다고 알려 왔다.

## AI 산출물

- [설문 최종본](../../planning/survey-results.md) 실패 사례 표의 R06 단서 칸에 "대략 언제"를 더하고 확인 출처를 적음
- [02 설문 집계 검증](../../planning/collab-2026-11-26/02-po-survey-tally.md) 7절 "확인 결과"를 더함
- 04 3절 확인 항목을 닫음. 01 G14를 닫음. 03·08·협업 README의 열린 항목 목록을 갱신함

## 사람의 판단

- 실패 8건 중 6건이 시점을 기억했다(PO가 응답 시트로 확인)

## 검증

- `bash Scripts/check-docs.sh` 통과
- `bash Scripts/check-stage-sensors.sh` 통과
- 6건을 인용한 5곳(survey-results:63, PRD:371, STATE:309, dev-memo-planning-review:13, po-expert-review-prompt:42)이 이미 6건이라 고치지 않음

## 검증하지 못한 것

1. AI는 응답 시트를 직접 보지 못했다. 6번째 건이 R06이라는 것은 표의 이유 응답("언제·어디서 저장했는지 기억나는데")과 PO의 "6건 맞아"를 합쳐 판단했다

## 근거 링크

없음(커밋 전)
