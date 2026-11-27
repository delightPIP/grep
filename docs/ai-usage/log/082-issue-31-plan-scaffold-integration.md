# 2026-11-27 · #31 로그인: 계획·뼈대·병렬 통합·검증 반영

- 작성자: Kiseok
- 이슈·PR: #31, carti-marketplace #1·#2·#3
- 커밋: `3a27bb1`, `4d43bd6`, `63302fe`, `8c976c3`, `fce340d`, `6c8be1c`, `4ab8e93`

> **요약** 개발자가 08 개발 전달 문서와 이슈를 보고 `/core-dev:flow` express로 구현을 시작했다. AI는 착수 결정을 묻고 ADR-0010·0011, #31 뼈대와 계약, 갈래별 핸드오프를 만들고, 병렬로 진행한 세 갈래를 통합한 뒤 두 갈래 검토의 지적을 고쳤다. 개발자는 기술 선택, 갈래 분할(Mac에서 코어), 테스트 작성 규칙, 로그인 창 닫힘 처리 방식, 기존 테스트 기대값 변경을 정했다.

## 사용 도구

Claude Code(Opus 5.5). 스킬 `core-dev:flow`(express), `core-dev:commit-rules`, `core-dev:handoff`, `docs:adr-manager`, `docs:policy-manager`, `docs:ai-usage`. 읽기 전용 검토 서브에이전트 2건(코드·동시성, 정책 대조). Spring Initializr, Testcontainers, swift 6.4.2(Windows), Vitest, `gh`, 웹 검색(무료 호스팅 비교, Orca 워크트리)

## 요청

- docs·이슈·08 문서·디자인 시안 확인과 flow 진행
- 첫 이슈(#31) 계획, 병렬 분할, 갈래별 핸드오프
- 배포 방식, Supabase 설정 방법, 다른 인증 서비스 질문
- 세 갈래 통합, 검증 지적 모두 반영

## AI 산출물

- ADR-0010(폴더 구성), ADR-0011(무료 배포와 이식 규칙), ADR-WEB-013(창 닫힘을 바로 취소로)
- 08 6절 개발 답 1·7·11·13·14, backend-design 삭제 방식, dev-team-config 계약 위치
- #31 0단계: `api/openapi.yaml`, `db/migrations/V1__auth.sql`, 코어 계약(AuthService·HTTPTransport·화면 상태), 웹 계약 타입, Spring Boot 4.2.0·SwiftPM·Vite 뼈대
- 갈래별 `.handoff-latest.md` 세 개와 4단계(Mac) 핸드오프
- 통합: 세 갈래 병합, AI 로그 번호 079 → 080 재매김, 임시 뷰를 실제 뷰·Supabase 로그인으로 교체
- 수정: 팝업 닫힘을 포커스 복귀 1.5초로 판단, Google `prompt=select_account`, Flyway 기준선, `gradlew` 실행 권한, 같은 계정일 때만 치던 줄 되살리기(토큰 `sub`), 만료 시 기기 세션 삭제, 로그인 시도 번호로 늦은 결과 버리기, 오프라인일 때 마지막 토큰, 2분 타이머 정지, `last_seen_at` 되감기 방지
- 테스트: 새 테스트 추가, 기존 테스트 이름 93개를 given_when_then 세 부분으로
- 정책: ACC-001 구현 위치, COM-010 값 칸(응답 없음 10초), 계정 열린 질문 3개(Sign in with Apple, 로그인 실패 이유, 로그인 화면 문구)
- carti-marketplace: #1 Windows에서 flow 엔진이 WSL bash를 잡는 문제, #2 전역 테스트 작성 규칙, #3 문서 센서 범위와 오탐

## 사람의 판단

- 웹 코어는 처음부터 Swift wasm(AI는 데모까지 TS를 추천), 로그인은 Supabase Auth, 삭제는 `deleted_at`, 처리 결과는 폴링 + 10초(AI 추천 수용)
- 앱 코드는 이 저장소, Web·iOS·Android 폴더를 모두 둠. 배포는 Render로 시작하고 실배포는 나중
- carti-RIBs-Swift `0.1.0` 태그를 직접 찍음. Supabase·Google·GitHub OAuth를 직접 설정함
- 코어 갈래를 Mac에서 맡음. 지시서는 문서가 아니라 핸드오프로
- 테스트 작성 규칙: 메서드 안 given/when/then 주석, 이름 `~했을때_~하면_~하는지`, `_`는 경계에만 쓰고 그 안은 붙여 씀
- 로그인 창 닫힘을 2분 대기 대신 포커스 복귀로 판단(① 선택)
- `select_account`와 Flyway 기준선 설정을 승인
- 검토 지적은 "다 고쳐"
- 기존 테스트 기대값 4곳 변경을 승인(만료 시 signOut 1회, PendingInput 계약)
- 센서 오탐은 플러그인을 고치는 방식으로

## 검증

- 잠근 명령(`./gradlew test`, `swift test`, `npm test`, Windows): 서버 20개 통과, 코어 전부 통과, 웹 59개 통과
- flow 게이트 align·issues·impl·verify 통과. impl 게이트는 엔진이 잠근 명령을 직접 실행했다
- `bash Scripts/check-docs.sh` 통과
- 검토 서브에이전트 2건의 지적(HIGH 후보 1, MEDIUM 4, 정책 불일치 5)을 반영했다. HIGH 후보는 미확인으로 남겼다
- 새 테스트는 RED를 확인한 뒤 구현했다. 동시 첫 로그인 테스트만 처음부터 통과했다(로직이 이미 안전했다)

## 검증하지 못한 것

1. 이번 수정 뒤의 wasm 빌드, `tsc`, 브라우저 동작. Windows에서는 wasm 웹 빌드가 안 된다
2. redirectTo에 붙인 `?attempt=`가 Supabase Redirect URLs(`/**`)와 맞는지, 실제 콜백에 그대로 돌아오는지
3. 같은 이메일로 두 방식 로그인 시 계정 수(ACC-001 규칙 4)와 `app_metadata.provider`의 뜻(AI 로그 081 10번·5번)
4. 실제 Chrome·Safari에서 포커스 신호가 바로 오는지
5. carti-marketplace 수정의 macOS·Linux 동작

## AI의 오류와 정정

1. 0단계에서 Windows로 `server/gradlew`를 커밋해 실행 권한이 빠졌다. Mac에서 발견했고 100755로 고쳤다
2. 개발자의 C 워크트리에서 `npm ci`를 시도하다 실패해 `node_modules`를 절반쯤 지웠다. 알리고 임시 워크트리에서 다시 검증했다
3. Supabase "Data access" 화면을 실제와 다르게 설명했다. 스크린샷을 보고 바로잡았다
4. wasm 웹 빌드가 Windows에서 되는 것으로 보고 갈래를 나눴다. 샘플 README를 읽고 B·C 경계를 다시 나눴다
5. 가짜 타이머에서 `vi.waitFor`가 시간을 앞당기는 것을 놓쳐 테스트 헬퍼가 틀렸다. 바로 넣는 헬퍼를 추가했다
6. 테스트 이름 목록에 `core/.build`의 의존성 테스트가 섞였다. 추적 파일만 다시 뽑았다

## 발견 사항

1. flow 엔진이 Windows에서 `System32\bash.exe`(WSL)를 잡아 센서가 돌지 않았다(carti-marketplace #1)
2. 문서 센서가 저장소 전체를 검사하고, `learned` 주석 예외가 정규식 되돌림으로 무력화되고, 엔진의 `state.md`를 막았다(carti-marketplace #3)
3. Supabase 새 프로젝트의 `public` 스키마 함수 때문에 Flyway가 기준선 없이 시작하지 않는다

## 근거 링크

- 이슈 #31, carti-marketplace #1·#2·#3
- 커밋: 위 머리말
