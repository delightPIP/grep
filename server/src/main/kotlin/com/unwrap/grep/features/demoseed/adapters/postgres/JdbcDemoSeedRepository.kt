package com.unwrap.grep.features.demoseed.adapters.postgres

import com.unwrap.grep.features.account.domain.AuthProvider
import com.unwrap.grep.features.demoseed.domain.DemoSeedRepository
import com.unwrap.grep.features.demoseed.domain.SeedRow
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Types
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Repository
class JdbcDemoSeedRepository(private val jdbc: JdbcClient) : DemoSeedRepository {

	/**
	 * users에는 이메일이 없다(V1). 토큰 sub가 auth.users.id이므로 그 값으로 external_id를 잇는다.
	 * 같은 이메일로 Google·GitHub를 모두 쓰면 계정이 둘이므로 로그인 방식으로 하나를 고른다(ACC-001 규칙 4).
	 */
	override fun findUserId(provider: AuthProvider, email: String): UUID? =
		jdbc.sql(
			"""
			SELECT u.id FROM users u JOIN auth.users au ON u.external_id = au.id::text
			WHERE lower(au.email) = lower(:email) AND u.auth_provider = :provider
			""".trimIndent(),
		)
			.param("email", email)
			.param("provider", provider.claimValue)
			.query(UUID::class.java)
			.optional()
			.orElse(null)

	override fun lockLastItemNumber(userId: UUID): Long =
		jdbc.sql("SELECT last_item_number FROM users WHERE id = :userId FOR UPDATE")
			.param("userId", userId)
			.query(Long::class.java)
			.single()

	/** 번호 발급은 JdbcItemRepository.insert와 같은 방식(ARC-001). item_jobs는 넣지 않는다(#59 워커가 다시 집지 않게). */
	override fun insert(userId: UUID, row: SeedRow): Long {
		val file = row.file
		val savedAt = OffsetDateTime.ofInstant(row.savedAt, ZoneOffset.UTC)
		return jdbc.sql(
			"""
			WITH issued AS (
				UPDATE users SET last_item_number = last_item_number + 1 WHERE id = :userId
				RETURNING last_item_number
			)
			INSERT INTO items (user_id, number, kind, url, normalized_url, text_body, object_path, file_name,
			                   file_format, file_size, content_hash, title, source, status, blocked_reason,
			                   list_summary, handoff_summary, summary_model, summary_prompt_version, tags,
			                   search_text, created_at, updated_at)
			SELECT :userId, last_item_number, :kind, :url, :normalizedUrl, :textBody, :objectPath, :fileName,
			       :fileFormat, :fileSize, :contentHash, :title, :source, :status, :blockedReason,
			       :listSummary, :handoffSummary, :model, :promptVersion, CAST(:tags AS text[]),
			       :searchText, :savedAt, :savedAt
			FROM issued
			RETURNING number
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("kind", row.kind.value)
			.param("url", row.url, Types.VARCHAR)
			.param("normalizedUrl", row.normalizedUrl, Types.VARCHAR)
			.param("textBody", row.textBody, Types.VARCHAR)
			.param("objectPath", file?.objectPath, Types.VARCHAR)
			.param("fileName", file?.fileName, Types.VARCHAR)
			.param("fileFormat", file?.format?.value, Types.VARCHAR)
			.param("fileSize", file?.size, Types.BIGINT)
			.param("contentHash", file?.contentHash, Types.VARCHAR)
			.param("title", row.title)
			.param("source", row.source, Types.VARCHAR)
			.param("status", row.status)
			.param("blockedReason", row.blockedReason, Types.VARCHAR)
			.param("listSummary", row.listSummary, Types.VARCHAR)
			.param("handoffSummary", row.handoffSummary, Types.VARCHAR)
			.param("model", SEED_MODEL.takeIf { row.handoffSummary != null }, Types.VARCHAR)
			.param("promptVersion", SEED_PROMPT_VERSION.takeIf { row.handoffSummary != null }, Types.VARCHAR)
			.param("tags", row.tags.toTypedArray())
			.param("searchText", row.searchText)
			.param("savedAt", savedAt)
			.query(Long::class.java)
			.single()
	}

	private companion object {
		/** 요약은 미리 만든 값이라 모델 대신 출처를 적는다(ADR-BCK-008 결정 3 칸). */
		const val SEED_MODEL = "demo-seed"
		const val SEED_PROMPT_VERSION = "seed.json v1"
	}
}
