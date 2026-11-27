# 데모 실행 절차

리허설(11/30)과 발표(12/1)에서 그렙을 로컬로 띄우는 순서다. 시드 내용과 장면별 기대 결과는 [데모 시드 자료](demo-seed.md)에 있다. 2026-11-27에 Windows에서 이 순서로 띄워 장면표를 실측했다.

## 1. 서버는 한 대만 켠다

- 서버와 웹은 한 컴퓨터(Windows 또는 Mac)에서만 띄운다. DB는 Supabase 세션 풀러(`pooler.supabase.com:5432`)를 쓰는데 풀이 15개이고, 서버 하나가 연결 10개를 잡는다. 두 대를 켜면 연결이 모자라 한쪽이 막힌다(`EMAXCONNSESSION`).
- 다른 컴퓨터의 서버, 다른 세션이 띄운 서버를 먼저 끈다.

## 2. 환경변수

- 서버: `server/.env`(`.gitignore` 대상). 칸은 `server/.env.example`과 같다.
  - 세션 풀러 주소를 쓰면 `DATABASE_USER`는 `postgres.<프로젝트 ID>`다.
  - `GEMINI_API_KEY`가 없으면 서버는 뜨지만 무대 저장(L2) 요약이 생기지 않고 `failed`가 된다.
  - 비밀값 파일은 워크트리 폴더가 아니라 메인 체크아웃에 둔다. 워크트리를 지우면 함께 사라진다.
- 웹: `web/.env.local`(`VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_API_BASE_URL=http://localhost:8080`).

## 3. 서버 띄우기

```bash
cd server
set -a && . <(tr -d '\r' < .env) && set +a   # Windows Git Bash. macOS는 tr 없이 . ./.env
./gradlew bootRun
```

`Started GrepServerApplicationKt`가 나오면 된다. `curl localhost:8080/me`가 401이면 정상이다(로그인 전).

## 4. 웹(Wasm) 빌드와 띄우기

웹은 Swift 브리지를 Wasm으로 빌드한 결과물(`web/.build/plugins/PackageToJS/outputs/Package/`)이 있어야 뜬다. 없으면 브라우저에 `Failed to resolve import "../.build/plugins/PackageToJS/outputs/Package/index.js"`가 나온다. 코어나 `web/Sources/`가 바뀌면 다시 빌드한다.

- macOS·Linux: `cd web && swift package --swift-sdk swift-6.4.2-RELEASE_wasm js`
- Windows: Windows Swift로는 Wasm 빌드가 안 된다. Docker의 Linux 컨테이너에서 CI와 같은 SDK로 빌드한다. BridgeJS 코드 생성에 node가 필요해 컨테이너에 넣는다.

```bash
# 레포 루트에서. 처음 한 번은 Wasm SDK를 받느라 몇 분 걸린다(볼륨에 남음).
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -v grep-swiftpm-cache:/root/.swiftpm -v grep-wb:/tmp/wb \
  -w /src/web swift:6.4.2 bash -c '
  apt-get update -qq >/dev/null && apt-get install -y -qq nodejs >/dev/null
  swift sdk list | grep -q "^swift-6.4.2-RELEASE_wasm$" || swift sdk install \
    https://download.swift.org/swift-6.4.2-release/wasm-sdk/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE_wasm.artifactbundle.tar.gz \
    --checksum 83baca83553f8c443cda7b84800912e6e709c3acd2e7ebf277794ca5836c0da5
  swift package --scratch-path /tmp/wb --swift-sdk swift-6.4.2-RELEASE_wasm js
  rm -rf .build/plugins/PackageToJS/outputs/Package && mkdir -p .build/plugins/PackageToJS/outputs
  cp -r /tmp/wb/plugins/PackageToJS/outputs/Package .build/plugins/PackageToJS/outputs/'
```

- 빌드 폴더(`--scratch-path`)를 컨테이너 볼륨에 두는 것은 Windows 폴더에 Linux 빌드 산출물이 섞이지 않게 하려는 것이다. 결과물만 `web/.build/`로 복사한다.
- SDK checksum은 `.github/workflows/ci.yml`의 web 잡과 같은 값이다.

빌드한 뒤:

```bash
cd web && npm ci && npm run dev    # http://localhost:5173
```

## 5. 계정 상태 확인

| 계정 | 로그인 | 상태 |
|---|---|---|
| A | GitHub | 자료 0건, 번호 0 |
| B | Google | 시드 34건(S번호 = 번호), 처리 작업 0건 |

- 무대 전에 계정 B에서 아무것도 저장하지 않는다. 저장하면 35번이 생겨 무대 저장(L2)의 번호가 대본과 어긋난다.
- 리허설이 끝나면 무대 브라우저에서 `로그아웃`해 둔다. 터미널 기록(COM-009)은 브라우저에 남아 이전 출력이 그대로 보인다.

## 6. 계정 초기화와 시드 다시 넣기

리허설에서 계정에 자료가 생겼을 때 되돌리는 방법이다. 시드 도구는 번호를 한 번이라도 받은 계정을 거부하므로(demo-seed 2절 7·8번), 먼저 그 계정의 자료와 번호를 지운다. 되돌릴 수 없는 작업이라 대상 계정(`auth_provider`)을 확인하고 실행한다.

1. Storage 원본 지우기: 그 계정 자료의 `items.object_path`를 모아 버킷 `items`에서 지운다(S3 호환 API, `STORAGE_S3_*` 키).
2. DB 지우기: 트랜잭션 하나로 그 계정의 `items`·`uploads`를 지우고(`item_jobs`는 함께 지워진다) `users.last_item_number`를 0으로 둔다. 사용자 행과 로그인은 남긴다.
3. 계정 B면 시드를 다시 넣는다. 서버가 떠 있어도 된다(시드는 빈 포트에 뜨고 DB 연결 2개만 쓴다).

```bash
cd server
set -a && . <(tr -d '\r' < .env) && set +a
./gradlew seedDemo -Pemail=<계정 B 이메일>     # "✓ 자료 34건을 넣었다", S01 → 1 … S34 → 34
```

- 시드는 처리 작업을 만들지 않아 하루 AI 처리 한도(COM-005)를 쓰지 않는다. 처리 작업 행을 지우면 그날 한도 집계도 0부터 다시 센다.
- 2026-11-27에 이 순서로 두 번 되돌렸다(테스트 자료 정리, 장면표 실측 중 계정 B에 생긴 글 2건).
