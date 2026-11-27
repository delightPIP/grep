package com.unwrap.grep.features.account.domain

import java.time.Duration
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SessionPolicyTest {
	private val now = Instant.parse("2026-11-26T12:00:00Z")

	@Test
	fun `마지막요청뒤정확히30일일때_판정하면_유지되는지`() {
		// given
		val lastSeenAt = now.minus(Duration.ofDays(30))

		// when
		val expired = SessionPolicy.isExpired(startedAt = lastSeenAt, lastSeenAt = lastSeenAt, now = now)

		// then
		assertFalse(expired)
	}

	@Test
	fun `마지막요청뒤30일을넘겼을때_판정하면_만료되는지`() {
		// given
		val lastSeenAt = now.minus(Duration.ofDays(30)).minusSeconds(1)

		// when
		val expired = SessionPolicy.isExpired(startedAt = lastSeenAt, lastSeenAt = lastSeenAt, now = now)

		// then
		assertTrue(expired)
	}

	@Test
	fun `로그인뒤정확히90일이고계속썼을때_판정하면_유지되는지`() {
		// given
		val startedAt = now.minus(Duration.ofDays(90))

		// when
		val expired = SessionPolicy.isExpired(startedAt = startedAt, lastSeenAt = now.minusSeconds(5), now = now)

		// then
		assertFalse(expired)
	}

	@Test
	fun `로그인뒤90일을넘기고계속썼을때_판정하면_만료되는지`() {
		// given
		val startedAt = now.minus(Duration.ofDays(90)).minusSeconds(1)

		// when
		val expired = SessionPolicy.isExpired(startedAt = startedAt, lastSeenAt = now.minusSeconds(5), now = now)

		// then
		assertTrue(expired)
	}
}
