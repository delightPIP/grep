package com.unwrap.grep.features.account.adapters.postgres

import com.unwrap.grep.features.account.api.ConnectionPrincipal
import com.unwrap.grep.features.account.domain.ConnectionEndReason
import com.unwrap.grep.features.account.domain.ConnectionNotice
import com.unwrap.grep.features.account.domain.ConnectionRepository
import com.unwrap.grep.features.account.domain.ConnectionSummary
import com.unwrap.grep.features.account.domain.ConnectionTokens
import com.unwrap.grep.features.account.domain.EndConnectionResult
import com.unwrap.grep.features.account.domain.RefreshTarget
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Timestamp
import java.time.Instant
import java.util.UUID

/**
 * connections(V4). 마지막으로 토큰을 준 시각은 `access_expires_at - 접근 토큰 수명`으로 셈한다.
 * 끊긴 연결은 지우지 않고 `ended_at`·`end_reason`을 남긴다(끊김 알림, ACC-002 규칙 11).
 */
@Repository
class JdbcConnectionRepository(private val jdbc: JdbcClient) : ConnectionRepository {

	override fun create(userId: UUID, clientId: String, accessHash: String, refreshHash: String, accessExpiresAt: Instant): Int {
		val number = jdbc.sql(
			"UPDATE users SET last_connection_number = last_connection_number + 1 WHERE id = :userId RETURNING last_connection_number",
		)
			.param("userId", userId)
			.query(Int::class.java)
			.single()
		jdbc.sql(
			"""
			INSERT INTO connections (user_id, number, client_id, access_token_hash, refresh_token_hash, access_expires_at)
			VALUES (:userId, :number, :clientId, :access, :refresh, :expiresAt)
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("number", number)
			.param("clientId", clientId)
			.param("access", accessHash)
			.param("refresh", refreshHash)
			.param("expiresAt", Timestamp.from(accessExpiresAt))
			.update()
		return number
	}

	override fun findActiveByAccess(accessHash: String, now: Instant): ConnectionPrincipal? =
		jdbc.sql(
			"""
			SELECT id, user_id FROM connections
			WHERE access_token_hash = :hash AND ended_at IS NULL AND access_expires_at > :now
			""".trimIndent(),
		)
			.param("hash", accessHash)
			.param("now", Timestamp.from(now))
			.query { rs, _ -> ConnectionPrincipal(rs.getObject("id", UUID::class.java), rs.getObject("user_id", UUID::class.java)) }
			.optional()
			.orElse(null)

	override fun findByRefresh(refreshHash: String): RefreshTarget? =
		jdbc.sql(
			"""
			SELECT id, user_id, client_id, created_at, access_expires_at - make_interval(secs => :ttl) AS last_issued_at,
			       ended_at IS NOT NULL AS ended
			FROM connections WHERE refresh_token_hash = :hash
			""".trimIndent(),
		)
			.param("hash", refreshHash)
			.param("ttl", TTL_SECONDS)
			.query { rs, _ ->
				RefreshTarget(
					connectionId = rs.getObject("id", UUID::class.java),
					userId = rs.getObject("user_id", UUID::class.java),
					clientId = rs.getString("client_id"),
					createdAt = rs.getTimestamp("created_at").toInstant(),
					lastIssuedAt = rs.getTimestamp("last_issued_at").toInstant(),
					ended = rs.getBoolean("ended"),
				)
			}
			.optional()
			.orElse(null)

	override fun rotate(connectionId: UUID, oldRefreshHash: String, accessHash: String, refreshHash: String, accessExpiresAt: Instant): Boolean =
		jdbc.sql(
			"""
			UPDATE connections
			SET access_token_hash = :access, refresh_token_hash = :refresh, access_expires_at = :expiresAt
			WHERE id = :id AND refresh_token_hash = :oldRefresh AND ended_at IS NULL
			""".trimIndent(),
		)
			.param("access", accessHash)
			.param("refresh", refreshHash)
			.param("expiresAt", Timestamp.from(accessExpiresAt))
			.param("id", connectionId)
			.param("oldRefresh", oldRefreshHash)
			.update() == 1

	override fun markRead(connectionId: UUID, at: Instant) {
		jdbc.sql("UPDATE connections SET last_read_at = :at WHERE id = :id")
			.param("at", Timestamp.from(at))
			.param("id", connectionId)
			.update()
	}

	override fun expireStale(userId: UUID, idleBefore: Instant, createdBefore: Instant, at: Instant) {
		jdbc.sql(
			"""
			UPDATE connections SET ended_at = :at, end_reason = 'expired'
			WHERE user_id = :userId AND ended_at IS NULL
			  AND (access_expires_at - make_interval(secs => :ttl) < :idleBefore OR created_at < :createdBefore)
			""".trimIndent(),
		)
			.param("at", Timestamp.from(at))
			.param("userId", userId)
			.param("ttl", TTL_SECONDS)
			.param("idleBefore", Timestamp.from(idleBefore))
			.param("createdBefore", Timestamp.from(createdBefore))
			.update()
	}

	override fun listActive(userId: UUID): List<ConnectionSummary> =
		jdbc.sql(
			"""
			SELECT c.number, oc.name, c.created_at, c.last_read_at
			FROM connections c JOIN oauth_clients oc ON oc.id = c.client_id
			WHERE c.user_id = :userId AND c.ended_at IS NULL
			ORDER BY c.number
			""".trimIndent(),
		)
			.param("userId", userId)
			.query { rs, _ ->
				ConnectionSummary(
					number = rs.getInt("number"),
					client = rs.getString("name"),
					connectedAt = rs.getTimestamp("created_at").toInstant(),
					lastReadAt = rs.getTimestamp("last_read_at")?.toInstant(),
				)
			}
			.list()

	/** 이미 끊긴 연결은 이유와 관계없이 `alreadyEnded`다. 직접 끊으면 알릴 필요가 없어 본 것으로 둔다. */
	override fun end(userId: UUID, number: Int, reason: ConnectionEndReason, at: Instant): EndConnectionResult {
		val ended = jdbc.sql(
			"""
			UPDATE connections c SET ended_at = :at, end_reason = :reason, notice_seen_at = :at
			FROM oauth_clients oc
			WHERE oc.id = c.client_id AND c.user_id = :userId AND c.number = :number AND c.ended_at IS NULL
			RETURNING oc.name
			""".trimIndent(),
		)
			.param("at", Timestamp.from(at))
			.param("reason", reason.value)
			.param("userId", userId)
			.param("number", number)
			.query(String::class.java)
			.optional()
		if (ended.isPresent) return EndConnectionResult.Ended(ended.get())
		val existing = jdbc.sql(
			"""
			SELECT oc.name FROM connections c JOIN oauth_clients oc ON oc.id = c.client_id
			WHERE c.user_id = :userId AND c.number = :number
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("number", number)
			.query(String::class.java)
			.optional()
		return existing.map<EndConnectionResult> { EndConnectionResult.AlreadyEnded(it) }.orElse(EndConnectionResult.NotFound)
	}

	override fun endAll(userId: UUID, reason: ConnectionEndReason, at: Instant): Int =
		jdbc.sql("UPDATE connections SET ended_at = :at, end_reason = :reason WHERE user_id = :userId AND ended_at IS NULL")
			.param("at", Timestamp.from(at))
			.param("reason", reason.value)
			.param("userId", userId)
			.update()

	override fun takeNotices(userId: UUID, at: Instant): List<ConnectionNotice> =
		jdbc.sql(
			"""
			UPDATE connections c SET notice_seen_at = :at
			FROM oauth_clients oc
			WHERE oc.id = c.client_id AND c.user_id = :userId AND c.ended_at IS NOT NULL
			  AND c.notice_seen_at IS NULL AND c.end_reason IN ('revoked', 'expired')
			RETURNING c.number, oc.name, c.end_reason
			""".trimIndent(),
		)
			.param("at", Timestamp.from(at))
			.param("userId", userId)
			.query { rs, _ -> rs.getInt("number") to ConnectionNotice(rs.getString("name"), ConnectionEndReason.of(rs.getString("end_reason"))) }
			.list()
			.sortedBy { it.first }
			.map { it.second }

	private companion object {
		val TTL_SECONDS: Double = ConnectionTokens.ACCESS_TTL.seconds.toDouble()
	}
}
