# 그렙

한국어 | [English](README.en.md)

저장한 자료를 골라 AI 도구용 글로 복사하는 서비스.

`담기` → `찾기` → `고르기` → `넘기기`

![웹 첫 화면](docs/planning/design-review-shots/web-01-Main.png)

## 사용 예

```text
그렙 ~ $ 찾기 결제
  131  결제위젯 연동 가이드         docs.tosspayments.com   2일 전
   97  PG사 수수료 비교 정리.pdf    PDF                     2주 전

그렙 ~ $ 고르기 131 97
✓ 선택 2건

그렙 ~ $ 넘기기
✓ 복사됨  2건 · 1,240자 (제목·출처·저장 시각·요약)
```

터미널 느낌의 화면이다. 진짜 명령줄 도구가 아니다. 명령은 한글 기본, 영문판이 같은 일을 한다.

| 한글 | 영문 | 기능 |
|---|---|---|
| `담기` | `keep` | 자료 저장 |
| `최근` | `recent` | 최근 자료 목록 |
| `찾기` | `seek` | 검색 |
| `고르기` | `pick` | 번호로 선택 |
| `넘기기` | `handoff` | AI 도구용 글 복사 |
| `묶음` | `pack` | 선택에 이름 붙이기 |
| `도움말` | `guide` | 명령 목록 |

전체: [명령어 설명서](docs/planning/commands.md)

## 데모 범위 (2026-12-01)

1. 붙여 넣기·끌어다 놓기로 저장, 중복 알림, 요약 생성
2. 단어로 다시 찾기
3. 골라서 AI 도구용 글로 복사

성공 기준: 한국어 자료를 찾아 AI 도구 입력창에 붙여 넣기까지 1분 안.

## 하지 않는 것

- 잊은 자료를 대신 떠올려 주지 않는다. 떠올릴 것을 주제어 하나로 줄일 뿐이다.
- 회사 자료 반출 제약은 풀지 못한다. 자료가 서버와 외부 LLM으로 간다.
- 다른 앱에 이미 저장한 자료는 이번에 가져오지 않는다.
- 진짜 명령줄 도구가 아니다.
- 문제와 원인은 아직 가설이다. 인터뷰 없이 설문 12명으로 방향만 봤다.

## 스택

| 영역 | 선택 | ADR |
|---|---|---|
| 서버 | Kotlin, Spring Boot, 모듈러 모놀리스 | [BCK-003](docs/adr/backend/ADR-BCK-003-kotlin-spring-boot.md), [BCK-004](docs/adr/backend/ADR-BCK-004-modular-monolith-hexagonal.md) |
| 데이터·인증·파일 | Supabase | [BCK-006](docs/adr/backend/ADR-BCK-006-supabase-without-lock-in.md) |
| 웹·데스크톱 | React, Swift 공유 코어, Tauri | [WEB-007](docs/adr/web/ADR-WEB-007-react-views-swift-core-tauri.md) |
| 요약 | 서버 소형 LLM | [BCK-008](docs/adr/backend/ADR-BCK-008-server-small-llm-summary.md) |
| API | OpenAPI 계약 우선 | [ADR-0001](docs/adr/ADR-0001-api-contract-first.md) |

## 문서

- [기획 한눈에 보기](docs/planning/overview.md)
- [기획서 (PRD)](docs/planning/PRD.md)
- [서비스 정책](docs/policies/README.md)
- [ADR](docs/adr/README.md)
- [AI 활용 기록](docs/ai-usage/README.md)
- [문서 지도](docs/README.md)

## 팀 Unwrap

| 이름 | 역할 | GitHub |
|---|---|---|
| 김태인 | PO | [@delightPIP](https://github.com/delightPIP) |
| 박기석 | 개발 | [@carti1108](https://github.com/carti1108) |
