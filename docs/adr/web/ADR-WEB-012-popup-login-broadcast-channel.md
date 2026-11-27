### ADR-WEB-012 웹 로그인은 팝업으로 하고, 결과는 콜백 페이지가 BroadcastChannel로 넘긴다
- 상태: 대체됨 (→ ADR-WEB-013)
- 날짜: 2026-11-26
- 영역: 웹

> **요약** 웹 로그인은 팝업 창에서 Supabase PKCE로 한다. 제공자가 돌려보낸 콜백 페이지가 code/error를 BroadcastChannel로 여는 창에 넘기고, 여는 창이 code를 세션으로 바꾼다. 창 닫힘은 알 수 없어서 2분이 지나면 `응답 없음`으로 끝낸다.

#### 배경

공유 코어의 `AuthService.signIn`은 "로그인 창을 열고 끝날 때까지 기다린다"는 계약이다(#31 0단계). Google 로그인 페이지는 `Cross-Origin-Opener-Policy: same-origin`을 보낸다(2026-11-26 curl로 확인). 그래서 팝업이 Google에 닿는 순간 여는 창이 팝업과의 연결을 잃는다. `popup.closed`가 곧바로 true가 되고 `window.opener`도 끊긴다.

#### 결정

1. 로그인은 팝업에서 한다. 사용자 동작 안에서 빈 창을 먼저 열고, PKCE 로그인 주소로 보낸다.
2. 제공자는 `auth-callback.html`로 돌려보낸다. 이 페이지는 주소의 search·hash를 BroadcastChannel로 넘기고 창을 닫는다. code를 세션으로 바꾸는 일은 PKCE 검증값을 가진 여는 창이 한다.
3. 창을 X로 닫은 것은 알 수 없다. 2분 안에 결과가 오지 않으면 `✗ 로그인 실패: 응답 없음`으로 끝낸다.
4. 로그인 코드는 `web/auth/supabase-auth.ts` 하나에 둔다(ADR-BCK-006 결정 7).

#### 고려한 대안

| 대안 | 기각 이유 |
| :--- | :--- |
| 전체 페이지 이동(Supabase 기본) | 가장 안정적이다. 하지만 `signIn`이 끝나지 않고 페이지를 떠나서, 돌아온 뒤 결과를 읽는 메서드가 필요해 공유 코어 계약이 바뀐다 |
| 팝업 + `popup.closed`·`window.opener` | Google의 COOP 때문에 로그인 중에도 닫힌 것으로 보여 `로그인 취소됨`이 잘못 뜬다 |

#### 결과

- 얻는 것: 공유 코어 계약을 바꾸지 않는다. 로그인 중에도 터미널 화면 상태가 그대로 남는다.
- 비용: 창을 닫으면 최대 2분 동안 버튼이 잠긴다. Supabase Redirect URLs에 `/auth-callback.html` 경로를 등록해야 한다. 스크립트로 창이 닫히지 않으면 콜백 페이지에 `이 창을 닫아도 됩니다`가 남는다.

#### 관련

ADR-BCK-006, ADR-WEB-007, ACC-001, #31
