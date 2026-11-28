# 배포 절차

ADR-0011·ADR-0016대로 서버와 웹은 Render 무료 웹 서비스 하나(서버가 웹 정적 파일을 함께 내보냄), DB·인증·파일은 Supabase에 둔다. 이 문서는 계정을 연결하고 처음 올릴 때의 순서와 값의 출처를 적는다. 로컬 실행은 [데모 실행 절차](demo-runbook.md)에 있다.

## 1. 미리 알 것

- Supabase 세션 풀은 15개다. Render 서버는 `SPRING_DATASOURCE_HIKARI_MAXIMUMPOOLSIZE=4`로 연결 4개만 잡는다(`render.yaml`). 로컬 서버(기본 10개)와 함께 떠도 14개다. 로컬 서버를 두 대 띄우면 넘친다.
- 무료 서버는 15분 동안 요청이 없으면 잠들고, 깨어나는 데 1분쯤 걸린다(Render 문서). 앱의 응답 없음 기준(COM-010, 10초)보다 길다. 외부 무료 핑으로 깨워 둔다(ADR-0016 결정 3, 6절). 무료 시간은 계정당 월 750시간이라 무료 서비스는 하나만 둔다.
- 무료 서버는 디스크를 남기지 않는다. 서버는 로컬 디스크에 저장하지 않으므로(ADR-0011 결정 3) 영향이 없다.

## 2. 서버(Render)

1. 둘 중 하나로 만든다.
   - GitHub 계정을 연결할 수 있으면: New → Blueprint로 이 저장소를 고른다. 루트의 `render.yaml`을 읽어 `grep-server` 서비스를 만든다. push하면 자동으로 다시 배포한다.
   - 연결할 수 없으면(저장소 관리자 권한이 없어 Render GitHub 앱을 설치하지 못할 때): New → Web Service → Public Git Repository에 저장소 주소를 넣는다. `render.yaml`은 읽지 않으므로 Runtime `Docker`, Dockerfile Path `./server/Dockerfile`, Docker Build Context `.`, Health Check Path `/health`, Instance Type `Free`를 직접 넣고 3절 변수를 넣는다. 공개 저장소 주소로 만든 서비스는 자동 배포가 없어 대시보드 Manual Deploy나 Deploy Hook으로 다시 배포한다(Render 문서 Deploys).
2. 지역은 `render.yaml`의 `region`이다(지금 `singapore`). 만든 뒤에는 바꿀 수 없다. Supabase 프로젝트 지역(Project Settings → General)과 가까운 곳이 아니면 만들기 전에 고친다. 가능한 값은 `oregon`·`ohio`·`virginia`·`frankfurt`·`singapore`다.
3. 만들 때 `sync: false` 칸의 값을 묻는다. 3절 표대로 넣는다. 이 질문은 처음 만들 때 한 번뿐이다. 나중에 더한 변수는 대시보드 Environment에서 직접 넣는다.
4. 첫 배포가 끝나면 서비스 주소(`https://<서비스 이름>.onrender.com`)를 `PUBLIC_URL`에 넣고 다시 배포한다. 주소는 서비스를 만든 뒤에야 정해진다.

이미지는 `server/Dockerfile`로 저장소 루트를 문맥 삼아 빌드한다. 웹(Swift Wasm → Vite)도 이 이미지에서 함께 빌드한다(ADR-0016). Render는 서비스 환경변수를 Docker 빌드 인자로 넘기므로(Render 문서 Docker) `SUPABASE_URL`·`SUPABASE_PUBLISHABLE_KEY`가 그대로 웹에 들어간다. 첫 빌드는 Swift·Node 단계 때문에 길다. Render 문서는 문맥 루트의 `.dockerignore`만 언급하고, `server/Dockerfile.dockerignore`를 읽는지는 적지 않았다. 읽지 않아도 Dockerfile이 필요한 경로만 복사하므로 이미지는 같고, 문맥 전송만 커진다.

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
| `WEB_ORIGIN` | `http://localhost:5173` | 웹이 같은 주소라 배포용으로는 필요 없다. 로컬 웹으로 배포 서버를 부를 때만 쓴다. 여럿이면 쉼표로 잇는다 |
| `GEMINI_API_KEY` | AI Studio 키 | COM-002 규칙 3 |
| `GEMINI_MODEL` | 넣지 않는다 | 비우면 `application.properties` 기본값을 쓴다. 빈 값으로 만들면 기본값이 아니라 빈 값이 된다 |
| `STORAGE_S3_ENDPOINT` | `https://<프로젝트 ID>.supabase.co/storage/v1/s3` | Storage → Settings → S3 Connection |
| `STORAGE_S3_REGION` | S3 지역 | 같은 화면 |
| `STORAGE_S3_ACCESS_KEY_ID` / `STORAGE_S3_SECRET_ACCESS_KEY` | S3 접근 키 | 같은 화면에서 새로 만든다 |
| `STORAGE_BUCKET` | `items`(고정) | `render.yaml` |
| `SPRING_DATASOURCE_HIKARI_MAXIMUMPOOLSIZE` | `4`(고정) | `render.yaml`, 1절 |

`WEB_ORIGIN`에 없는 출처의 사전 요청은 403이다(`AuthApiTest`). 출처는 끝의 `/` 없이 `https://`부터 적는다.

### 웹(빌드 때 들어가는 값)

Vite는 빌드할 때 값을 박아 넣는다. 값을 바꾸면 다시 배포해야 한다. 셋 다 브라우저에 들어가는 공개 값이다. 서버 이미지에서 빌드할 때 `server/Dockerfile`이 아래처럼 채운다.

| 이름 | 값 |
|---|---|
| `VITE_API_BASE_URL` | 비움(같은 출처로 부름) |
| `VITE_SUPABASE_URL` | 서버의 `SUPABASE_URL` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | 서버의 `SUPABASE_PUBLISHABLE_KEY` |

## 4. 웹을 따로 호스팅으로 옮길 때

ADR-0011이 골랐던 Cloudflare Pages나 Vercel로 옮길 때는 같은 `web/dist`를 올리고, `VITE_API_BASE_URL`을 서버 주소로, 서버의 `WEB_ORIGIN`을 웹 주소로 바꾼다. `server/Dockerfile`의 `wasm`·`web` 단계와 `SPRING_WEB_RESOURCES_STATIC_LOCATIONS` 줄은 지운다. Pages·Vercel 빌드 환경에는 Swift가 없어 Wasm은 GitHub Actions(CI `web` 잡과 같은 순서)에서 빌드해 올려야 하고, 저장소 비밀값(호스팅 토큰)을 넣으려면 관리자 권한이 필요하다.

## 5. Supabase 설정

Authentication → URL Configuration:

- Site URL: 웹 주소(`<PUBLIC_URL>`, 서버와 같다)
- Redirect URLs에 더할 것
  - `<PUBLIC_URL>/auth-callback.html`: 웹 로그인 팝업이 돌아오는 곳(`web/public/auth-callback.html`)
  - `<PUBLIC_URL>/oauth/callback`: AI 도구 연결 승인 화면의 로그인(ADR-BCK-015)
  - 로컬용 `http://localhost:5173/auth-callback.html`, `http://localhost:8080/oauth/callback`은 그대로 둔다

Google 로그인의 리디렉션 주소는 Supabase 주소(`<SUPABASE_URL>/auth/v1/callback`)라 웹 주소가 바뀌어도 그대로다. Google Cloud 콘솔의 승인된 JavaScript 원본에 `http://localhost:5173`을 넣어 두었다면 `<PUBLIC_URL>`도 더한다.

## 6. 첫 배포 확인 순서

1. `curl https://<서비스 이름>.onrender.com/health` → `{"status":"ok"}`. 잠들어 있었으면 1분쯤 걸린다.
2. `curl -i https://<서비스 이름>.onrender.com/me` → 401(로그인 전). 500이면 Render 로그에서 DB 연결(`DATABASE_*`)을 본다.
3. `https://<서비스 이름>.onrender.com/`을 열면 그렙 로그인 화면이 뜬다. 빈 화면이면 브라우저 콘솔에서 `.wasm`·`/assets/` 요청을 본다.
4. Google로 로그인한다. 팝업이 닫히지 않으면 5절 Redirect URLs를 본다.
5. 링크 하나를 저장하고 요약이 생기는지 본다. `failed`면 `GEMINI_API_KEY`를 본다.
6. 파일 하나를 저장하고 다시 연다. 실패하면 `STORAGE_S3_*`를 본다.
7. AI 도구 연결 주소 `<PUBLIC_URL>/mcp`로 연결을 시작해 승인 화면 로그인까지 간다.

8. 외부 무료 핑(UptimeRobot, cron-job.org 등)에 `https://<서비스 이름>.onrender.com/health`를 10분 간격으로 등록한다(ADR-0016 결정 3). 20분 뒤 다시 열어 바로 뜨는지 본다.

## 7. 남은 일

- `/health`는 DB에 닿지 않는다. Supabase 무료 프로젝트의 쉬는 상태를 막으려면 DB 접촉이 필요하다(ADR-0011 결정 6).
- 이 문서의 Render 화면 이름은 2026-11-28 문서 기준이다.
