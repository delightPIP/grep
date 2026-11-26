# grep
Don' just store | grep and connect

## 폴더

| 폴더 | 내용 |
|---|---|
| `api/openapi.yaml` | 클라이언트와 서버의 계약 원본(ADR-0001) |
| `server/` | Kotlin Spring Boot 서버(ADR-BCK-003·004) |
| `db/migrations/` | 순수 SQL 마이그레이션. 서버 빌드가 복사해 Flyway로 실행 |
| `core/` | Swift 공유 코어(ADR-WEB-007). 웹·iOS·Android가 같이 씀 |
| `web/` | 웹(Vite React + wasm 코어) |
| `ios/`, `android/` | 웹 다음에 만듦 |
| `docs/` | 정책·ADR·기획 문서([문서 지도](docs/README.md)) |

폴더 구성과 배포 방식은 [ADR-0010](docs/adr/ADR-0010-monorepo-top-level-folders.md), [ADR-0011](docs/adr/ADR-0011-free-tier-deploy-portable.md).

## 테스트

Docker가 켜져 있어야 한다(서버 테스트가 Postgres 컨테이너를 띄움).

```sh
cd server && ./gradlew test && cd ../core && swift test && cd ../web && npm test
```

환경변수는 `server/.env.example`, `web/.env.example`을 본다. `web`의 wasm 빌드는 macOS·Linux에서만 된다.
