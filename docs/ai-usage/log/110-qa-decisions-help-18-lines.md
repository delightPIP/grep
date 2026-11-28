# 2026-11-28 · QA 확인 필요 Q-1·Q-2 반영

- 작성자: TAENI(PO)
- 이슈·PR: PR #182
- 커밋: 없음(커밋 전)

> **요약** [QA 검수 보고](../../planning/qa-2026-11-28-demo-readiness.md)의 Q-1·Q-2를 PO가 정했다. `도움말` 기대값은 18줄로 바꾸고, 시점 장면은 구현됐어도 대본에서 계속 뺀다. AI가 이 결정을 장면표와 현황 문서, 결정 로그에 반영했다.

## 사용 도구

Claude Code(Claude Opus 5.5), `po-workflow:qa-inspection` 스킬의 후속 작업.

## 요청

Q-1은 18줄로 바꾸고 시점 장면은 빼는 것으로 문서에 반영한다.

## AI 산출물

- `docs/planning/demo-seed.md`: 5절 "처음 연 화면" 기대값 18줄, 시점 행·S16 역할·시점 설명에 대본에서 뺀 이유, 7절 변경 기록 한 줄
- `docs/planning/flow-inventory.md`, `screen-checklist.md`, `user-flow.md`: "13줄"을 18줄 또는 줄 수 없는 표현으로
- `docs/planning/STATE.md` 12절: 2026-11-28 결정 한 줄(11-26의 "13줄 표"를 대체)
- `docs/planning/qa-2026-11-28-demo-readiness.md`: Q-1·Q-2 결정, DS-02·DS-15 판정과 집계

## 사람의 판단

- Q-1: 18줄로 바꾼다(PO)
- Q-2: 시점 장면은 대본에서 뺀다(PO)

## 검증

`bash Scripts/check-docs.sh` 통과. 앱은 실행하지 않았다.

## 검증하지 못한 것

1. 이번 빌드로 `도움말`이 실제로 18줄로 보이는지는 리허설 전 재실측에서 확인한다
2. 그날의 기록인 `collab-2026-11-26/08-po-dev-handoff.md`, `design-review-2026-11-26.md`와 `web/features/logged-in/view.tsx` 주석의 "13줄"·"16줄"은 고치지 않았다

## 근거 링크

PR #182
