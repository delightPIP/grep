package com.unwrap.grep.features.account.adapters.supabase

import com.unwrap.grep.features.account.domain.AuthProvider
import com.unwrap.grep.features.account.domain.LoginExchange
import com.unwrap.grep.features.account.domain.SupabaseLogin
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import org.springframework.web.util.UriComponentsBuilder
import tools.jackson.core.JacksonException
import tools.jackson.module.kotlin.jacksonObjectMapper
import java.io.IOException
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.net.http.HttpTimeoutException
import java.time.Duration

/**
 * Supabase Auth의 PKCE 로그인(supabase-js `exchangeCodeForSession`과 같은 요청).
 * - 시작: `GET /auth/v1/authorize?provider=…&redirect_to=…&code_challenge=…&code_challenge_method=s256`
 * - 교환: `POST /auth/v1/token?grant_type=pkce` `{auth_code, code_verifier}`, 헤더 `apikey`
 * 근거: https://supabase.com/docs/guides/auth/sessions/pkce-flow
 * 공개 키(publishable key)는 비밀이 아니지만 환경변수로 받는다(ADR-0011).
 */
@Component
class SupabasePkceLogin(
	@Value("\${grep.supabase.url}") private val supabaseUrl: String,
	@Value("\${grep.supabase.publishable-key}") private val publishableKey: String,
) : SupabaseLogin {
	private val json = jacksonObjectMapper()
	private val client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build()
	private val authBase = "${supabaseUrl.trimEnd('/')}/auth/v1"

	override fun authorizeUrl(provider: AuthProvider, redirectTo: String, codeChallenge: String): URI =
		UriComponentsBuilder.fromUriString("$authBase/authorize")
			.queryParam("provider", provider.claimValue)
			.queryParam("redirect_to", redirectTo)
			.queryParam("code_challenge", codeChallenge)
			.queryParam("code_challenge_method", "s256")
			.encode()
			.build()
			.toUri()

	override fun exchange(authCode: String, codeVerifier: String): LoginExchange {
		if (publishableKey.isBlank()) {
			log.warn("SUPABASE_PUBLISHABLE_KEY is not set")
			return LoginExchange.Failure(DENIED)
		}
		val body = json.writeValueAsString(mapOf("auth_code" to authCode, "code_verifier" to codeVerifier))
		val request = HttpRequest.newBuilder(URI("$authBase/token?grant_type=pkce"))
			.timeout(Duration.ofSeconds(15))
			.header("Content-Type", "application/json")
			.header("apikey", publishableKey)
			.POST(HttpRequest.BodyPublishers.ofString(body))
			.build()
		val response = try {
			client.send(request, HttpResponse.BodyHandlers.ofString())
		} catch (e: HttpTimeoutException) {
			return LoginExchange.Failure(NO_RESPONSE)
		} catch (e: IOException) {
			return LoginExchange.Failure(DISCONNECTED)
		}
		if (response.statusCode() != 200) {
			log.warn("supabase pkce exchange http {}", response.statusCode())
			return LoginExchange.Failure(if (response.statusCode() >= 500) NO_RESPONSE else DENIED)
		}
		val token = try {
			json.readTree(response.body()).path("access_token").asString("")
		} catch (e: JacksonException) {
			""
		}
		return if (token.isBlank()) LoginExchange.Failure(DENIED) else LoginExchange.Success(token)
	}

	override fun signOut(accessToken: String) {
		val request = HttpRequest.newBuilder(URI("$authBase/logout?scope=local"))
			.timeout(Duration.ofSeconds(10))
			.header("apikey", publishableKey)
			.header("Authorization", "Bearer $accessToken")
			.POST(HttpRequest.BodyPublishers.noBody())
			.build()
		runCatching { client.send(request, HttpResponse.BodyHandlers.discarding()) }
			.onFailure { log.warn("supabase sign out failed: {}", it.javaClass.simpleName) }
	}

	private companion object {
		/** ACC-001 `✗ 로그인 실패: <이유>`의 이유 낱말. */
		const val DISCONNECTED = "연결 끊김"
		const val NO_RESPONSE = "응답 없음"
		const val DENIED = "권한 거부"
		val log = LoggerFactory.getLogger(SupabasePkceLogin::class.java)
	}
}
