package com.unwrap.grep.features.account.testing

import com.jayway.jsonpath.JsonPath
import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.support.FakeSupabaseAuth
import jakarta.servlet.http.Cookie
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.ResultActionsDsl
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import java.net.URI
import java.security.MessageDigest
import java.util.Base64
import java.util.UUID

/** AI 도구 연결 테스트 바탕. AI 도구(OAuth 클라이언트)가 하는 일을 MockMvc로 흉내 낸다. */
abstract class ConnectionApiTestSupport : ArchiveApiTestSupport() {

	data class ClientApp(val clientId: String, val redirectUri: String)

	/** 승인 화면을 거쳐 받은 인가 코드와 그때 쓴 PKCE 값. */
	data class Approval(val client: ClientApp, val code: String, val verifier: String, val state: String)

	data class Tokens(val accessToken: String, val refreshToken: String)

	fun register(name: String = "Claude Code", redirectUri: String = "http://localhost:33418/callback"): ClientApp {
		val body = mockMvc.post("/oauth/register") {
			contentType = MediaType.APPLICATION_JSON
			content = """{"client_name":${jsonString(name)},"redirect_uris":["$redirectUri"]}"""
		}.andExpect { status { isCreated() } }.andReturn().response.contentAsString
		return ClientApp(JsonPath.read(body, "$.client_id"), redirectUri)
	}

	fun authorize(client: ClientApp, challenge: String, state: String = "st-1"): ResultActionsDsl =
		mockMvc.get("/oauth/authorize") {
			param("response_type", "code")
			param("client_id", client.clientId)
			param("redirect_uri", client.redirectUri)
			param("code_challenge", challenge)
			param("code_challenge_method", "S256")
			param("state", state)
		}

	/** `/oauth/authorize`부터 Supabase 로그인을 마치고 승인 화면에 닿을 때까지. 승인 화면 쿠키를 돌려준다. */
	fun loginToConsent(client: ClientApp, supabaseToken: String, verifier: String, state: String = "st-1"): Cookie {
		val cookie = authorize(client, s256(verifier), state).andExpect { status { isOk() } }.andReturn().response.getCookie(COOKIE)!!
		mockMvc.get("/oauth/login") {
			param("provider", "google")
			cookie(cookie)
		}.andExpect { status { isFound() } }
		mockMvc.get("/oauth/callback") {
			param("code", FakeSupabaseAuth.issueLoginCode(supabaseToken))
			cookie(cookie)
		}.andExpect { status { isSeeOther() } }
		return cookie
	}

	fun decide(cookie: Cookie, decision: String, requestId: String = cookie.value): ResultActionsDsl =
		mockMvc.post("/oauth/decision") {
			contentType = MediaType.APPLICATION_FORM_URLENCODED
			param("request", requestId)
			param("decision", decision)
			cookie(cookie)
		}

	/** 로그인하고 `허용`을 눌러 인가 코드를 받는다. */
	fun approve(supabaseToken: String, client: ClientApp = register()): Approval {
		val verifier = "verifier-" + UUID.randomUUID() + UUID.randomUUID()
		val cookie = loginToConsent(client, supabaseToken, verifier)
		val page = decide(cookie, "allow").andExpect { status { isOk() } }.andReturn().response.contentAsString
		val redirect = Regex("url=([^\"]+)\"").find(page)!!.groupValues[1].replace("&amp;", "&")
		val query = queryOf(redirect)
		return Approval(client, query.getValue("code"), verifier, query.getValue("state"))
	}

	fun exchange(approval: Approval, verifier: String = approval.verifier): ResultActionsDsl =
		mockMvc.post("/oauth/token") {
			contentType = MediaType.APPLICATION_FORM_URLENCODED
			param("grant_type", "authorization_code")
			param("code", approval.code)
			param("client_id", approval.client.clientId)
			param("redirect_uri", approval.client.redirectUri)
			param("code_verifier", verifier)
		}

	fun refresh(client: ClientApp, refreshToken: String): ResultActionsDsl =
		mockMvc.post("/oauth/token") {
			contentType = MediaType.APPLICATION_FORM_URLENCODED
			param("grant_type", "refresh_token")
			param("refresh_token", refreshToken)
			param("client_id", client.clientId)
		}

	/** 등록부터 토큰까지 한 번에. */
	fun connect(supabaseToken: String, clientName: String = "Claude Code"): Tokens {
		val body = exchange(approve(supabaseToken, register(clientName))).andExpect { status { isOk() } }.andReturn().response.contentAsString
		return Tokens(JsonPath.read(body, "$.access_token"), JsonPath.read(body, "$.refresh_token"))
	}

	fun mcp(accessToken: String?, body: String): ResultActionsDsl =
		mockMvc.post("/mcp") {
			accessToken?.let { header("Authorization", "Bearer $it") }
			accept = MediaType.APPLICATION_JSON
			contentType = MediaType.APPLICATION_JSON
			content = body
		}

	fun callTool(accessToken: String, name: String, arguments: String): ResultActionsDsl =
		mcp(accessToken, """{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"$name","arguments":$arguments}}""")

	/** 도구 결과의 첫 글 내용. */
	fun toolText(result: ResultActionsDsl): String =
		JsonPath.read(result.andReturn().response.contentAsString, "$.result.content[0].text")

	fun listConnections(token: String) = mockMvc.get("/connections") { header("Authorization", "Bearer $token") }

	fun endConnection(token: String, number: Any) = mockMvc.delete("/connections/$number") { header("Authorization", "Bearer $token") }

	fun endAllConnections(token: String) = mockMvc.post("/connections/revoke-all") { header("Authorization", "Bearer $token") }

	fun takeNotices(token: String) = mockMvc.post("/connections/notices") { header("Authorization", "Bearer $token") }

	fun s256(verifier: String): String =
		Base64.getUrlEncoder().withoutPadding().encodeToString(MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray()))

	fun queryOf(uri: String): Map<String, String> =
		URI(uri).rawQuery.split('&').associate { part ->
			val (name, value) = part.split('=', limit = 2)
			name to java.net.URLDecoder.decode(value, Charsets.UTF_8)
		}

	private fun jsonString(value: String) = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

	companion object {
		const val COOKIE = "grep_connect"
	}
}
