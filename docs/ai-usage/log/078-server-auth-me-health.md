# 2026-11-26 · 서버 인증 /health, /me와 세션 만료 구현

- 작성자: Kiseok
- 이슈·PR: #31
- 커밋: ff77083

> **요약** 핸드오프 문서를 이어받아 #31 A 갈래(서버 인증)의 `/health`, `/me`를 구현했다. 사람은 구현 결과를 확인하고 커밋과 이 로그 작성을 승인했다.

## 사용 도구

Claude Code(Opus 5.5). `core-dev:handoff`(recall), `core-dev:commit-rules`, `docs:ai-usage`, web-fetch 서브에이전트(Supabase 문서 확인), Gradle·Testcontainers

## 요청

`.handoff-latest.md`를 읽고 이어서 진행하라는 요청. 이후 커밋과 AI 활용 로그 작성을 승인했다("ㅇㅇ").

## AI 산출물

- Supabase 공식 문서(jwt-fields, jwts, signing-keys)로 토큰 클레임 확인: 세션은 `session_id`(항상 있음), 로그인 방식은 `app_metadata.provider`, `aud`는 `authenticated`, `iss`는 `<SUPABASE_URL>/auth/v1`
- `server/` 아래 계정 모듈(`features/account`의 domain·adapters), 보안 설정과 `/health`(`app/SecurityConfig.kt`), 오류 응답(`shared/kernel/ApiError.kt`)
- `application.properties`에 issuer·audience·ES256 검증 설정 추가
- 테스트 16개: 세션 만료 경계값 단위 테스트 4개, 가짜 JWKS 서버와 직접 서명한 토큰으로 API 통합 테스트 12개

## 사람의 판단

- AI의 구현과 보고를 그대로 받아들이고 커밋과 로그 작성을 승인했다.

## 검증

- 구현 전 테스트를 먼저 돌려 실패(컴파일 실패)를 확인했다.
- 구현 후 `cd server && ./gradlew test`: 17개 모두 통과(기존 컨텍스트 테스트 포함, Docker Testcontainers 사용)
- 별도 코드 리뷰는 하지 않음.

## 검증하지 못한 것

1. Google·GitHub 로그인 토큰의 `app_metadata.provider` 값이 `google`·`github`인지는 문서에 없어 가정했다. 다르면 실제 로그인이 모두 `unauthorized`가 된다. 실제 Supabase 토큰으로 확인해야 한다.
2. 세션 시작 시각은 실제 로그인 시각이 아니라 서버가 그 세션을 처음 본 시각이라, 90일 만료가 실제보다 늦게 걸릴 수 있다.
3. 실제 Supabase 프로젝트와 연결해 실행하지 않았다.

## 근거 링크

#31, ff77083
