# 배포 절차

ADR-0011대로 서버는 Render 무료 웹 서비스, 웹은 Cloudflare Pages, DB·인증·파일은 Supabase에 둔다. 이 문서는 계정을 연결하고 처음 올릴 때의 순서와 값의 출처를 적는다. 로컬 실행은 [데모 실행 절차](demo-runbook.md)에 있다.

## 1. 미리 알 것

- Supabase 세션 풀은 15개다. Render 서버는 `SPRING_DATASOURCE_HIKARI_MAXIMUMPOOLSIZE=4`로 연결 4개만 잡는다(`render.yaml`). 로컬 서버(기본 10개)와 함께 떠도 14개다. 로컬 서버를 두 대 띄우면 넘친다.
- 무료 서버는 15분 동안 요청이 없으면 잠들고, 깨어나는 데 1분쯤 걸린다(Render 문서). 앱의 응답 없음 기준(COM-010, 10초)보다 길다. 발표 전에 `/health`를 한 번 불러 깨운다. ADR-0011 결정 6의 주기 호출과 `/health`의 DB 접촉은 아직 없다(6절).
- 무료 서버는 디스크를 남기지 않는다. 서버는 로컬 디스크에 저장하지 않으므로(ADR-0011 결정 3) 영향이 없다.

## 2. 서버(Render)

1. Render 대시보드에서 New → Blueprint로 이 저장소를 고른다. 루트의 `render.yaml`을 읽어 `grep-server` 서비스를 만든다.
2. 지역은 `render.yaml`의 `region`이다(지금 `singapore`). 만든 뒤에는 바꿀 수 없다. Supabase 프로젝트 지역(Project Settings → General)과 가까운 곳이 아니면 만들기 전에 고친다. 가능한 값은 `oregon`·`ohio`·`virginia`·`frankfurt`·`singapore`다.
3. 만들 때 `sync: false` 칸의 값을 묻는다. 3절 표대로 넣는다. 이 질문은 처음 만들 때 한 번뿐이다. 나중에 더한 변수는 대시보드 Environment에서 직접 넣는다.
4. 첫 배포가 끝나면 서비스 주소(`https://<서비스 이름>.onrender.com`)를 `PUBLIC_URL`에 넣고 다시 배포한다. 주소는 서비스를 만든 뒤에야 정해진다.

이미지는 `server/Dockerfile`로 저장소 루트를 문맥 삼아 빌드한다. Render 문서는 문맥 루트의 `.dockerignore`만 언급하고, `server/Dockerfile.dockerignore`를 읽는지는 적지 않았다. 읽지 않아도 Dockerfile이 필요한 경로만 복사하므로 이미지는 같고, 문맥 전송만 커진다.

## 3. 환경변수

### 서버(Render Environment)

이름은 `server/.env.example`과 같다.

| 이름 | 값 | 출처 |
|---|---|---|
| `PORT` | 넣지 않는다 | Render가 넣는다 |
| `DATABASE_URL` | `jdbc:postgresql://<세션 풀러 호스트>:5432/postgres` | Supabase → Connect → Session pooler |
| `DATABASE_USER` | `postgres.<프로젝트 ID>` | 세션 풀러를 쓸 때의 사용자 |
| `DATABASE_PASSWORD` | DB 비밀번호 | Supabase 프로젝트를 만들 때 정한 값 |
| `SUPABASE_URL` | `https://<프로젝트 ID>.supabase.co` | Project Settings → API |
| `SUPABASE_PUBLISHABLE_KEY` | 공개 키 | Project Settings → API Keys. 웹의 `VITE_SUPABASE_PUBLISHABLE_KEY`와 같다 |
| `PUBLIC_URL` | `https://<서비스 이름>.onrender.com` | 2절 4번 |
| `WEB_ORIGIN` | `https://<Pages 프로젝트>.pages.dev` | 4절. 여럿이면 쉼표로 잇는다(로컬 웹도 붙이려면 `,http://localhost:5173`) |
| `GEMINI_API_KEY` | AI Studio 키 | COM-002 규칙 3 |
| `GEMINI_MODEL` | 넣지 않는다 | 비우면 `application.properties` 기본값을 쓴다. 빈 값으로 만들면 기본값이 아니라 빈 값이 된다 |
| `STORAGE_S3_ENDPOINT` | `https://<프로젝트 ID>.supabase.co/storage/v1/s3` | Storage → Settings → S3 Connection |
| `STORAGE_S3_REGION` | S3 지역 | 같은 화면 |
| `STORAGE_S3_ACCESS_KEY_ID` / `STORAGE_S3_SECRET_ACCESS_KEY` | S3 접근 키 | 같은 화면에서 새로 만든다 |
| `STORAGE_BUCKET` | `items`(고정) | `render.yaml` |
| `SPRING_DATASOURCE_HIKARI_MAXIMUMPOOLSIZE` | `4`(고정) | `render.yaml`, 1절 |

`WEB_ORIGIN`에 없는 출처의 사전 요청은 403이다(`AuthApiTest`). 출처는 끝의 `/` 없이 `https://`부터 적는다.

### 웹(Pages 빌드 변수)

Vite는 빌드할 때 값을 박아 넣는다. 값을 바꾸면 다시 빌드해야 한다. 셋 다 브라우저에 들어가는 공개 값이다.

| 이름 | 값 |
|---|---|
| `VITE_API_BASE_URL` | 서버의 `PUBLIC_URL`과 같은 주소 |
| `VITE_SUPABASE_URL` | 서버의 `SUPABASE_URL`과 같다 |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | 서버의 `SUPABASE_PUBLISHABLE_KEY`와 같다 |

## 4. 웹(Cloudflare Pages)

웹 빌드는 두 단계다. `web/`에서 `swift package --swift-sdk swift-6.4.2-RELEASE_wasm js`로 Swift 브리지를 Wasm으로 만들고(`web/.build/plugins/PackageToJS/outputs/Package/`), `npm ci && npm run build`로 `web/dist`를 만든다. 올릴 폴더는 `web/dist`다. Pages 빌드 이미지에는 Swift가 없어 첫 단계를 어디서 돌릴지 정해야 한다.

| 안 | 방식 | 판단 |
|---|---|---|
| A. GitHub Actions에서 빌드해 올리기 | CI의 `web` 잡과 같은 순서(`setup-swift-linux` + Wasm SDK)로 `web/dist`를 만들고 `wrangler pages deploy web/dist`(Direct Upload)로 올린다 | 고른 안. CI가 이미 같은 빌드를 돌리고 있어 순서와 SDK 체크섬을 그대로 쓴다. 저장소 비밀값에 `CLOUDFLARE_API_TOKEN`(Pages 편집 권한)과 `CLOUDFLARE_ACCOUNT_ID`가 필요하다 |
| B. Pages Git 연동 빌드에서 Swift 받기 | 빌드 명령에서 Swift 도구 모음과 Wasm SDK를 내려받아 설치한 뒤 빌드 | 매 빌드마다 큰 내려받기가 생기고, 빌드 이미지에 맞는 Swift 배포판을 따로 맞춰야 한다. Pages 빌드 시간 제한 안에 끝나는지 확인되지 않았다 |
| C. Wasm 산출물을 커밋 | Pages가 `npm run build`만 돌린다 | `.build/`를 저장소에 넣게 되고, 코어가 바뀔 때마다 산출물 갱신을 잊으면 웹이 옛 코어로 돈다 |

A를 쓸 때의 Pages 설정:

- 프로젝트는 Direct Upload로 만든다(`wrangler pages project create <이름> --production-branch main`). Direct Upload로 만든 프로젝트는 나중에 Git 연동으로 바꿀 수 없다.
- Pages 대시보드의 빌드 명령·출력 폴더는 쓰지 않는다. 빌드 변수(3절)는 Actions 잡의 `env`로 넘긴다.
- 배포 워크플로 파일은 아직 없다. 넣을 때 CI `web` 잡의 Wasm 빌드 단계를 그대로 옮기고 `npm run build` 뒤에 `wrangler pages deploy`를 붙인다.

## 5. Supabase 설정

Authentication → URL Configuration:

- Site URL: 웹 주소(`https://<Pages 프로젝트>.pages.dev`)
- Redirect URLs에 더할 것
  - `https://<Pages 프로젝트>.pages.dev/auth-callback.html`: 웹 로그인 팝업이 돌아오는 곳(`web/public/auth-callback.html`)
  - `<PUBLIC_URL>/oauth/callback`: AI 도구 연결 승인 화면의 로그인(ADR-BCK-015)
  - 로컬용 `http://localhost:5173/auth-callback.html`, `http://localhost:8080/oauth/callback`은 그대로 둔다

Google 로그인의 리디렉션 주소는 Supabase 주소(`<SUPABASE_URL>/auth/v1/callback`)라 웹 주소가 바뀌어도 그대로다. Google Cloud 콘솔의 승인된 JavaScript 원본에 `http://localhost:5173`을 넣어 두었다면 Pages 주소도 더한다.

## 6. 첫 배포 확인 순서

1. `curl https://<서비스 이름>.onrender.com/health` → `{"status":"ok"}`. 잠들어 있었으면 1분쯤 걸린다.
2. `curl -i https://<서비스 이름>.onrender.com/me` → 401(로그인 전). 500이면 Render 로그에서 DB 연결(`DATABASE_*`)을 본다.
3. 사전 요청: `curl -i -X OPTIONS https://<서비스 이름>.onrender.com/me -H "Origin: https://<Pages 프로젝트>.pages.dev" -H "Access-Control-Request-Method: GET"` → 200과 `Access-Control-Allow-Origin`. 403이면 `WEB_ORIGIN`을 본다.
4. 웹 주소를 열고 Google로 로그인한다. 팝업이 닫히지 않으면 5절 Redirect URLs를 본다.
5. 링크 하나를 저장하고 요약이 생기는지 본다. `failed`면 `GEMINI_API_KEY`를 본다.
6. 파일 하나를 저장하고 다시 연다. 실패하면 `STORAGE_S3_*`를 본다.
7. AI 도구 연결 주소 `<PUBLIC_URL>/mcp`로 연결을 시작해 승인 화면 로그인까지 간다.

## 7. 남은 일

- 잠들기 막기(ADR-0011 결정 6): 주기 호출 수단(GitHub Actions 예약 실행 등)과 `/health`의 DB 접촉이 없다.
- 웹 배포 워크플로(4절 A안)와 Cloudflare 비밀값 등록.
- 계정 연결과 실제 배포는 하지 않았다. 이 문서의 Render·Cloudflare 화면 이름은 2026-11-28 문서 기준이다.
