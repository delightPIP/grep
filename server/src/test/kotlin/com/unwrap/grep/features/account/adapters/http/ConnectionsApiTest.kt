package com.unwrap.grep.features.account.adapters.http

import com.unwrap.grep.features.account.testing.ConnectionApiTestSupport
import org.hamcrest.Matchers.contains
import kotlin.test.Test
import kotlin.test.assertEquals

/** AI 도구 연결 목록과 끊기. 근거: ACC-002 규칙 4·6~11, openapi `/connections…`. */
class ConnectionsApiTest : ConnectionApiTestSupport() {

	private val ping = """{"jsonrpc":"2.0","id":1,"method":"ping"}"""

	private fun mcpStatus(accessToken: String) = mcp(accessToken, ping).andReturn().response.status

	@Test
	fun `두도구를연결했을때_목록을보면_번호순으로도구이름과연결주소를주는지`() {
		// given
		val token = newUser()
		connect(token, "Claude Code")
		connect(token, "ChatGPT")

		// when
		val list = listConnections(token)

		// then
		list.andExpect {
			status { isOk() }
			jsonPath("$.mcpUrl") { value("http://grep.test/mcp") }
			jsonPath("$.connections[*].number") { value(contains(1, 2)) }
			jsonPath("$.connections[*].client") { value(contains("Claude Code", "ChatGPT")) }
			jsonPath("$.connections[0].lastReadAt") { value(null as Any?) }
		}
	}

	@Test
	fun `연결하나를끊으면_그연결만다음요청부터거부되고다른연결은그대로인지`() {
		// given
		val token = newUser()
		val first = connect(token, "Claude Code")
		val second = connect(token, "ChatGPT")

		// when
		val ended = endConnection(token, 1)

		// then
		ended.andExpect {
			status { isOk() }
			jsonPath("$.result") { value("ended") }
			jsonPath("$.client") { value("Claude Code") }
		}
		assertEquals(401, mcpStatus(first.accessToken))
		assertEquals(200, mcpStatus(second.accessToken))
		listConnections(token).andExpect { jsonPath("$.connections[*].number") { value(contains(2)) } }
	}

	@Test
	fun `이미끊긴연결과없는번호와남의번호를끊으면_alreadyEnded와404인지`() {
		// given
		val token = newUser()
		connect(token)
		endConnection(token, 1)
		val stranger = newUser()
		connect(stranger)

		// when
		val again = endConnection(token, 1)
		val missing = endConnection(token, 9)
		val others = endConnection(newUser(), 1)
		val invalid = endConnection(token, "a")

		// then
		again.andExpect { jsonPath("$.result") { value("alreadyEnded") } }
		missing.andExpect { status { isNotFound() } }
		others.andExpect { status { isNotFound() } }
		invalid.andExpect { status { isBadRequest() } }
	}

	@Test
	fun `모든연결을끊으면_끊은수를주고모든연결이거부되며갱신도막히는지`() {
		// given
		val token = newUser()
		val first = connect(token)
		val second = connect(token)

		// when
		val result = endAllConnections(token)

		// then
		result.andExpect { jsonPath("$.count") { value(2) } }
		assertEquals(401, mcpStatus(first.accessToken))
		assertEquals(401, mcpStatus(second.accessToken))
		listConnections(token).andExpect { jsonPath("$.connections.length()") { value(0) } }
	}

	@Test
	fun `다른기기에서모두끊거나만료됐을때_알림을한번만주고직접끊은연결은알리지않는지`() {
		// given
		val token = newUser()
		connect(token, "Claude Code")
		connect(token, "ChatGPT")
		endConnection(token, 1)
		connect(token, "Cursor")
		jdbc.sql("UPDATE connections SET access_expires_at = now() - interval '31 days' WHERE user_id = :userId AND number = 3")
			.param("userId", userIdOf(token)).update()
		jdbc.sql("UPDATE connections SET ended_at = now(), end_reason = 'revoked' WHERE user_id = :userId AND number = 2")
			.param("userId", userIdOf(token)).update()

		// when
		val first = takeNotices(token)
		val second = takeNotices(token)

		// then
		first.andExpect {
			jsonPath("$.ended[*].client") { value(contains("ChatGPT", "Cursor")) }
			jsonPath("$.ended[*].reason") { value(contains("revoked", "expired")) }
		}
		second.andExpect { jsonPath("$.ended.length()") { value(0) } }
	}

	@Test
	fun `30일동안갱신하지않은연결일때_갱신하면_invalid_grant이고만료로끝나는지`() {
		// given
		val token = newUser()
		val client = register()
		val body = exchange(approve(token, client)).andReturn().response.contentAsString
		val refreshToken = Regex("\"refresh_token\":\"([^\"]+)\"").find(body)!!.groupValues[1]
		jdbc.sql("UPDATE connections SET access_expires_at = now() - interval '31 days' WHERE user_id = :userId")
			.param("userId", userIdOf(token)).update()

		// when
		val refreshed = refresh(client, refreshToken).andReturn().response

		// then
		assertEquals(400, refreshed.status)
		takeNotices(token).andExpect { jsonPath("$.ended[0].reason") { value("expired") } }
	}
}
