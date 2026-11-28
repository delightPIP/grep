### ADR-BCK-018 MCP 서버는 SDK 없이 Spring MVC에서 JSON-RPC로 직접 만든다
- 상태: 채택
- 날짜: 2026-11-28
- 영역: 백엔드

> **요약** `/mcp`는 공식 Kotlin SDK를 쓰지 않고 Spring MVC 컨트롤러가 JSON-RPC를 직접 처리한다. 상태 없는 Streamable HTTP로 POST 한 번에 JSON 응답 하나를 준다. OAuth 엔드포인트도 Spring으로 만든다.

#### 배경

ADR-BCK-003 결정 4는 MCP 서버를 공식 Kotlin SDK로 만들기로 했고, ADR-BCK-015 결정 5는 착수 첫 단계에서 실제 연결을 실험하고 SDK가 원격 OAuth를 받쳐 주지 못하면 인가 엔드포인트는 Spring으로 만들게 했다. #124 1단계에서 Kotlin SDK 0.16.0(`kotlin-sdk-server-jvm`)을 확인하니 서버 전송(Streamable HTTP, SSE)이 Ktor 서버(`ktor-server-core`, `ktor-server-sse`)에 묶여 있어 Spring MVC 요청에 얹을 수 없었다. 서버가 쓰는 MCP 기능은 읽기 도구 두 개(ARC-009)뿐이다.

#### 결정

1. `/mcp`는 상태 없는 Streamable HTTP 서버다. POST 한 번에 JSON 응답 하나로 답하고, GET 스트림(SSE)과 세션 ID는 두지 않는다.
2. 처리하는 메서드는 `initialize`, `ping`, `tools/list`, `tools/call`과 알림(답 없이 202)뿐이다. 그 밖은 JSON-RPC `method not found`다.
3. OAuth 인가 서버 엔드포인트(메타데이터, 등록, 인가, 토큰)도 Spring으로 만든다(ADR-BCK-015 결정 5의 대체 경로).
4. 지원 프로토콜 버전은 `2025-06-18`(기본), `2025-11-25`, `2025-03-26`이다. 클라이언트가 이 중 하나를 요청하면 그대로 쓴다.

#### 고려한 대안

| 대안 | 기각 이유 |
| :--- | :--- |
| Kotlin SDK와 Ktor 서버를 Spring 옆에 함께 띄우기 | 웹 서버가 둘이 되고 Render 무료 512MB에서 메모리가 빠듯하다. 인증 필터도 두 번 만든다 |
| SDK core 위에 서블릿 전송을 직접 쓰기 | 코루틴·kotlinx.serialization·Ktor 의존이 그대로 들어오고 전송 계층은 결국 직접 짠다 |
| 공식 Java SDK의 서블릿 전송 | Reactor 의존이 늘고, 쓰는 메서드 네 개에 비해 무겁다 |

#### 결과

- 얻는 것: 새 의존 없이 기존 Spring 보안 필터·JSON 처리로 끝난다. 로컬 Claude Code로 등록·OAuth 승인·연결을 확인했다(#124).
- 비용: MCP 사양이 바뀌면(새 프로토콜 버전, 필수 메서드) 직접 따라가야 한다. 서버가 먼저 보내는 알림·진행 상황 스트림이 필요해지면 SSE를 더하거나 SDK를 다시 검토한다.

#### 관련

ADR-BCK-003(결정 4 대체), ADR-BCK-004, ADR-BCK-015, ARC-009, #124
