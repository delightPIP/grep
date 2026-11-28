package com.unwrap.grep.support

import com.nimbusds.jose.JWSAlgorithm
import com.nimbusds.jose.JWSHeader
import com.nimbusds.jose.crypto.ECDSASigner
import com.nimbusds.jose.jwk.Curve
import com.nimbusds.jose.jwk.ECKey
import com.nimbusds.jose.jwk.JWKSet
import com.nimbusds.jose.jwk.gen.ECKeyGenerator
import com.nimbusds.jwt.JWTClaimsSet
import com.nimbusds.jwt.SignedJWT
import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.time.Duration
import java.time.Instant
import java.util.Date
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Supabase Auth 대역. 직접 만든 P-256 키로 접근 토큰을 서명하고, 그 공개키를 JWKS로 내준다.
 * 클레임 모양은 Supabase 문서(https://supabase.com/docs/guides/auth/jwt-fields)를 따른다.
 */
object FakeSupabaseAuth {
	private val signingKey: ECKey = ECKeyGenerator(Curve.P_256).keyID("test-key").generate()
	private val strangerKey: ECKey = ECKeyGenerator(Curve.P_256).keyID("test-key").generate()

	/** PKCE 로그인 대역: 인가 코드 → 접근 토큰. 코드는 한 번만 바꿔 준다. */
	private val loginCodes = ConcurrentHashMap<String, String>()
	val signedOutTokens: MutableSet<String> = ConcurrentHashMap.newKeySet()

	private val server: HttpServer = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0).apply {
		createContext("/auth/v1/.well-known/jwks.json") { exchange ->
			val body = JWKSet(signingKey.toPublicJWK()).toString().toByteArray()
			exchange.responseHeaders.add("Content-Type", "application/json")
			exchange.sendResponseHeaders(200, body.size.toLong())
			exchange.responseBody.use { it.write(body) }
		}
		// POST /auth/v1/token?grant_type=pkce {auth_code, code_verifier}. 공개 키 헤더가 없으면 401.
		createContext("/auth/v1/token") { exchange ->
			val body = exchange.requestBody.readAllBytes().decodeToString()
			val code = Regex("\"auth_code\":\"([^\"]+)\"").find(body)?.groupValues?.get(1)
			val token = code?.let { loginCodes.remove(it) }
			val ok = token != null && exchange.requestHeaders.getFirst("apikey") == PUBLISHABLE_KEY
			val response = if (ok) """{"access_token":"$token","token_type":"bearer"}""" else """{"error":"invalid_grant"}"""
			exchange.responseHeaders.add("Content-Type", "application/json")
			exchange.sendResponseHeaders(if (ok) 200 else 400, response.length.toLong())
			exchange.responseBody.use { it.write(response.toByteArray()) }
		}
		createContext("/auth/v1/logout") { exchange ->
			exchange.requestHeaders.getFirst("Authorization")?.removePrefix("Bearer ")?.let { signedOutTokens += it }
			exchange.sendResponseHeaders(204, -1)
			exchange.close()
		}
		start()
	}

	const val PUBLISHABLE_KEY = "test-publishable-key"

	/** Google·GitHub 로그인을 마치고 돌아올 때 붙는 코드를 하나 만든다. 바꾸면 [accessToken]을 준다. */
	fun issueLoginCode(accessToken: String): String =
		UUID.randomUUID().toString().also { loginCodes[it] = accessToken }

	val baseUrl: String = "http://127.0.0.1:${server.address.port}"
	val issuer: String = "$baseUrl/auth/v1"
	val jwkSetUri: String = "$issuer/.well-known/jwks.json"

	fun token(
		sub: String = UUID.randomUUID().toString(),
		provider: String = "google",
		sessionId: String = UUID.randomUUID().toString(),
		issuer: String = this.issuer,
		audience: String = "authenticated",
		expiresIn: Duration = Duration.ofHours(1),
		signedByStranger: Boolean = false,
	): String {
		val now = Instant.now()
		val claims = JWTClaimsSet.Builder()
			.subject(sub)
			.issuer(issuer)
			.audience(audience)
			.issueTime(Date.from(now.minusSeconds(60)))
			.expirationTime(Date.from(now.plus(expiresIn)))
			.claim("role", "authenticated")
			.claim("email", "same@example.com")
			.claim("session_id", sessionId)
			.claim("app_metadata", mapOf("provider" to provider, "providers" to listOf(provider)))
			.build()
		val key = if (signedByStranger) strangerKey else signingKey
		val jwt = SignedJWT(JWSHeader.Builder(JWSAlgorithm.ES256).keyID(key.keyID).build(), claims)
		jwt.sign(ECDSASigner(key))
		return jwt.serialize()
	}
}
