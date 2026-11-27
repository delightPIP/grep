package com.unwrap.grep.features.archive.adapters.postgres

import com.unwrap.grep.features.archive.domain.ItemRef
import com.unwrap.grep.features.archive.domain.TrashRepository
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

/** 휴지통(ARC-008). V2 `items.deleted_at`이 NULL이 아니면 휴지통이다. 모든 쿼리는 user_id로 거른다(COM-006). */
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
		jdbc.sql("UPDATE items SET deleted_at = CAST(:trashedAt AS timestamptz) WHERE user_id = :userId AND number = ANY(:numbers)")
			.param("trashedAt", trashedAt?.let { OffsetDateTime.ofInstant(it, ZoneOffset.UTC) })
			.param("userId", userId)
			.param("numbers", numbers.toLongArray())
			.update()
	}
}
