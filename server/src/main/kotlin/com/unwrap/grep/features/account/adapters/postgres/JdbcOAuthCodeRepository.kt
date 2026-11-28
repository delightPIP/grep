package com.unwrap.grep.features.account.adapters.postgres

import com.unwrap.grep.features.account.domain.OAuthCodeRepository
import com.unwrap.grep.features.account.domain.RedeemedCode
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Timestamp
import java.time.Instant
import java.util.UUID

/** oauth_codes(V4). 코드 원문은 두지 않는다. */
@Repository
class JdbcOAuthCodeRepository(private val jdbc: JdbcClient) : OAuthCodeRepository {

	override fun insert(codeHash: String, clientId: String, userId: UUID, redirectUri: String, codeChallenge: String, expiresAt: Instant) {
		jdbc.sql(
			"""
			INSERT INTO oauth_codes (code_hash, client_id, user_id, redirect_uri, code_challenge, expires_at)
			VALUES (:hash, :clientId, :userId, :redirectUri, :challenge, :expiresAt)
			""".trimIndent(),
		)
			.param("hash", codeHash)
			.param("clientId", clientId)
			.param("userId", userId)
			.param("redirectUri", redirectUri)
			.param("challenge", codeChallenge)
			.param("expiresAt", Timestamp.from(expiresAt))
			.update()
	}

	override fun redeem(codeHash: String, now: Instant): RedeemedCode? =
		jdbc.sql(
			"""
			UPDATE oauth_codes SET used_at = :now
			WHERE code_hash = :hash AND used_at IS NULL AND expires_at > :now
			RETURNING client_id, user_id, redirect_uri, code_challenge
			""".trimIndent(),
		)
			.param("hash", codeHash)
			.param("now", Timestamp.from(now))
			.query { rs, _ ->
				RedeemedCode(rs.getString("client_id"), rs.getObject("user_id", UUID::class.java), rs.getString("redirect_uri"), rs.getString("code_challenge"))
			}
			.optional()
			.orElse(null)
}
