package com.unwrap.grep.features.account.domain

import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Duration
import java.util.Base64

/**
 * 연결 토큰·인가 코드·클라이언트 ID를 만들고 해시한다(ADR-BCK-015 결정 3). 원문은 발급 응답에만 있고 표에는 해시만 둔다.
 * 원문이 32바이트 난수라 솔트 없는 SHA-256으로 충분하다.
 */
object ConnectionTokens {
	private val random = SecureRandom()
	private val urlEncoder = Base64.getUrlEncoder().withoutPadding()

	/** 접근 토큰 수명. ARC-009 값 "인증 기능 기본값"을 Supabase 접근 토큰과 같은 1시간으로 둔다(ACC-001). */
	val ACCESS_TTL: Duration = Duration.ofHours(1)

	/** 갱신 토큰을 이 기간 동안 쓰지 않으면 연결은 로그인 만료로 끝난다(ACC-001 세션 미사용 만료와 같은 값). */
	val IDLE_LIMIT: Duration = SessionPolicy.IDLE_LIMIT

	/** 승인한 때부터 이 기간이 지나면 연결은 로그인 만료로 끝난다(ACC-001 세션 최대 기간과 같은 값). */
	val MAX_AGE: Duration = SessionPolicy.MAX_LIFETIME

	/** 인가 코드 수명. 승인 직후 AI 도구가 바로 바꿔 간다. */
	val CODE_TTL: Duration = Duration.ofMinutes(5)

	fun newSecret(prefix: String): String = prefix + urlEncoder.encodeToString(ByteArray(32).also(random::nextBytes))

	fun newClientId(): String = "gc_" + urlEncoder.encodeToString(ByteArray(16).also(random::nextBytes))

	fun hash(secret: String): String =
		MessageDigest.getInstance("SHA-256").digest(secret.toByteArray()).joinToString("") { "%02x".format(it) }

	/** PKCE S256: BASE64URL(SHA256(verifier)) == challenge(RFC 7636 4.6). */
	fun s256(verifier: String): String =
		urlEncoder.encodeToString(MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.US_ASCII)))

	/** 길이가 달라도 시간이 새지 않게 비교한다. */
	fun matches(expected: String, actual: String): Boolean =
		MessageDigest.isEqual(expected.toByteArray(), actual.toByteArray())
}
