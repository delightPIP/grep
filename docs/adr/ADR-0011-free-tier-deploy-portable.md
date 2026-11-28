### ADR-0011 데모 단계 배포는 Render 무료(서버)·Cloudflare Pages(웹)·Supabase로 하고, 옮기기 쉽게 만든다
- 상태: 대체됨 (결정 2 → ADR-0016)
- 날짜: 2026-11-26
- 영역: 공통

> **요약** Kotlin 서버는 Docker 이미지로 Render 무료 웹 서비스에, 웹 정적 파일은 Cloudflare Pages에 올리고, DB·인증·파일은 Supabase를 쓴다(ADR-BCK-006). 발표 노트북의 로컬 실행을 대체 경로로 둔다. 실사용 배포로 옮길 때 설정만 바꾸면 되도록 이식 규칙을 지킨다.

#### 배경

COM-005는 결제 수단이 필요한 서비스를 쓰지 못하게 한다. Supabase는 Kotlin 서버를 띄우지 못하고, ADR-BCK-006은 서버를 Supabase 밖에서 호스팅하도록 정했다. 웹·iOS·Android가 같은 계정 데이터를 써야 하므로 공개 HTTPS 주소가 필요하다(iOS ATS, OAuth 리다이렉트).

#### 결정

1. 서버는 `server/`의 Dockerfile로 빌드한 이미지를 Render 무료 웹 서비스에서 돌린다.
2. 웹은 Vite 빌드 결과를 Cloudflare Pages에 올린다.
3. 이식 규칙: 설정·비밀키는 모두 환경변수, 포트는 `PORT`, `/health` 제공, 서버에 상태를 두지 않음(로컬 디스크에 저장하지 않음), 웹은 API 주소를 빌드 환경변수로 받는다.
4. 처리 워커와 배치는 서버 프로세스 안에서 돈다(ADR-BCK-004).
5. 파일은 서버를 거치지 않고 Supabase 서명 URL로 주고받는다.
6. 잠들기를 막으려고 `/health`를 주기적으로 호출하고, 이 호출이 DB를 한 번 건드려 Supabase 일시 정지도 막는다.
7. 발표 장면의 대체 경로는 노트북 로컬 실행이다.

#### 고려한 대안

| 대안 | 기각 이유 |
| :--- | :--- |
| 노트북 + Cloudflare Tunnel만 | 노트북이 꺼지면 모바일·다른 기기에서 쓸 수 없다. 대체 경로로만 둔다 |
| Google Cloud Run, Koyeb, Oracle Always Free | 결제 수단 등록이 필요해 COM-005를 어긴다 |
| Fly.io, Railway | 상시 무료 플랜이 없다 |
| Supabase Edge Functions로 서버 대체 | ADR-BCK-003(Kotlin)·ADR-BCK-006(Edge Functions 쓰지 않음)과 맞지 않는다 |

#### 결과

- 얻는 것: 카드 없이 공개 HTTPS 주소가 생긴다. 이미지·환경변수 규칙 덕분에 Cloud Run·ECS로 옮길 때 서버·웹 이전은 반나절~하루다.
- 비용: 15분 동안 요청이 없으면 잠들고 깨어나는 데 30초가 넘는다(COM-010 10초 기준이면 `응답 없음`). 512MB·공유 CPU라 처리 동시 실행 수를 작게 둔다. 무료 대역폭이 작다(5GB/월 보고). 무료 조건이 바뀔 수 있다. 무료 조건 수치는 2차 출처 기준이라 붙일 때 공식 문서에서 다시 확인한다.

#### 관련

COM-005, COM-010, ADR-BCK-003, ADR-BCK-004, ADR-BCK-006, ADR-0010
