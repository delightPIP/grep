package com.unwrap.grep.features.archive.trash.adapters.postgres

import com.unwrap.grep.features.archive.item.adapters.postgres.ITEM_ROW
import com.unwrap.grep.features.archive.item.adapters.postgres.SUMMARY_COLUMNS
import com.unwrap.grep.features.archive.trash.domain.ItemRef
import com.unwrap.grep.features.archive.trash.domain.TrashCursor
import com.unwrap.grep.features.archive.trash.domain.TrashRepository
import com.unwrap.grep.features.archive.trash.domain.TrashedItem
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Types
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

/**
 * 휴지통(ARC-008). V2 `items.deleted_at`이 NULL이 아니면 휴지통이다. 사용자 요청 쿼리는 user_id로 거른다(COM-006).
 * 영구 삭제는 행을 지운다. item_jobs는 ON DELETE CASCADE로, 요약·태그·검색 색인·중복 판정 값은 같은 행이라 함께 사라진다.
 */
@Repository
class JdbcTrashRepository(private val jdbc: JdbcClient) : TrashRepository {

	override fun findRefsForUpdate(userId: UUID, numbers: Collection<Long>, inTrash: Boolean): List<ItemRef> =
		jdbc.sql(
			"""
			SELECT number, COALESCE(user_title, title) AS title FROM items
			WHERE user_id = :userId AND number = ANY(:numbers) AND (deleted_at IS NOT NULL) = :inTrash
			FOR UPDATE
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("numbers", numbers.toLongArray())
			.param("inTrash", inTrash)
			.query { rs, _ -> ItemRef(rs.getLong("number"), rs.getString("title")) }
			.list()

	override fun setTrashedAt(userId: UUID, numbers: Collection<Long>, trashedAt: Instant?) {
		jdbc.sql(
			"UPDATE items SET deleted_at = CAST(:trashedAt AS timestamptz) WHERE user_id = :userId AND number = ANY(:numbers)",
		)
			.param("trashedAt", trashedAt?.utc())
			.param("userId", userId)
			.param("numbers", numbers.toLongArray())
			.update()
	}

	override fun findTrashed(userId: UUID, after: TrashCursor?, limit: Int): List<TrashedItem> =
		jdbc.sql(
			"""
			SELECT $SUMMARY_COLUMNS FROM items
			WHERE user_id = :userId AND deleted_at IS NOT NULL
			  AND (CAST(:afterAt AS timestamptz) IS NULL
			       OR (deleted_at, number) < (CAST(:afterAt AS timestamptz), CAST(:afterNumber AS bigint)))
			ORDER BY deleted_at DESC, number DESC
			LIMIT :limit
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("afterAt", after?.trashedAt?.utc())
			.param("afterNumber", after?.number, Types.BIGINT)
			.param("limit", limit)
			.query { rs, rowNum ->
				TrashedItem(
					item = ITEM_ROW.mapRow(rs, rowNum)!!,
					trashedAt = rs.getObject("deleted_at", OffsetDateTime::class.java).toInstant(),
				)
			}
			.list()

	override fun countTrashed(userId: UUID): Long =
		jdbc.sql("SELECT count(*) FROM items WHERE user_id = :userId AND deleted_at IS NOT NULL")
			.param("userId", userId)
			.query(Long::class.java)
			.single()

	override fun deleteTrashed(userId: UUID): List<String?> =
		jdbc.sql("DELETE FROM items WHERE user_id = :userId AND deleted_at IS NOT NULL RETURNING object_path")
			.param("userId", userId)
			.query { rs, _ -> rs.getString("object_path") }
			.list()

	/** 예약 작업이 모든 사용자를 한 번에 훑는다. `items_trashed_idx`(V3)를 탄다. */
	override fun deleteTrashedBefore(boundary: Instant): List<String?> =
		jdbc.sql("DELETE FROM items WHERE deleted_at < :boundary RETURNING object_path")
			.param("boundary", boundary.utc())
			.query { rs, _ -> rs.getString("object_path") }
			.list()

	private fun Instant.utc(): OffsetDateTime = OffsetDateTime.ofInstant(this, ZoneOffset.UTC)
}
