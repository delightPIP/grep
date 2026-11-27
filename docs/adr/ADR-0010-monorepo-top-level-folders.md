### ADR-0010 앱 코드는 이 저장소에 두고 계약·서버·공유 코어·플랫폼별 앱을 최상위 폴더로 나눈다
- 상태: 채택
- 날짜: 2026-11-26
- 영역: 공통

> **요약** 앱 코드를 문서와 같은 저장소에 두고, `api/`(OpenAPI 계약), `server/`(Kotlin), `db/migrations/`(순수 SQL), `core/`(Swift 공유 코어), `web/`, `ios/`, `android/`를 최상위 폴더로 나눈다. 웹을 먼저 만들고, iOS·Android도 만든다.

#### 배경

[08 개발 전달 문서](../planning/collab-2026-11-26/08-po-dev-handoff.md) 판 0.6 기준으로 구현을 시작한다. 앱 저장소 위치와 계약 파일 위치가 [개발 팀 설정](../dev-team-config.md)에서 비어 있었다. 정책·ADR이 이 저장소에 있고, 2인 팀이 데모 일정(11/29 보장)에 맞춰야 한다. 웹이 첫 플랫폼이고 iOS·Android도 만들며, 세 플랫폼은 `core/`를 공유한다(ADR-WEB-007).

#### 결정

1. 앱 코드는 이 저장소에 둔다.
2. 최상위 폴더는 `api/`, `server/`, `db/migrations/`, `core/`, `web/`, `ios/`, `android/`이다. `docs/`는 그대로 둔다.
3. 계약 원본은 `api/openapi.yaml` 하나다(ADR-0001).
4. `core/`는 carti-RIBs-Swift를 GitHub 태그로 의존한다.
5. `ios/`·`android/`는 첫 구현 전까지 README만 둔다.

#### 고려한 대안

| 대안 | 기각 이유 |
| :--- | :--- |
| 앱을 별도 저장소로 | 정책·ADR과 코드가 갈라져 PR 하나로 정책 대조와 문서 검사를 할 수 없다. 2인 팀에 저장소 관리 비용만 는다 |
| `apps/`·`packages/` 모노레포 관례 | JS 워크스페이스 관례라 Gradle·SwiftPM이 섞인 구성에서는 얻는 게 없고 경로만 깊어진다 |

#### 결과

- 얻는 것: 정책 ID와 코드·테스트를 한 PR에서 대조한다. 플랫폼을 추가할 때 폴더 하나만 늘린다.
- 비용: 언어마다 빌드 도구가 따로라(Gradle, SwiftPM, npm) CI에 경로별 필터가 필요하다.

#### 관련

ADR-0001, ADR-WEB-007, ADR-BCK-004, ADR-0011, 08 개발 전달 문서
