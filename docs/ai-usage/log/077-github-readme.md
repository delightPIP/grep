# 2026-11-26 · GitHub README 꾸미기

- 작성자: TAENI
- 이슈·PR: 없음(PR 생성 전)
- 커밋: 없음(커밋 전)

> **요약** PO가 GitHub 첫 화면 README를 꾸미고 만든 사람을 넣어 달라고 했다. AI가 기획서·명령어 설명서·ADR·디자인 시안 캡처에서 내용을 골라 소개, 사용 예, 화면, 데모 범위, 기술 스택, 문서 안내, 팀 소개(Unwrap, 김태인 PO·박기석 개발)로 README를 새로 썼다.

## 사용 도구

Claude Code(Opus 5.5), `gh` CLI(기여자 확인), `Scripts/check-docs.sh`

## 요청

GitHub README를 알아서 잘 꾸미고, 누가 만들었는지도 넣어 달라.

## AI 산출물

- `README.md` 전면 재작성: 한 줄 소개, 웹 시안 캡처, 명령 사용 예와 명령 표, 데모 필수 범위와 성공 기준, 기술 스택과 ADR 링크, 문서 표, 팀 Unwrap 표(이름·역할·GitHub)
- 이 로그 항목과 목록 표 한 줄

## 사람의 판단

- 구성·문구는 AI가 정했고 PO가 아직 보지 않았다(AI 제안·미확인).
- PO가 첫 안의 말투가 과하다고 해서(배지, 꾸밈말, 프로필 사진) 저장소 문서처럼 건조하고 짧게 다시 썼다.

## 검증

- `bash Scripts/check-docs.sh`: 통과
- 내용은 PRD 0.9, 명령어 설명서, dev-team-config의 값만 옮겼다.

## 검증하지 못한 것

1. GitHub에서 실제로 렌더링된 모습(이미지 크기)은 PR 화면에서 확인해야 한다.

## 근거 링크

없음(커밋 전)

## 추가 작업 (같은 날)

- PO 요청으로 다른 README 10개(karakeep, linkwarden, glow, ripgrep, zoxide, fzf, bat, toss/slash, toss/es-toolkit, daangn/stackflow)를 `gh`로 읽어 구성·길이·말투를 비교했다.
- PO가 AI 추천 두 가지(ripgrep식 "하지 않는 것", karakeep식 "비슷한 서비스")를 골랐으나, 이어서 "비슷한 서비스는 넣지 마, 서비스만 소개"라고 해 "하지 않는 것"만 남겼다. 내용은 PRD 3절에서 옮겼다.
- 영문 README(`README.en.md`)를 추가하고 두 파일 맨 위에 언어 전환 링크를 달았다. 팀원 이름의 영문 표기(Taein Kim, Kiseok Park)는 AI가 정했고 본인 확인 전이다.
