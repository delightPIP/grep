package com.unwrap.grep.features.archive.item.adapters.postgres

import com.unwrap.grep.features.archive.item.domain.ItemRevision
import com.unwrap.grep.features.archive.item.domain.ItemRevisionRepository
import com.unwrap.grep.features.archive.item.domain.StoredItem
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Types
import java.util.UUID

/**
 * 고치기(V3 `user_title`·`removed_tags`, V2 `user_summary`). 고친 제목은 `title`에도 써서 목록·찾기·넘기기가 그대로 읽는다.
 * 태그는 대소문자를 가리지 않고 지운다(ARC-002 규칙 5와 같은 기준).
 */
@Repository
class JdbcItemRevisionRepository(private val jdbc: JdbcClient) : ItemRevisionRepository {

	/**
	 * shortcut: search_text에는 고친 제목·요약을 덧붙이기만 한다. 고치기 전 제목·지운 태그 낱말도 일반 검색어로는 계속 찾힌다.
	 * 본문 일부를 따로 저장하지 않아 다시 모을 수 없어서다. 찾기 정확도 불만이 나오면 본문 칸을 따로 두고 다시 모은다.
	 */
	override fun revise(userId: UUID, number: Long, revision: ItemRevision): StoredItem? =
		jdbc.sql(
			"""
			UPDATE items SET
				user_title = COALESCE(CAST(:title AS text), user_title),
				title = COALESCE(CAST(:title AS text), title),
				user_summary = COALESCE(CAST(:summary AS text), user_summary),
				removed_tags = ARRAY(SELECT DISTINCT unnest(removed_tags || CAST(:removed AS text[]))),
				tags = ARRAY(
					SELECT t FROM unnest(tags) WITH ORDINALITY AS u(t, o)
					WHERE lower(t) <> ALL(CAST(:removed AS text[])) ORDER BY o
				),
				search_text = concat_ws(' ', search_text, CAST(:title AS text), CAST(:summary AS text)),
				updated_at = now()
			WHERE user_id = :userId AND number = :number AND deleted_at IS NULL
			RETURNING $SUMMARY_COLUMNS
			""".trimIndent(),
		)
			.param("title", revision.title, Types.VARCHAR)
			.param("summary", revision.summary, Types.VARCHAR)
			.param("removed", revision.removeTags.toTypedArray())
			.param("userId", userId)
			.param("number", number)
			.query(ITEM_ROW)
			.optional()
			.orElse(null)
}
