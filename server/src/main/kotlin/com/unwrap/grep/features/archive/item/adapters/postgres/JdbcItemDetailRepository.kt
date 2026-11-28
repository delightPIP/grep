package com.unwrap.grep.features.archive.item.adapters.postgres

import com.unwrap.grep.features.archive.api.ItemBody
import com.unwrap.grep.features.archive.item.domain.FileFormat
import com.unwrap.grep.features.archive.item.domain.ItemDetailRepository
import com.unwrap.grep.features.archive.item.domain.ItemDetailSource
import com.unwrap.grep.features.archive.item.domain.ItemKind
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.util.UUID

/** 자세히 보기 한 건. 자료와 든 묶음 이름을 한 문장으로 읽는다. */
@Repository
class JdbcItemDetailRepository(private val jdbc: JdbcClient) : ItemDetailRepository {

	override fun findActiveDetail(userId: UUID, number: Long): ItemDetailSource? =
		jdbc.sql(
			"""
			SELECT $SUMMARY_COLUMNS, url, handoff_summary, text_body, body_text, body_length, body_from_image,
			       object_path, file_format,
			       ARRAY(SELECT bu.name FROM bundle_items b JOIN bundles bu ON bu.id = b.bundle_id
			             WHERE b.item_id = items.id ORDER BY lower(bu.name)) AS bundle_names
			FROM items
			WHERE user_id = :userId AND number = :number AND deleted_at IS NULL
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("number", number)
			.query(DETAIL_ROW)
			.optional()
			.orElse(null)

	private companion object {
		val DETAIL_ROW = RowMapper { rs, rowNum ->
			val item = ITEM_ROW.mapRow(rs, rowNum)!!
			// 글 자료는 붙여 넣은 글이 곧 본문이다(V5 주석). 나머지는 처리 때 읽은 본문.
			val body = if (item.kind == ItemKind.TEXT) {
				rs.getString("text_body")?.let { ItemBody.of(it) }
			} else {
				rs.getString("body_text")?.let { text ->
					ItemBody(text, rs.getInt("body_length"), rs.getBoolean("body_from_image"))
				}
			}
			@Suppress("UNCHECKED_CAST")
			val bundles = (rs.getArray("bundle_names").array as Array<String>).toList()
			ItemDetailSource(
				item = item,
				url = rs.getString("url"),
				handoffSummary = rs.getString("handoff_summary"),
				body = body,
				objectPath = rs.getString("object_path"),
				fileFormat = rs.getString("file_format")?.let { value -> FileFormat.entries.first { it.value == value } },
				bundles = bundles,
			)
		}
	}
}
