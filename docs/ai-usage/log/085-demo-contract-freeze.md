# 2026-11-27 · #56 데모 범위 계약 고정(W2)

- 작성자: Kiseok
- 이슈·PR: #56
- 커밋: 없음(커밋 전)

> **요약** 데모 필수 13개 작업이 함께 쓸 계약을 #56 한 번에 고정했다. 사람이 API 식별자(번호만), 파일 저장 순서, 작업 분담을 정했다. AI는 마이그레이션 V2, openapi 엔드포인트 7개, 코어 줄 종류·포트, 웹 타입, Gemini ADR을 만들었다. 실제로 동작하는 것은 코어의 `담기` 한 경로다(가짜 서버 기준).

## 사용 도구

Claude Code(Claude Opus 5.5). 스킬: core-dev:handoff(recall), core-dev:flow(express: align·issues·impl·verify·ailog), grill-me·to-issues·impl 절차, docs:adr-manager, docs:ai-usage, core-dev:google-eng-review-standards. 읽기 전용 감사 서브에이전트 2개(코드, 정책 대조), Gemini 약관 확인용 웹 조회 서브에이전트 1개.

## 요청

핸드오프를 이어받아 로컬 정리(병합된 브랜치·워크트리 삭제)를 한 뒤, #56 계약 고정을 W2 세션으로 진행해 달라는 요청.

## AI 산출물

- `db/migrations/V2__items_jobs.sql`: items(사용자별 번호, 상태 5종, 정규화 주소·해시 사용자별 유일, 요약 3칸, 태그, `search_text` PGroonga 색인, 휴지통), uploads, item_jobs(자료당 진행 작업 하나)
- 서버 테스트 DB를 `groonga/pgroonga:4.0.4-alpine-17`로 바꾸고 스키마 테스트 8개 추가
- `api/openapi.yaml`: `POST·GET /items`, `/uploads`, `/uploads/limits`, `/items/search`, `/items/status`(번호로 찾기), `/handoff`, 오류 코드 `invalid_request`·`file_too_large`·`unsupported_format`·`not_found`
- 코어: `ItemSummary`·상태·이유 값, `담기` 명령(`InputCommand`·`KeepCommand`·`ItemsAPI`), 실패 뒤 같은 줄을 다시 치면 같은 멱등성 키를 재사용, 데모 줄 종류 23개와 상태줄 칸, `ClipboardPort`·`FilePort`·`HistoryStore`와 가짜 구현, `PlatformServices`
- 웹: `support/view-state.ts` 타입, `ports/*.ts` 3개, `view.tsx`가 아직 그리지 않는 줄을 `없는 명령`으로 그리지 않게 함
- 문서: ADR-BCK-014(Gemini Flash 무료 등급, ADR-BCK-008 결정 4 대체), COM-002 비고에 약관 확인 기록, `server/.env.example`
- carti-marketplace#4(플로 엔진이 Windows에서 WSL bash를 부르는 문제) 이슈 등록

## 사람의 판단

- 실행 프로필 express, 남은 Unit은 auto로 진행
- align 질문 3개를 모두 추천대로 받아들임: W2가 #56을 전부 맡음, API는 사용자별 번호로만 자료를 가리킴, 파일은 업로드 자리 → 서명 URL PUT → `POST /items` 순서
- 기존 테스트 기대값 변경(Flyway 적용 목록 `0,1` → `0,1,2`)을 승인
- ADR-BCK-014 초안과 COM-002 비고 수정을 승인
- 엔진 버그: 로컬 임시 수정과 마켓플레이스 이슈 등록을 지시. 이후 verify 게이트가 막히자 "carti-marketplace 최신화하고 적용 먼저"를 지시

## 검증

- 잠근 전체 명령(서버·코어·웹) 1회 통과, impl 게이트에서 1회 더 통과. 당시 서버 26, 코어 48, 웹 60
- 리뷰 반영 뒤 범위를 좁혀 다시 실행한 다음, 잠근 전체 명령을 한 번 더 실행: 서버 28, 코어 51, 웹 60 통과
- `Scripts/check-docs.sh` 통과. verify 게이트는 갱신한 엔진으로 origin/main 이후 바뀐 문서만 검사해 통과
- 읽기 전용 감사 2트랙: 코드 리뷰는 P1 없음·P2 4건, 정책 대조는 P1 2건·P2 7건. P1 전부와 P2 일부 반영

## 검증하지 못한 것

1. `api/openapi.yaml`은 기계 검증을 하지 않았다. 레포에 YAML 파서·OpenAPI 린터가 없다.
2. 웹 `tsc`는 wasm 생성물과 `bridge-state.ts`(M 담당) 때문에 오류가 남는다. wasm 빌드와 `npm run build`는 Mac에서 확인해야 한다.
3. Swift `Line`·`LoggedInDependency`·`GrepApp` 생성자 변경으로 `web/Sources` 브리지가 깨진다. M 세션이 맞춘다.
4. 미반영 P2: 저장 뒤 `요약 생성 중 N` 증가, `연결 끊김` 상태줄, 새 글을 치는 중 저장이 실패하면 `입력은 남겨 둠` 문구와 실제가 다른 점, `찾기` 0건 일치 위치 외 세부. 각 실행 이슈(#57·#60·#61)로 넘김

## AI의 오류와 정정

1. 처음 `/uploads`에서 확장자로 415를 돌려주게 계약을 썼다. COM-004 규칙 2(형식은 내용으로 판정)와 어긋나 정책 대조에서 걸렸고, 크기만 거르도록 고쳤다.
2. 번호 조회(`/items/status`)에 50개 제한을 두었다. ARC-001 값(개수 제한 없음)과 어긋나 제한을 없애고 `missing` 목록을 더했다.
3. 저장마다 새 멱등성 키를 만들어 재시도에서 키가 쓸모없었다. 실패 뒤 같은 줄 재시도에 같은 키를 쓰도록 고쳤다.
4. 최근 목록을 처음에 `GET /items/recent`로 만들었다가 이슈 본문(`GET /items`)에 맞춰 옮겼다.
5. Swift 타입 이름 `CommandLine`이 표준 라이브러리와 겹쳐 `InputCommand`로 바꿨다.

## 발견 사항

1. core-dev 플로 엔진(84961cac6347)이 Windows에서 센서를 `bash`로 불러 WSL bash가 잡혔다. 최신판(ce8f85e387b5)은 Git Bash를 찾고, 문서 센서를 바뀐 문서로 좁힌다(carti-marketplace#4).
2. 잠근 명령이 `shell=True`로 돌던 옛 엔진 때문에 Git Bash 경로를 명령에 직접 넣었다. 새 엔진은 `bash -c`로 돌리므로 다음 플로에서는 경로 없이 잠가도 된다.

## 근거 링크

#56, carti-marketplace#4. 커밋 없음(커밋 전).
