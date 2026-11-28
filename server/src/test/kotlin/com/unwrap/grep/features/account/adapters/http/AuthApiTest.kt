package com.unwrap.grep.features.account.adapters.http

import com.unwrap.grep.TestcontainersConfiguration
import com.unwrap.grep.support.FakeSupabaseAuth
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Import
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.options
import java.time.Duration
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

@Import(TestcontainersConfiguration::class)
@SpringBootTest
@AutoConfigureMockMvc
class AuthApiTest {

	@Autowired
	lateinit var mockMvc: MockMvc

	@Autowired
	lateinit var jdbc: JdbcClient

	companion object {
		@JvmStatic
		@DynamicPropertySource
		fun supabase(registry: DynamicPropertyRegistry) {
			registry.add("spring.security.oauth2.resourceserver.jwt.jwk-set-uri") { FakeSupabaseAuth.jwkSetUri }
			registry.add("spring.security.oauth2.resourceserver.jwt.issuer-uri") { FakeSupabaseAuth.issuer }
			// 배포에서는 로컬 웹과 Cloudflare Pages 주소처럼 여러 출처를 쉼표로 넣는다
			registry.add("grep.web-origin") { "http://web.test, https://pages.test" }
		}
	}

	private fun getMe(token: String?, query: String = "") = mockMvc.get("/me$query") {
		if (token != null) header("Authorization", "Bearer $token")
	}

	private fun userIdOf(token: String): String {
		val body = getMe(token).andExpect { status { isOk() } }.andReturn().response.contentAsString
		return Regex("\"userId\":\"([^\"]+)\"").find(body)!!.groupValues[1]
	}

	private fun countUsers(sub: String): Int =
		jdbc.sql("SELECT count(*) FROM users WHERE external_id = :sub").param("sub", sub).query(Int::class.java).single()

	private fun seedSession(token: String, sessionId: UUID, startedAgo: Duration, lastSeenAgo: Duration) {
		userIdOf(token)
		val now = OffsetDateTime.now(ZoneOffset.UTC)
		jdbc.sql("UPDATE sessions SET started_at = :started, last_seen_at = :lastSeen WHERE id = :id")
			.param("started", now.minus(startedAgo))
			.param("lastSeen", now.minus(lastSeenAgo))
			.param("id", sessionId)
			.update()
	}

	@Test
	fun `토큰이없을때_health를부르면_ok를주는지`() {
		// given: 토큰 없음

		// when
		val result = mockMvc.get("/health")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.status") { value("ok") }
		}
	}

	@Test
	fun `토큰이없을때_me를부르면_unauthorized로막는지`() {
		// given: 토큰 없음

		// when
		val result = getMe(null)

		// then
		result.andExpect {
			status { isUnauthorized() }
			jsonPath("$.code") { value("unauthorized") }
		}
	}

	@Test
	fun `다른키로서명된토큰일때_me를부르면_unauthorized로막는지`() {
		// given
		val token = FakeSupabaseAuth.token(signedByStranger = true)

		// when
		val result = getMe(token)

		// then
		result.andExpect {
			status { isUnauthorized() }
			jsonPath("$.code") { value("unauthorized") }
		}
	}

	@Test
	fun `만료된토큰일때_me를부르면_unauthorized로막는지`() {
		// given
		val token = FakeSupabaseAuth.token(expiresIn = Duration.ofHours(-1))

		// when
		val result = getMe(token)

		// then
		result.andExpect {
			status { isUnauthorized() }
			jsonPath("$.code") { value("unauthorized") }
		}
	}

	@Test
	fun `발급자나대상이다른토큰일때_me를부르면_unauthorized로막는지`() {
		// given
		val wrongIssuer = FakeSupabaseAuth.token(issuer = "https://other.supabase.co/auth/v1")
		val wrongAudience = FakeSupabaseAuth.token(audience = "anon")

		// when
		val results = listOf(getMe(wrongIssuer), getMe(wrongAudience))

		// then
		results.forEach {
			it.andExpect {
				status { isUnauthorized() }
				jsonPath("$.code") { value("unauthorized") }
			}
		}
	}

	@Test
	fun `지원하지않는로그인방식일때_me를부르면_unauthorized로막는지`() {
		// given
		val token = FakeSupabaseAuth.token(provider = "email")

		// when
		val result = getMe(token)

		// then
		result.andExpect {
			status { isUnauthorized() }
			jsonPath("$.code") { value("unauthorized") }
		}
	}

	@Test
	fun `처음로그인했을때_me를두번부르면_계정을하나만만들고같은사용자를주는지`() {
		// given
		val sub = UUID.randomUUID().toString()
		val token = FakeSupabaseAuth.token(sub = sub, provider = "github")

		// when
		val first = getMe(token)
		val second = getMe(token)

		// then
		first.andExpect {
			status { isOk() }
			jsonPath("$.authProvider") { value("github") }
			jsonPath("$.itemCount") { value(0) }
		}
		val firstId = Regex("\"userId\":\"([^\"]+)\"").find(first.andReturn().response.contentAsString)!!.groupValues[1]
		second.andExpect { jsonPath("$.userId") { value(firstId) } }
		assertEquals(1, countUsers(sub))
	}

	@Test
	fun `같은이메일로Google과GitHub로로그인했을때_me를부르면_다른계정이되는지`() {
		// given: 두 토큰 모두 email이 same@example.com이고, 외부 ID까지 같은 가장 나쁜 경우
		val sub = UUID.randomUUID().toString()
		val google = FakeSupabaseAuth.token(sub = sub, provider = "google")
		val github = FakeSupabaseAuth.token(sub = sub, provider = "github")

		// when
		val googleUserId = userIdOf(google)
		val githubUserId = userIdOf(github)

		// then
		assertNotEquals(googleUserId, githubUserId)
	}

	@Test
	fun `주소에다른사용자ID를넣었을때_me를부르면_무시하고토큰의사용자를주는지`() {
		// given
		val token = FakeSupabaseAuth.token()
		val ownUserId = userIdOf(token)

		// when
		val result = getMe(token, query = "?userId=${UUID.randomUUID()}")

		// then
		result.andExpect { jsonPath("$.userId") { value(ownUserId) } }
	}

	@Test
	fun `30일넘게안쓴세션일때_me를부르면_session_expired를주고갱신하지않는지`() {
		// given
		val sessionId = UUID.randomUUID()
		val token = FakeSupabaseAuth.token(sessionId = sessionId.toString())
		seedSession(token, sessionId, startedAgo = Duration.ofDays(40), lastSeenAgo = Duration.ofDays(31))

		// when
		val first = getMe(token)
		val second = getMe(token)

		// then
		listOf(first, second).forEach {
			it.andExpect {
				status { isUnauthorized() }
				jsonPath("$.code") { value("session_expired") }
			}
		}
	}

	@Test
	fun `로그인한지90일넘은세션일때_me를부르면_session_expired를주는지`() {
		// given
		val sessionId = UUID.randomUUID()
		val token = FakeSupabaseAuth.token(sessionId = sessionId.toString())
		seedSession(token, sessionId, startedAgo = Duration.ofDays(91), lastSeenAgo = Duration.ofDays(1))

		// when
		val result = getMe(token)

		// then
		result.andExpect {
			status { isUnauthorized() }
			jsonPath("$.code") { value("session_expired") }
		}
	}

	@Test
	fun `웹주소에서사전요청을보냈을때_me를부르면_CORS를허용하는지`() {
		// given: grep.web-origin = http://web.test, https://pages.test

		// when
		val result = mockMvc.options("/me") {
			header("Origin", "http://web.test")
			header("Access-Control-Request-Method", "GET")
			header("Access-Control-Request-Headers", "authorization")
		}

		// then
		result.andExpect {
			status { isOk() }
			header { string("Access-Control-Allow-Origin", "http://web.test") }
		}
	}

	@Test
	fun `웹주소를여럿넣었을때_두번째주소에서사전요청을보내면_CORS를허용하는지`() {
		// given: grep.web-origin = http://web.test, https://pages.test

		// when
		val result = mockMvc.options("/me") {
			header("Origin", "https://pages.test")
			header("Access-Control-Request-Method", "GET")
			header("Access-Control-Request-Headers", "authorization")
		}

		// then
		result.andExpect {
			status { isOk() }
			header { string("Access-Control-Allow-Origin", "https://pages.test") }
		}
	}

	@Test
	fun `넣지않은주소에서사전요청을보냈을때_me를부르면_CORS를막는지`() {
		// given: grep.web-origin = http://web.test, https://pages.test

		// when
		val result = mockMvc.options("/me") {
			header("Origin", "https://other.test")
			header("Access-Control-Request-Method", "GET")
		}

		// then
		result.andExpect {
			status { isForbidden() }
			header { doesNotExist("Access-Control-Allow-Origin") }
		}
	}
}
