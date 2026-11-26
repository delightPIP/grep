# 2026-11-26 · 개발자 첨삭 3종으로 개발 흐름 스킬 1차 만들기

- 작성자: TAENI
- 이슈·PR: delightPIP/po-workflow-skills#5 (스킬), delightPIP/grep#22 (이 레포)
- 커밋: delightPIP/po-workflow-skills 26853ec (스킬). 이 레포는 이 로그와 함께 커밋

> **요약** PO가 수집 노트의 정할 것 4개를 추천안대로 정했고, AI가 기존 개발 스킬 본문을 서브에이전트로 대조한 뒤 범용 dev 스킬 3개(입구 `dev-flow`, 요구사항 받기, 기술 설계)를 po-workflow-skills 레포에 썼다. 그렙 팀 정보는 이 레포의 팀 설정 파일 초안에 두었다.

## 사용 도구

Claude Code(Opus 5.5), Explore 서브에이전트 1개(기존 스킬 대조), `agent-skills-creator` 검사 스크립트, `Scripts/check-docs.sh`, `gh`

## 요청

- 추천안대로 진행해 달라(스킬 위치, 범위, 1차 범위, 문서 ID).

## AI 산출물

- po-workflow-skills `skills/dev-flow/`: 12단계 입구 `SKILL.md`, `references/`(공통 규칙 원본 G1~G8과 사람이 결정할 것 표, 12단계·되돌아갈 곳·규모별 축소·착수·완료 조건 4단, 단계별로 넘길 스킬과 붙일 규칙, 이름과 ID, 팀 설정 템플릿), `evals/scenarios.md`
- po-workflow-skills `skills/dev-requirements-intake/`: 세 번 읽기와 점검 목록, 질의서·확인문·기능 명세 보완·추적표 템플릿, 가상 예시('나중에 읽기'), 평가 시나리오
- po-workflow-skills `skills/dev-technical-design/`: 설계 문서·ADR 초안·API 계약·마이그레이션·이벤트 템플릿, 평가 시나리오
- po-workflow-skills README·`plugin.json`(0.4.0)·`marketplace.json`·`install.sh`에 등록
- 이 레포: [팀 설정](../../dev-team-config.md) 초안, [문서 지도](../../README.md)에 한 줄, [수집 노트](../../planning/dev-skill-intake.md)에 PO 결정과 결정 뒤 바꾼 것

## 사람의 판단

- 스킬 위치 po-workflow-skills, 범용 + 그렙은 첫 팀 설정, 1차 범위 입구·요구사항 받기·기술 설계, 문서 ID는 C2를 줄여서(모두 AI 추천안 수용)

## 검증

- 기존 스킬 대조: 서브에이전트가 core-dev·engineering·docs·po-workflow 스킬과 사용자 스킬 `impl`·`pr`의 SKILL.md를 읽고 공통 규칙별로 표를 냈다. 그 결과로 추천안 일부를 조정했다(수집 노트 "결정 뒤 바꾼 것").
- `agent-skills-creator` 검사: 세 스킬 모두 14개 통과, 2개 실패. 실패는 이 PC에 ruby가 없는 것(머리말은 Python YAML로 읽어 통과)과 README를 표로 쓰는 레포 방식 차이로, 기존 `ai-ux-design`과 같다.
- `bash Scripts/check-docs.sh`: 통과.

## 검증하지 못한 것

- 평가 시나리오 18개(스킬당 6개)와 라우팅은 실제로 돌려 보지 않았다.
- 그렙의 지난 기획 문서로 읽기 전용 시범 적용을 하지 않았다.
- 팀 설정의 `{{}}` 칸(병합 결정권, 리뷰 스킬, 필수 검사 명령, 계약 파일 위치 등)은 근거를 찾지 못해 비워 두었다. PO·개발자 확인 전이다.
- 서브에이전트가 읽지 않은 스킬(`engineering:deploy-checklist`, `docs:api-spec-doc` 등)은 대조하지 않았다.

## AI의 오류와 정정

- 처음 쓴 팀 설정에 "확인한 사람: PO"와 근거 없는 긴급 기준("데모를 막는 결함")을 적었다. PO가 확인한 적이 없고 근거도 없어서 "AI 초안, PO·개발자 확인 전"과 빈칸으로 고쳤다.
- 스킬 레포 검사 규칙(긴 줄표 금지)에 맞추려고 일괄 치환하다가 표의 빈 칸이 `|: |`로 깨지고 제목에 콜론이 두 번 들어갔다. 검색해 모두 고쳤다.

## 근거 링크

- delightPIP/po-workflow-skills#5, 커밋 26853ec
- delightPIP/grep#22
