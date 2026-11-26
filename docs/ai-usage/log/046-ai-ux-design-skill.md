# 2026-11-26 · 디자이너 가이드 3종으로 AI 기능 UX 설계 스킬 만들기

- 작성자: TAENI
- 이슈·PR: delightPIP/po-workflow-skills#2 (스킬). 이 레포는 없음
- 커밋: delightPIP/po-workflow-skills 2181ab5 (스킬). 이 레포는 없음(커밋 전)

> **요약** PO가 디자이너의 AI 기능 UX 설계 가이드 3종을 한 건씩 넘겼고, AI가 건마다 가져갈 것·바꿀 것·버릴 것을 수집 노트에 정리한 뒤 하나로 합친 스킬 계획을 세웠다. PO가 스킬 위치·범위·가정 기록 위치·ID 체계를 정했고, AI가 가이드의 외부 인용을 원문으로 확인한 뒤 범용 스킬 `ai-ux-design`을 po-workflow-skills 레포에 쓰고 PR을 열었다.

## 사용 도구

Claude Code(Opus 5.5), web-fetch 서브에이전트 2개(외부 출처 확인), `agent-skills-creator` 검사 스크립트, `Scripts/check-docs.sh`, `gh`

## 요청

- 디자인 작업 스킬을 만들려고 디자이너 작업 자료 여러 건을 한 건씩 줄 테니, 받을 때마다 미리 학습해 어떻게 반영할지 준비해 달라.
- 다 받은 뒤: 외부 출처를 확인하고 스킬을 쓴 다음, 커밋하고 PR을 올려 달라.

## AI 산출물

- [디자인 스킬 수집 노트](../../planning/design-skill-intake.md): 자료 D1(6단계), D2(7단계), D3(6단계와 템플릿)마다 가져갈 것·그렙에 맞게 바꿀 것·버릴 것, 세 자료가 공통으로 말한 규칙 8개, 최종 합본 계획(단계, ID, 파일 구성), PO 결정 표
- po-workflow-skills 레포 `skills/ai-ux-design/`: `SKILL.md`, `references/`(단계 상세, 상태와 기준, 문서 틀, 가상 예시, 점검표, 외부 출처 확인 기록), `evals/scenarios.md`(라우팅과 행동 시나리오 8개). README·`plugin.json`(0.3.0)·`marketplace.json`·`install.sh`에 등록
- 외부 출처 확인: WCAG 2.2 성공 기준 11개, NN/g 응답 시간 한계, Google Rules of ML Rule #1·#2, Microsoft Human-AI 지침 18개, NIST AI 600-1, GOV.UK 진행형 사용성 테스트를 원문으로 대조
- 스킬 PR: delightPIP/po-workflow-skills#2 (아직 열려 있는 #1 위에 쌓음)

## 사람의 판단

- 자료는 세 건이며 세 번째에서 "여기까지 끝"으로 수집을 마쳤다.
- 스킬 위치: po-workflow-skills 레포(AI 추천안 수용)
- 범위: 범용만. AI는 "범용 + 그렙 예시 분리"를 추천했으나 PO가 그렙 사례·규칙을 넣지 않기로 했다
- 가정 기록: 설계 문서 안 로그 절(AI 추천안 수용)
- ID 체계: D3 기반 + 가정은 H(AI 추천안 수용)
- 스킬을 쓰기 전에 외부 출처부터 확인하는 순서(AI 추천안 수용)

## 검증

- 외부 출처: 위 6개는 원문으로 확인했다. 틀린 인용은 없었다. "동작 줄이기"(prefers-reduced-motion)는 WCAG 본문에 없고 관련 기준 2.3.3은 AAA라서, 스킬에는 AA 기준이 아닌 권장으로 적었다.
- `agent-skills-creator` 검사: 14개 통과, 2개 실패. 실패는 이 PC에 ruby가 없는 것(머리말은 Python YAML로 읽어 통과)과 README를 표로 쓰는 레포 방식 차이다.
- `bash Scripts/check-docs.sh`: 통과.

## 검증하지 못한 것

- 스킬 평가 시나리오 8개는 실제로 돌려 보지 않았다.
- Google PAIR People + AI Guidebook은 페이지가 있다는 것만 확인했다. 장 구성을 읽지 못해 스킬에서 내용을 인용하지 않았다.

## AI의 오류와 정정

- web-fetch로 WCAG 페이지를 읽었을 때 가운데 부분(성공 기준 본문)이 원문이 아닌 요약으로 돌아왔고, 두 번 물을 때 답이 달랐다. 페이지를 직접 받아 각 기준의 원문 문장을 뽑아 다시 대조했다.
- Microsoft와 NIST PDF는 web-fetch로 글자를 읽지 못했다. 서브에이전트가 받은 요약은 원문이 아니라 기억에 기댄 내용이라 쓰지 않았고, 임시 가상 환경에 PDF 읽기 도구를 설치해 원문에서 확인했다.

## 근거 링크

- delightPIP/po-workflow-skills#2, 커밋 2181ab5
- 이 레포: 없음(커밋 전)
