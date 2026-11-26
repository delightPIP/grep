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

/**
 * Supabase Auth 대역. 직접 만든 P-256 키로 접근 토큰을 서명하고, 그 공개키를 JWKS로 내준다.
 * 클레임 모양은 Supabase 문서(https://supabase.com/docs/guides/auth/jwt-fields)를 따른다.
 */
object FakeSupabaseAuth {
	private val signingKey: ECKey = ECKeyGenerator(Curve.P_256).keyID("test-key").generate()
	private val strangerKey: ECKey = ECKeyGenerator(Curve.P_256).keyID("test-key").generate()

	private val server: HttpServer = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0).apply {
		createContext("/auth/v1/.well-known/jwks.json") { exchange ->
			val body = JWKSet(signingKey.toPublicJWK()).toString().toByteArray()
			exchange.responseHeaders.add("Content-Type", "application/json")
			exchange.sendResponseHeaders(200, body.size.toLong())
			exchange.responseBody.use { it.write(body) }
		}
		start()
	}

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
