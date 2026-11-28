package com.unwrap.grep.features.account.adapters.http

import com.unwrap.grep.features.account.testing.ConnectionApiTestSupport
import com.unwrap.grep.support.FakeSupabaseAuth
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** AI 도구 연결의 OAuth 인가 서버. 근거: ADR-BCK-015 결정 1·2, ARC-009 규칙 7·9·사용자 문구, ACC-001 문구, RFC 7591·7636·8414·9728. */
class OAuthAuthorizationApiTest : ConnectionApiTestSupport() {

	@Test
	fun `AI도구가연결을찾을때_메타데이터를읽으면_자원주소와인가엔드포인트와S256을주는지`() {
		// given
		val resourceUrl = "/.well-known/oauth-protected-resource"

		// when
		val resource = mockMvc.get(resourceUrl)
		val server = mockMvc.get("/.well-known/oauth-authorization-server")

		// then
		resource.andExpect {
			status { isOk() }
			jsonPath("$.resource") { value("http://grep.test/mcp") }
			jsonPath("$.authorization_servers[0]") { value("http://grep.test") }
		}
		server.andExpect {
			status { isOk() }
			jsonPath("$.issuer") { value("http://grep.test") }
			jsonPath("$.authorization_endpoint") { value("http://grep.test/oauth/authorize") }
			jsonPath("$.token_endpoint") { value("http://grep.test/oauth/token") }
			jsonPath("$.registration_endpoint") { value("http://grep.test/oauth/register") }
			jsonPath("$.code_challenge_methods_supported[0]") { value("S256") }
		}
	}

	@Test
	fun `토큰없이_mcp를부르면_401과보호자원메타데이터주소를주는지`() {
		// given
		val body = """{"jsonrpc":"2.0","id":1,"method":"ping"}"""

		// when
		val withoutToken = mcp(null, body).andReturn().response
		val withWrongToken = mcp("gca_wrong", body).andReturn().response
		val withAppToken = mcp(newUser(), body).andReturn().response

		// then
		assertEquals(401, withoutToken.status)
		assertEquals("Bearer resource_metadata=\"http://grep.test/.well-known/oauth-protected-resource\"", withoutToken.getHeader("WWW-Authenticate"))
		assertEquals(401, withWrongToken.status)
		assertTrue(withWrongToken.getHeader("WWW-Authenticate")!!.contains("error=\"invalid_token\""))
		assertEquals(401, withAppToken.status)
	}

	@Test
	fun `로그인전일때_승인을시작하면_ACC001로그인화면을먼저보이는지`() {
		// given
		val client = register()

		// when
		val page = authorize(client, s256("v".repeat(43))).andReturn().response

		// then
		assertEquals(200, page.status)
		assertTrue(page.contentAsString.contains("그렙 ~ \$ 로그인 필요"))
		assertTrue(page.contentAsString.contains("Google로 계속"))
		assertTrue(page.contentAsString.contains("GitHub로 계속"))
		assertTrue(page.getHeader("Content-Security-Policy")!!.contains("frame-ancestors 'none'"))
		assertTrue(page.getHeader("Set-Cookie")!!.contains("SameSite=Lax"))
	}

	@Test
	fun `로그인하고나면_승인화면에AI도구이름과계정과ARC009문구를보이는지`() {
		// given
		val token = newUser()
		val client = register(name = "Claude Code")

		// when
		val cookie = loginToConsent(client, token, "verifier-" + "x".repeat(40))
		val page = mockMvc.get("/oauth/consent") { cookie(cookie) }.andReturn().response.contentAsString

		// then
		assertTrue(page.contains("<h1>그렙 연결</h1>"))
		assertTrue(page.contains("Claude Code가 그렙 계정 same@example.com(Google)에 연결하려고 함"))
		assertTrue(page.contains("이 도구는 보관함 전체를 검색하고 읽을 수 있음(읽기 전용). 읽어 간 내용은 그 도구 제공사의 정책을 따름"))
		assertTrue(page.contains(">허용</button>") && page.contains(">거부</button>"))
		assertTrue(token in FakeSupabaseAuth.signedOutTokens)
	}

	@Test
	fun `Google동의화면에서취소했을때_돌아오면_로그인취소됨을보이는지`() {
		// given
		val client = register()
		val cookie = authorize(client, s256("v".repeat(43))).andReturn().response.getCookie(COOKIE)!!
		mockMvc.get("/oauth/login") {
			param("provider", "github")
			cookie(cookie)
		}

		// when
		val page = mockMvc.get("/oauth/callback") {
			param("error", "access_denied")
			cookie(cookie)
		}.andReturn().response.contentAsString

		// then
		assertTrue(page.contains("✗ 로그인 취소됨"))
	}

	@Test
	fun `AI도구이름에태그가있을때_승인화면에보이면_이스케이프하는지`() {
		// given
		val client = register(name = "<script>alert(1)</script>")

		// when
		val cookie = loginToConsent(client, newUser(), "verifier-" + "y".repeat(40))
		val page = mockMvc.get("/oauth/consent") { cookie(cookie) }.andReturn().response.contentAsString

		// then
		assertFalse(page.contains("<script>"))
		assertTrue(page.contains("&lt;script&gt;"))
	}

	@Test
	fun `허용하면_연결됨문구와함께코드와state를돌려주고_코드를토큰으로바꿀수있는지`() {
		// given
		val token = newUser()
		val approval = approve(token)

		// when
		val tokens = exchange(approval)

		// then
		assertEquals("st-1", approval.state)
		tokens.andExpect {
			status { isOk() }
			header { string("Cache-Control", "no-store") }
			jsonPath("$.token_type") { value("Bearer") }
			jsonPath("$.expires_in") { value(3600) }
			jsonPath("$.access_token") { exists() }
			jsonPath("$.refresh_token") { exists() }
		}
	}

	@Test
	fun `허용한뒤화면에_ARC009허용뒤문구를보이는지`() {
		// given
		val cookie = loginToConsent(register(name = "Claude Code"), newUser(), "verifier-" + "z".repeat(40))

		// when
		val page = decide(cookie, "allow").andReturn().response.contentAsString

		// then
		assertTrue(page.contains("✓ 연결됨  Claude Code"))
		assertTrue(page.contains("  이 창을 닫고 Claude Code로 돌아가기"))
		assertTrue(page.contains("url=http://localhost:33418/callback?code="))
	}

	@Test
	fun `거부하면_연결안함문구를보이고_access_denied로돌려보내는지`() {
		// given
		val cookie = loginToConsent(register(name = "Claude Code"), newUser(), "verifier-" + "w".repeat(40))

		// when
		val page = decide(cookie, "deny").andReturn().response.contentAsString

		// then
		assertTrue(page.contains("· 연결 안 함  Claude Code"))
		assertTrue(page.contains("  이 창을 닫아도 됨. 그렙 자료는 넘기기(복사)로 계속 쓸 수 있음"))
		assertTrue(page.contains("callback?error=access_denied&amp;state=st-1"))
		assertFalse(page.contains("code="))
	}

	@Test
	fun `폼의요청ID가쿠키와다를때_허용하면_코드를주지않는지`() {
		// given
		val cookie = loginToConsent(register(), newUser(), "verifier-" + "q".repeat(40))

		// when
		val forged = decide(cookie, "allow", requestId = "someone-else").andReturn().response

		// then
		assertEquals(400, forged.status)
		assertFalse(forged.contentAsString.contains("code="))
	}

	@Test
	fun `등록하지않은돌아갈주소일때_승인을시작하면_돌려보내지않고화면에알리는지`() {
		// given
		val client = register(redirectUri = "https://claude.ai/api/mcp/auth_callback")

		// when
		val response = authorize(client.copy(redirectUri = "https://evil.example/cb"), s256("v".repeat(43))).andReturn().response

		// then
		assertEquals(400, response.status)
		assertEquals(null, response.getHeader("Location"))
		assertTrue(response.contentAsString.contains("✗ 연결할 수 없음"))
	}

	@Test
	fun `PKCE없이승인을시작하면_돌아갈주소로invalid_request를돌려보내는지`() {
		// given
		val client = register()

		// when
		val response = mockMvc.get("/oauth/authorize") {
			param("response_type", "code")
			param("client_id", client.clientId)
			param("redirect_uri", client.redirectUri)
			param("state", "s")
		}.andReturn().response

		// then
		assertEquals(302, response.status)
		assertTrue(response.getHeader("Location")!!.startsWith("http://localhost:33418/callback?error=invalid_request&state=s"))
	}

	@Test
	fun `https도루프백도아닌주소로_등록하면_invalid_redirect_uri인지`() {
		// given
		val bodies = listOf(
			"""{"client_name":"x","redirect_uris":["http://evil.example/cb"]}""",
			"""{"client_name":"x","redirect_uris":["javascript:alert(1)"]}""",
			"""{"client_name":"x","redirect_uris":[]}""",
			"""{"client_name":"x"}""",
		)

		// when
		val responses = bodies.map { body ->
			mockMvc.post("/oauth/register") {
				contentType = MediaType.APPLICATION_JSON
				content = body
			}.andReturn().response
		}

		// then
		responses.forEach { response ->
			assertEquals(400, response.status)
			assertTrue(response.contentAsString.contains("invalid_redirect_uri"))
		}
	}

	@Test
	fun `PKCE검증값이틀리거나코드를두번쓰면_invalid_grant인지`() {
		// given
		val first = approve(newUser())
		val second = approve(newUser())

		// when
		val wrongVerifier = exchange(first, verifier = "wrong-" + "v".repeat(40)).andReturn().response
		val afterWrong = exchange(first).andReturn().response
		val ok = exchange(second).andReturn().response
		val reused = exchange(second).andReturn().response

		// then
		assertEquals(400, wrongVerifier.status)
		assertTrue(wrongVerifier.contentAsString.contains("invalid_grant"))
		assertEquals(400, afterWrong.status)
		assertEquals(200, ok.status)
		assertEquals(400, reused.status)
		assertTrue(reused.contentAsString.contains("invalid_grant"))
	}

	@Test
	fun `갱신토큰으로바꾸면_새토큰이되고옛접근토큰과옛갱신토큰은거부되는지`() {
		// given
		val token = newUser()
		val client = register()
		val body = exchange(approve(token, client)).andReturn().response.contentAsString
		val oldAccess = Regex("\"access_token\":\"([^\"]+)\"").find(body)!!.groupValues[1]
		val oldRefresh = Regex("\"refresh_token\":\"([^\"]+)\"").find(body)!!.groupValues[1]

		// when
		val refreshed = refresh(client, oldRefresh).andReturn().response.contentAsString
		val newAccess = Regex("\"access_token\":\"([^\"]+)\"").find(refreshed)!!.groupValues[1]
		val reusedRefresh = refresh(client, oldRefresh).andReturn().response

		// then
		assertEquals(401, mcp(oldAccess, """{"jsonrpc":"2.0","id":1,"method":"ping"}""").andReturn().response.status)
		assertEquals(200, mcp(newAccess, """{"jsonrpc":"2.0","id":1,"method":"ping"}""").andReturn().response.status)
		assertEquals(400, reusedRefresh.status)
	}
}
