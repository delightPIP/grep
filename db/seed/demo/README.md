# 데모 시드 파일

[데모 시드 자료](../../../docs/planning/demo-seed.md) 3·4절의 34건과 무대용 L2다. 모두 팀이 만든 발표용 가상 자료다(COM-002 규칙 3). 파일·글·가상 기사·요약은 AI가 초안을 만들고 개발자가 확인했다(demo-seed 7절).

| 위치 | 내용 |
|---|---|
| `seed.json` | 시드 도구(#69)가 읽는 목록. 자료마다 형식, 제목, 저장일(`savedDaysAgo`, 넣는 날 D 기준), 파일·글·링크, 검색용 본문, 미리 만든 요약 두 종, 태그, 상태(`blocked`면 `blockedReason`: S07 `no_text`, S33 `login_required`) |
| `files/` | 파일 19개. 이름은 `S번호_제목` |
| `texts/` | 붙여 넣는 글 7개 |
| `articles/` | 가상 기사 6개의 원본 HTML. 공개본은 `https://carti1108.github.io/grep-seed-demo/` |
| `stage/` | 무대에서 끌어다 놓을 L2(시드에 넣지 않음) |

- 검색 낱말 규칙(demo-seed 2절 5번)은 제목·본문·요약·태그 모두에 지킨다. `찾기 텀블러` 8건, `찾기 텀블러 캠페인` 4건이 나와야 한다.
- PDF 글꼴은 나눔고딕(SIL Open Font License)을 넣었다.

## 넣기(#69)

```bash
cd server && ./gradlew seedDemo -Pemail=<계정 B 이메일>   # 로그인 방식은 기본 google, -Pprovider=github로 바꿈
```

- DB·스토리지 연결은 서버와 같은 환경변수(`DATABASE_URL`, `STORAGE_S3_*` 등)를 쓴다. 이메일은 화면·로그에 찍지 않는다.
- 계정은 Supabase `auth.users`의 이메일과 로그인 방식으로 찾는다. 앱에서 한 번도 로그인하지 않은 계정이면 멈춘다.
- 번호를 한 번이라도 받은 계정(`last_item_number > 0`)이면 거부한다(demo-seed 2절 7·8번). 다시 넣으려면 새 계정을 쓴다.
- 요약·태그·찾기 본문은 `seed.json` 값을 넣고 처리 작업(`item_jobs`)을 만들지 않는다. 그래서 워커가 다시 처리하지 않고 하루 AI 처리 한도도 쓰지 않는다.
