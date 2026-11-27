package com.unwrap.grep.features.archive.adapters.postgres

import com.unwrap.grep.features.archive.api.ItemCounter
import com.unwrap.grep.features.archive.api.ItemSavedTimes
import com.unwrap.grep.features.archive.domain.FileFormat
import com.unwrap.grep.features.archive.domain.HandoffSource
import com.unwrap.grep.features.archive.domain.HandoffSourceRepository
import com.unwrap.grep.features.archive.domain.ItemKind
import com.unwrap.grep.features.archive.domain.ItemRepository
import com.unwrap.grep.features.archive.domain.ItemStatus
import com.unwrap.grep.features.archive.domain.NewItem
import com.unwrap.grep.features.archive.domain.SavedRange
import com.unwrap.grep.features.archive.domain.StoredItem
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Types
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

internal const val SUMMARY_COLUMNS = """
	number, kind, title, source, status, blocked_reason, list_summary, user_summary, partial_note, tags,
	created_at, deleted_at
"""

internal val ITEM_ROW = RowMapper { rs, _ ->
	@Suppress("UNCHECKED_CAST")
	val tags = (rs.getArray("tags").array as Array<String>).toList()
	StoredItem(
		number = rs.getLong("number"),
		kind = ItemKind.entries.first { it.value == rs.getString("kind") },
		title = rs.getString("title"),
		source = rs.getString("source"),
		status = ItemStatus.of(rs.getString("status")),
		blockedReason = rs.getString("blocked_reason"),
		listSummary = rs.getString("list_summary"),
		userSummary = rs.getString("user_summary"),
		partialNote = rs.getString("partial_note"),
		tags = tags,
		savedAt = rs.getObject("created_at", OffsetDateTime::class.java).toInstant(),
		inTrash = rs.getObject("deleted_at") != null,
	)
}

/** items·item_jobs(V2). 모든 쿼리는 user_id로 거른다(COM-006). */
@Repository
class JdbcItemRepository(private val jdbc: JdbcClient) :
	ItemRepository, ItemCounter, ItemSavedTimes, HandoffSourceRepository {

	override fun lockOwner(userId: UUID) {
		jdbc.sql("SELECT id FROM users WHERE id = :userId FOR UPDATE")
			.param("userId", userId)
			.query(UUID::class.java)
			.single()
	}

	override fun findByIdempotencyKey(userId: UUID, key: UUID): StoredItem? =
		findOne("idempotency_key = :value", userId, key)

	override fun findByNormalizedUrl(userId: UUID, normalizedUrl: String): StoredItem? =
		findOne("normalized_url = :value", userId, normalizedUrl)

	override fun findByContentHash(userId: UUID, contentHash: String): StoredItem? =
		findOne("content_hash = :value", userId, contentHash)

	private fun findOne(condition: String, userId: UUID, value: Any): StoredItem? =
		jdbc.sql("SELECT $SUMMARY_COLUMNS FROM items WHERE user_id = :userId AND $condition")
			.param("userId", userId)
			.param("value", value)
			.query(ITEM_ROW)
			.optional()
			.orElse(null)

	/**
	 * ARC-001: 번호는 MAX(number)가 아니라 users.last_item_number로 발급한다(지운 번호를 다시 쓰지 않는다).
	 * 자료와 처리 작업(ARC-005)을 한 문장에서 넣어 같은 트랜잭션에 묶는다(ADR-BCK-002 결정 3).
	 */
	override fun insert(item: NewItem): StoredItem {
		val file = item.file
		return jdbc.sql(
			"""
			WITH issued AS (
				UPDATE users SET last_item_number = last_item_number + 1 WHERE id = :userId
				RETURNING last_item_number
			), created AS (
				INSERT INTO items (user_id, number, kind, url, normalized_url, text_body, object_path, file_name,
				                   file_format, file_size, content_hash, title, source, idempotency_key)
				SELECT :userId, last_item_number, :kind, :url, :normalizedUrl, :textBody, :objectPath, :fileName,
				       :fileFormat, :fileSize, :contentHash, :title, :source, :idempotencyKey
				FROM issued
				RETURNING *
			), queued AS (
				INSERT INTO item_jobs (item_id) SELECT id FROM created
			)
			SELECT $SUMMARY_COLUMNS FROM created
			""".trimIndent(),
		)
			.param("userId", item.userId)
			.param("kind", item.kind.value)
			.param("url", item.url, Types.VARCHAR)
			.param("normalizedUrl", item.normalizedUrl, Types.VARCHAR)
			.param("textBody", item.textBody, Types.VARCHAR)
			.param("objectPath", file?.objectPath, Types.VARCHAR)
			.param("fileName", file?.fileName, Types.VARCHAR)
			.param("fileFormat", file?.format?.value, Types.VARCHAR)
			.param("fileSize", file?.size, Types.BIGINT)
			.param("contentHash", file?.contentHash, Types.VARCHAR)
			.param("title", item.title)
			.param("source", item.source, Types.VARCHAR)
			.param("idempotencyKey", item.idempotencyKey)
			.query(ITEM_ROW)
			.single()
	}

	override fun countActive(userId: UUID, saved: SavedRange): Long =
		jdbc.sql(
			"""
			SELECT count(*) FROM items
			WHERE user_id = :userId AND deleted_at IS NULL
			  AND (CAST(:from AS timestamptz) IS NULL OR created_at >= CAST(:from AS timestamptz))
			  AND (CAST(:to AS timestamptz) IS NULL OR created_at < CAST(:to AS timestamptz))
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("from", saved.from?.let { OffsetDateTime.ofInstant(it, ZoneOffset.UTC) })
			.param("to", saved.to?.let { OffsetDateTime.ofInstant(it, ZoneOffset.UTC) })
			.query(Long::class.java)
			.single()

	override fun countActiveItems(userId: UUID): Long = countActive(userId)

	override fun savedTimes(userId: UUID, numbers: Collection<Long>): List<Instant> =
		jdbc.sql("SELECT created_at FROM items WHERE user_id = :userId AND deleted_at IS NULL AND number = ANY(:numbers)")
			.param("userId", userId)
			.param("numbers", numbers.toLongArray())
			.query { rs, _ -> rs.getObject("created_at", OffsetDateTime::class.java).toInstant() }
			.list()

	override fun findActive(userId: UUID, beforeNumber: Long?, limit: Int, saved: SavedRange): List<StoredItem> =
		jdbc.sql(
			"""
			SELECT $SUMMARY_COLUMNS FROM items
			WHERE user_id = :userId AND deleted_at IS NULL AND (CAST(:before AS bigint) IS NULL OR number < :before)
			  AND (CAST(:from AS timestamptz) IS NULL OR created_at >= CAST(:from AS timestamptz))
			  AND (CAST(:to AS timestamptz) IS NULL OR created_at < CAST(:to AS timestamptz))
			ORDER BY number DESC
			LIMIT :limit
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("before", beforeNumber, Types.BIGINT)
			.param("from", saved.from?.let { OffsetDateTime.ofInstant(it, ZoneOffset.UTC) })
			.param("to", saved.to?.let { OffsetDateTime.ofInstant(it, ZoneOffset.UTC) })
			.param("limit", limit)
			.query(ITEM_ROW)
			.list()

	/** 번호 개수에 제한이 없으므로(ARC-001) IN 목록 대신 배열 하나로 넘긴다. */
	override fun findActiveByNumbers(userId: UUID, numbers: Collection<Long>): List<StoredItem> =
		jdbc.sql("SELECT $SUMMARY_COLUMNS FROM items WHERE user_id = :userId AND deleted_at IS NULL AND number = ANY(:numbers)")
			.param("userId", userId)
			.param("numbers", numbers.toLongArray())
			.query(ITEM_ROW)
			.list()

	override fun findActiveForHandoff(userId: UUID, numbers: Collection<Long>): List<HandoffSource> =
		jdbc.sql(
			"""
			SELECT number, kind, title, url, file_format, status, blocked_reason, handoff_summary, user_summary,
			       partial_note, created_at
			FROM items WHERE user_id = :userId AND deleted_at IS NULL AND number = ANY(:numbers)
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("numbers", numbers.toLongArray())
			.query(HANDOFF_ROW)
			.list()

	private companion object {
		val HANDOFF_ROW = RowMapper { rs, _ ->
			HandoffSource(
				number = rs.getLong("number"),
				kind = ItemKind.entries.first { it.value == rs.getString("kind") },
				title = rs.getString("title"),
				url = rs.getString("url"),
				fileFormat = rs.getString("file_format")?.let { value -> FileFormat.entries.first { it.value == value } },
				status = ItemStatus.of(rs.getString("status")),
				blockedReason = rs.getString("blocked_reason"),
				handoffSummary = rs.getString("handoff_summary"),
				userSummary = rs.getString("user_summary"),
				partialNote = rs.getString("partial_note"),
				savedAt = rs.getObject("created_at", OffsetDateTime::class.java).toInstant(),
			)
		}
	}
}
