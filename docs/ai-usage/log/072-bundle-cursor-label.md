# 2026-11-26 · `묶음…` 버튼도 `묶음 _`로 맞추기

- 작성자: TAENI
- 이슈·PR: #30
- 커밋: 없음(커밋 전)

> **요약** 071에서 이름 시트를 여는 고른 것 줄의 `묶음…` 버튼은 그대로 뒀다. PO가 이것도 `_`로 맞추라고 했다. AI가 시안 6개 파일과 기획 문서 4개, MOB-001 문구, 결정 로그를 `묶음 _`로 바꿨다.

## 사용 도구

Claude Code(Opus 5.5). 시안 캔버스(Artifact), Python(문구 바꾸기), `Scripts/check-docs.sh`

## 요청

- 묶음…도 _로 맞춰 줘.

## AI 산출물

- 시안(버전 63): MPickBar 기본 버튼, M3·M6·M12의 고른 것 줄, M9 장면 설명, 웹 10 보관함의 `묶음 _` 버튼(선택 줄과 자세히 보기 칸)
- 문서: [모바일·데스크톱 화면 설계](../../planning/design-mobile-desktop.md) M3 줄, [흐름 점검표](../../planning/flow-inventory.md), [화면 체크리스트](../../planning/screen-checklist.md), [사용자 흐름도](../../planning/user-flow.md), [STATE](../../planning/STATE.md) 결정 로그 줄 고침
- 정책: [MOB-001](../../policies/mobile/MOB-001-bottom-tabs.md) 예시 문구의 버튼 이름만 바꿈(규칙 그대로), [모바일 변경 이력](../../policies/mobile/CHANGELOG.md) 한 줄

## 사람의 판단

- 시트를 여는 `묶음` 버튼도 `_`로 맞추라고 정했다.

## 검증

- 시안 파일과 문서(AI 활용 기록 제외)에서 `묶음…`이 0건인 것을 확인했다.
- `bash Scripts/check-docs.sh`: 통과

## 검증하지 못한 것

1. 바뀐 버튼을 시안에서 다시 열어 보지 않았다. 글자 수가 같아 폭은 그대로다.
