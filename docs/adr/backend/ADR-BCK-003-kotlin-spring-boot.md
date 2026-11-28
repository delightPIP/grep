### ADR-BCK-003 서버 언어는 Kotlin, 프레임워크는 Spring Boot로 한다
- 상태: 일부 대체됨 (결정 4 → ADR-BCK-018)
- 날짜: 2026-11-25
- 영역: 백엔드

> **요약** 서버는 Kotlin과 Spring Boot, Gradle 멀티 모듈로 만든다. 추출은 Apache Tika, LLM 호출은 공식 Anthropic Java SDK, MCP는 공식 Kotlin SDK를 쓴다.

#### 배경

이 서버가 하는 일은 대부분 파일·웹 본문 추출, LLM 호출, 비동기 작업, MCP 제공이고 요청량은 적다. ADR-0001로 서버가 클라이언트와 분리되었으므로 언어는 서버 기준으로만 고른다. Swift는 서버 쪽 생태계가 부족해 후보에서 뺐다.

#### 결정

1. Kotlin과 Spring Boot를 쓰고, 모듈은 Gradle 멀티 모듈로 나눈다(ADR-BCK-004).
2. 파일 형식 판별과 텍스트 추출은 Apache Tika로 한다. 4.x(2026-08 정식)를 기준으로 검토한다.
3. LLM 호출은 공식 Anthropic Java SDK로 한다.
4. MCP 서버는 공식 Kotlin SDK로 만든다.
5. 다른 언어로 옮길 수 있도록 ADR-0001(스펙 우선, 언어 밖 API 테스트)과 ADR-BCK-002(순수 SQL 마이그레이션)를 지킨다.

#### 고려한 대안

| 대안 | 기각 이유 |
| :--- | :--- |
| Python (FastAPI) | 추출과 AI 생태계가 가장 강하고 MVP가 빠르다. 그러나 모듈 경계를 컴파일 단계에서 강제할 수 없고 타입이 약하다 |
| Rust | 안전하고 가볍고 타입 사고가 Swift와 가깝다. 그러나 PDF·docx 추출 생태계가 약하고, 공식 LLM SDK가 없으며, 학습 비용이 MVP 일정을 잡아먹는다 |
| Java | Kotlin과 같은 생태계지만 더 장황하고, Swift 개발자에게 덜 자연스럽다 |
| Swift (서버) | 추출·LLM·MCP 생태계가 부족해 개발자가 제외했다 |

#### 결과

- 얻는 것: Gradle 모듈로 모듈 경계를 컴파일 단계에서 강제한다(ADR-BCK-004). 정적 타입과 코루틴으로 비동기 작업을 다룬다. Tika 하나로 여러 파일 형식을 처리한다.
- 비용: JVM이라 메모리를 많이 써서 무료·소형 서버에서 부담이 된다. AI 관련 새 도구는 Python보다 늦게 나온다. MCP Kotlin SDK의 원격 OAuth 지원을 확인하지 못해 스파이크가 필요하다. Tika 4.x는 기본 출력이 Markdown으로 바뀌었다.

#### 관련

ADR-0001, ADR-BCK-002, ADR-BCK-004
