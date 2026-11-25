# 2026-11-25 · 서비스 이름 그렙, 팀 이름 Unwrap

- 이슈·PR: delightPIP/grep#5
- 커밋: 없음(커밋 전)

> **요약** PO가 서비스 이름을 그렙으로, 팀 이름을 GREP에서 Unwrap("문제를 풀어 보다")으로 정했다. AI가 기획 문서의 "이 서비스" 30곳을 조사에 맞춰 "그렙"으로 바꾸고, 이름을 정의하는 곳(PRD 1절, STATE, 개요, 문서 README)을 고쳤다.

## 사용 도구

Claude Code(Claude Opus 5.5), Python(조사를 맞춘 문자열 치환).

## 요청

PO: 서비스 이름은 그렙으로, 팀 이름은 Unwrap으로 하기로 했다. 문서를 일관되게 바꿔 달라.

## AI 산출물

- 서비스 이름 후보 다섯 개(보따리, 챙김, 곳간, 줍줍, 건네)와 추천. PO는 고르지 않고 그렙으로 정했다
- `docs/planning/` 문서와 `docs/policies/README.md`의 "이 서비스" 30곳을 "그렙"으로 바꿈(조사 은/이/을/과 맞춤)
- PRD 1절·12절·14절, STATE 개요와 결정 로그, `overview.md`, 문서 README 세 곳의 이름 정의
- `commands.md`: 서비스 이름이 grep이어도 `grep`을 명령으로 쓰지 않는다는 줄

## 사람의 판단

- 서비스 이름 그렙(영문 grep), 팀 이름 Unwrap(PO)

## 검증

`bash Scripts/check-docs.sh`, `bash Scripts/check-stage-sensors.sh` 실행.

## 검증하지 못한 것

1. 영문 표기는 저장소 이름에 맞춰 grep으로 적었다. PO에게 따로 확인하지 않았다.
2. 결정 로그의 지난 줄과 AI 로그 001~017은 기록이라 옛 이름(GREP, "이 서비스")을 그대로 두었다. 경쟁 서비스를 가리키는 "이 서비스들"도 그대로 두었다.
3. PR #4(개발자 브랜치)의 문서는 고치지 않았다.

## 근거 링크

delightPIP/grep#5
