package com.unwrap.grep.features.account.domain

import org.springframework.stereotype.Component
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/** 승인 화면에 로그인한 그렙 계정. [label]은 승인 화면 첫 줄의 `<계정>`이다(ARC-009 규칙 9). */
data class ConsentAccount(val userId: UUID, val label: String)

/** 승인 화면을 오가는 동안 들고 있는 인가 요청. [loginVerifier]는 Supabase 로그인 PKCE 값이다. */
data class PendingAuthorization(
	val id: String,
	val request: AuthorizationRequest,
	val createdAt: Instant,
	val loginVerifier: String? = null,
	val account: ConsentAccount? = null,
)

/**
 * 진행 중인 인가 요청을 메모리에 10분 둔다. 브라우저는 쿠키로 [PendingAuthorization.id]만 들고 다닌다.
 * shortcut: 서버 한 대(ADR-0011, Render 무료 한 대) 기준이다. 재시작하면 진행 중인 승인은 처음부터 다시 한다. 서버를 늘리면 표로 옮긴다.
 */
@Component
class PendingAuthorizations(private val clock: Clock) {
	private val entries = ConcurrentHashMap<String, PendingAuthorization>()

	fun start(request: AuthorizationRequest): PendingAuthorization {
		evictExpired()
		if (entries.size >= MAX_ENTRIES) throw OAuthError("temporarily_unavailable", "too many pending authorizations")
		val pending = PendingAuthorization(ConnectionTokens.newSecret(""), request, clock.instant())
		entries[pending.id] = pending
		return pending
	}

	fun find(id: String?): PendingAuthorization? {
		val pending = id?.let { entries[it] } ?: return null
		if (isExpired(pending)) {
			entries.remove(pending.id)
			return null
		}
		return pending
	}

	fun update(pending: PendingAuthorization) {
		entries.computeIfPresent(pending.id) { _, _ -> pending }
	}

	/** 허용·거부하면 지운다. 같은 요청을 두 번 결정하지 못한다. */
	fun take(id: String): PendingAuthorization? = entries.remove(id)?.takeUnless { isExpired(it) }

	private fun isExpired(pending: PendingAuthorization) = pending.createdAt.plus(TTL) < clock.instant()

	private fun evictExpired() = entries.values.removeIf { isExpired(it) }

	private companion object {
		val TTL: Duration = Duration.ofMinutes(10)
		const val MAX_ENTRIES = 1000
	}
}
