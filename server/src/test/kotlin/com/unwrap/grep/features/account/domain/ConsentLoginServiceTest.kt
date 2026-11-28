package com.unwrap.grep.features.account.domain

import java.net.URI
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class ConsentLoginServiceTest {
	private val clock = Clock.fixed(Instant.parse("2026-11-28T12:00:00Z"), ZoneOffset.UTC)
	private val userId = UUID.fromString("00000000-0000-0000-0000-000000000001")
	private val identity = TokenIdentity(AuthProvider.GOOGLE, "google-sub", UUID.fromString("00000000-0000-0000-0000-0000000000aa"))
	private val pending = PendingAuthorizations(clock)
	private val supabase = FakeSupabaseLogin()

	@Test
	fun `진행중인요청이없을때_콜백이오면_만료로답하는지`() {
		// given
		val service = service(verified = VerifiedSupabaseToken(identity, "a@b.c"))

		// when
		val result = service.completeLogin(requestId = "없는요청", code = "code", error = null)

		// then
		assertEquals(ConsentLoginResult.Expired, result)
	}

	@Test
	fun `동의화면에서취소했을때_콜백이오면_취소문구로다시로그인시키는지`() {
		// given
		val started = startWithVerifier()
		val service = service(verified = VerifiedSupabaseToken(identity, "a@b.c"))

		// when
		val result = service.completeLogin(started.id, code = null, error = "access_denied")

		// then
		assertEquals(ConsentLoginResult.Retry("✗ 로그인 취소됨"), result)
	}

	@Test
	fun `토큰검증에실패했을때_콜백이오면_권한거부문구로다시로그인시키는지`() {
		// given
		val started = startWithVerifier()
		val service = service(verified = null)

		// when
		val result = service.completeLogin(started.id, code = "code", error = null)

		// then
		assertEquals(ConsentLoginResult.Retry("✗ 로그인 실패: 권한 거부"), result)
		assertNull(pending.find(started.id)?.account)
	}

	@Test
	fun `로그인이맞을때_콜백이오면_계정을붙이고세션을끝내는지`() {
		// given
		val started = startWithVerifier()
		val service = service(verified = VerifiedSupabaseToken(identity, "a@b.c"))

		// when
		val result = service.completeLogin(started.id, code = "code", error = null)

		// then
		assertEquals(ConsentLoginResult.LoggedIn, result)
		val updated = pending.find(started.id)!!
		assertEquals(ConsentAccount(userId, "a@b.c(Google)"), updated.account)
		assertNull(updated.loginVerifier)
		assertEquals(listOf("supabase-token"), supabase.signedOut)
	}

	private fun startWithVerifier(): PendingAuthorization {
		val client = OAuthClient("client-1", "Claude Code", listOf("http://localhost/cb"))
		val started = pending.start(AuthorizationRequest(client, "http://localhost/cb", "challenge", "st-1"))
		pending.update(started.copy(loginVerifier = "verifier"))
		return started
	}

	private fun service(verified: VerifiedSupabaseToken?) =
		ConsentLoginService(pending, supabase, { verified }, AccountService(FakeUsers(), FakeSessions(), clock))

	private inner class FakeUsers : UserRepository {
		override fun findOrCreate(provider: AuthProvider, externalId: String) = Account(userId, provider)
	}

	private class FakeSessions : SessionRepository {
		override fun findOrStart(sessionId: UUID, userId: UUID, now: Instant) = SessionRecord(userId, now, now)

		override fun touch(sessionId: UUID, now: Instant) = Unit
	}

	private class FakeSupabaseLogin : SupabaseLogin {
		val signedOut = mutableListOf<String>()

		override fun authorizeUrl(provider: AuthProvider, redirectTo: String, codeChallenge: String) = URI("https://supabase.test/authorize")

		override fun exchange(authCode: String, codeVerifier: String) = LoginExchange.Success("supabase-token")

		override fun signOut(accessToken: String) {
			signedOut += accessToken
		}
	}
}
