package com.unwrap.grep.features.account.domain

import com.unwrap.grep.features.account.api.ConnectionAccess
import com.unwrap.grep.features.account.api.ConnectionPrincipal
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Instant
import java.util.UUID

/** `연결` 목록의 한 줄(ACC-002 규칙 7). [client]는 OAuth 클라이언트 등록 이름이다. */
data class ConnectionSummary(val number: Int, val client: String, val connectedAt: Instant, val lastReadAt: Instant?)

/** 끊긴 까닭(V4 `end_reason`). */
enum class ConnectionEndReason(val value: String) {
	/** `연결 끊기`(ACC-002 규칙 8). 끊은 기기가 이미 알기에 알림을 띄우지 않는다. */
	USER("user"),

	/** `로그아웃 모든기기`(ACC-002 규칙 4). 알림 이유 `다른 기기에서 끊음`. */
	REVOKED("revoked"),

	/** 갱신 토큰 미사용·최대 기간 초과(ACC-002 규칙 11). 알림 이유 `로그인 만료`. */
	EXPIRED("expired");

	companion object {
		fun of(value: String): ConnectionEndReason = entries.first { it.value == value }
	}
}

sealed interface EndConnectionResult {
	data class Ended(val client: String) : EndConnectionResult
	data class AlreadyEnded(val client: String) : EndConnectionResult
	data object NotFound : EndConnectionResult
}

/** 사용자가 모르는 사이 끊긴 연결(ACC-002 규칙 11). */
data class ConnectionNotice(val client: String, val reason: ConnectionEndReason)

/** 갱신 요청이 가리키는 연결. [lastIssuedAt]은 마지막으로 토큰을 준 시각이다. */
data class RefreshTarget(
	val connectionId: UUID,
	val userId: UUID,
	val clientId: String,
	val createdAt: Instant,
	val lastIssuedAt: Instant,
	val ended: Boolean,
)

/** 발급한 토큰 한 쌍. 원문은 응답에만 쓴다. */
data class IssuedTokens(val accessToken: String, val refreshToken: String, val expiresInSeconds: Long)

interface ConnectionRepository {
	/** 사용자별 연결 번호를 하나 올려 붙이고 연결을 만든다. 같은 트랜잭션 안에서 부른다. */
	fun create(userId: UUID, clientId: String, accessHash: String, refreshHash: String, accessExpiresAt: Instant): Int

	fun findActiveByAccess(accessHash: String, now: Instant): ConnectionPrincipal?

	fun findByRefresh(refreshHash: String): RefreshTarget?

	/** 갱신 토큰이 [oldRefreshHash] 그대로이고 끊기지 않았을 때만 바꾼다. 동시에 두 번 갱신하면 하나만 이긴다. */
	fun rotate(connectionId: UUID, oldRefreshHash: String, accessHash: String, refreshHash: String, accessExpiresAt: Instant): Boolean

	fun markRead(connectionId: UUID, at: Instant)

	/** 미사용·최대 기간을 넘긴 내 연결을 `expired`로 끝낸다. */
	fun expireStale(userId: UUID, idleBefore: Instant, createdBefore: Instant, at: Instant)

	fun listActive(userId: UUID): List<ConnectionSummary>

	fun end(userId: UUID, number: Int, reason: ConnectionEndReason, at: Instant): EndConnectionResult

	fun endAll(userId: UUID, reason: ConnectionEndReason, at: Instant): Int

	/** 아직 알리지 않은 끊김을 돌려주고 알린 것으로 표시한다. */
	fun takeNotices(userId: UUID, at: Instant): List<ConnectionNotice>
}

/**
 * AI 도구 연결의 토큰과 목록(ADR-BCK-015 결정 3, ACC-002). 토큰은 해시로만 다룬다.
 * 만료는 따로 도는 작업 없이 목록·알림·갱신 때 판정한다.
 */
@Service
class ConnectionService(
	private val connections: ConnectionRepository,
	private val clock: Clock,
) : ConnectionAccess {

	/** 인가 코드를 바꿀 때(OAuth 토큰 엔드포인트) 연결을 새로 만든다. */
	@Transactional
	fun open(userId: UUID, clientId: String): IssuedTokens {
		val tokens = newTokens()
		connections.create(userId, clientId, ConnectionTokens.hash(tokens.accessToken), ConnectionTokens.hash(tokens.refreshToken), accessExpiresAt())
		return tokens
	}

	/** 갱신 토큰 회전. 끊겼거나 기간을 넘겼거나 다른 클라이언트의 토큰이면 null(`invalid_grant`). */
	@Transactional
	fun refresh(refreshToken: String, clientId: String?): IssuedTokens? {
		val oldHash = ConnectionTokens.hash(refreshToken)
		val target = connections.findByRefresh(oldHash) ?: return null
		if (target.ended || (clientId != null && clientId != target.clientId)) return null
		val now = clock.instant()
		if (isStale(target.createdAt, target.lastIssuedAt, now)) {
			expireStale(target.userId, now)
			return null
		}
		val tokens = newTokens()
		val rotated = connections.rotate(
			target.connectionId, oldHash,
			ConnectionTokens.hash(tokens.accessToken), ConnectionTokens.hash(tokens.refreshToken), accessExpiresAt(),
		)
		return tokens.takeIf { rotated }
	}

	override fun authenticate(accessToken: String): ConnectionPrincipal? =
		connections.findActiveByAccess(ConnectionTokens.hash(accessToken), clock.instant())

	override fun markRead(connectionId: UUID) = connections.markRead(connectionId, clock.instant())

	@Transactional
	fun list(userId: UUID): List<ConnectionSummary> {
		expireStale(userId, clock.instant())
		return connections.listActive(userId)
	}

	/** 같은 연결을 두 기기에서 동시에 끊어도 오류가 아니다(ACC-002 규칙 9). */
	fun end(userId: UUID, number: Int): EndConnectionResult =
		connections.end(userId, number, ConnectionEndReason.USER, clock.instant())

	fun endAll(userId: UUID): Int = connections.endAll(userId, ConnectionEndReason.REVOKED, clock.instant())

	@Transactional
	fun takeNotices(userId: UUID): List<ConnectionNotice> {
		val now = clock.instant()
		expireStale(userId, now)
		return connections.takeNotices(userId, now)
	}

	private fun expireStale(userId: UUID, now: Instant) =
		connections.expireStale(userId, now.minus(ConnectionTokens.IDLE_LIMIT), now.minus(ConnectionTokens.MAX_AGE), now)

	private fun isStale(createdAt: Instant, lastIssuedAt: Instant, now: Instant) =
		lastIssuedAt < now.minus(ConnectionTokens.IDLE_LIMIT) || createdAt < now.minus(ConnectionTokens.MAX_AGE)

	private fun newTokens() = IssuedTokens(
		accessToken = ConnectionTokens.newSecret(ACCESS_PREFIX),
		refreshToken = ConnectionTokens.newSecret(REFRESH_PREFIX),
		expiresInSeconds = ConnectionTokens.ACCESS_TTL.seconds,
	)

	private fun accessExpiresAt(): Instant = clock.instant().plus(ConnectionTokens.ACCESS_TTL)

	private companion object {
		const val ACCESS_PREFIX = "gca_"
		const val REFRESH_PREFIX = "gcr_"
	}
}
