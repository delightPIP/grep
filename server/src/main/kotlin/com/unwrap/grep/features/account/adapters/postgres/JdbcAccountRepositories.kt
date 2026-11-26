package com.unwrap.grep.features.account.adapters.postgres

import com.unwrap.grep.features.account.domain.Account
import com.unwrap.grep.features.account.domain.AuthProvider
import com.unwrap.grep.features.account.domain.SessionRecord
import com.unwrap.grep.features.account.domain.SessionRepository
import com.unwrap.grep.features.account.domain.UserRepository
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

private fun Instant.toUtc(): OffsetDateTime = OffsetDateTime.ofInstant(this, ZoneOffset.UTC)

@Repository
class JdbcUserRepository(private val jdbc: JdbcClient) : UserRepository {
	override fun findOrCreate(provider: AuthProvider, externalId: String): Account {
		// 동시에 처음 로그인해도 UNIQUE (auth_provider, external_id)가 한 행만 남긴다.
		jdbc.sql(
			"""
			INSERT INTO users (id, auth_provider, external_id) VALUES (:id, :provider, :externalId)
			ON CONFLICT (auth_provider, external_id) DO NOTHING
			""".trimIndent(),
		)
			.param("id", UUID.randomUUID())
			.param("provider", provider.claimValue)
			.param("externalId", externalId)
			.update()
		val userId = jdbc.sql("SELECT id FROM users WHERE auth_provider = :provider AND external_id = :externalId")
			.param("provider", provider.claimValue)
			.param("externalId", externalId)
			.query(UUID::class.java)
			.single()
		return Account(userId, provider)
	}
}

@Repository
class JdbcSessionRepository(private val jdbc: JdbcClient) : SessionRepository {
	override fun findOrStart(sessionId: UUID, userId: UUID, now: Instant): SessionRecord {
		jdbc.sql(
			"""
			INSERT INTO sessions (id, user_id, started_at, last_seen_at) VALUES (:id, :userId, :now, :now)
			ON CONFLICT (id) DO NOTHING
			""".trimIndent(),
		)
			.param("id", sessionId)
			.param("userId", userId)
			.param("now", now.toUtc())
			.update()
		return jdbc.sql("SELECT user_id, started_at, last_seen_at FROM sessions WHERE id = :id")
			.param("id", sessionId)
			.query { rs, _ ->
				SessionRecord(
					userId = rs.getObject("user_id", UUID::class.java),
					startedAt = rs.getObject("started_at", OffsetDateTime::class.java).toInstant(),
					lastSeenAt = rs.getObject("last_seen_at", OffsetDateTime::class.java).toInstant(),
				)
			}
			.single()
	}

	override fun touch(sessionId: UUID, now: Instant) {
		jdbc.sql("UPDATE sessions SET last_seen_at = :now WHERE id = :id")
			.param("now", now.toUtc())
			.param("id", sessionId)
			.update()
	}
}
