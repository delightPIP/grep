package com.unwrap.grep.features.archive.adapters.postgres

import com.unwrap.grep.features.archive.domain.ItemSearch
import com.unwrap.grep.features.archive.domain.MatchedIn
import com.unwrap.grep.features.archive.domain.SearchHit
import com.unwrap.grep.features.archive.domain.SearchQuery
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

/**
 * 찾기 SQL은 여기에만 둔다(V2 주석). 낱말마다 search_text에서 부분 일치(`&@`, items_search_idx)로 찾고 모두 맞아야 한다.
 * 낱말은 PGroonga 쿼리 문법(`OR`, `-`)으로 읽지 않는다. 태그는 정확히 같은 것만, 대소문자 없이(ARC-002 규칙 5).
 * Spring 이름 매개변수는 `&@`의 `&`를 매개변수로 읽으므로 위치 매개변수(`?`)만 쓴다. SQL 글에 사용자 입력은 넣지 않는다.
 */
@Repository
class PgroongaItemSearch(private val jdbc: JdbcClient) : ItemSearch {

	override fun find(userId: UUID, query: SearchQuery, beforeNumber: Long?, limit: Int): List<SearchHit> {
		val matched = matchedIn(query)
		val where = conditions(userId, query)
		val before = if (beforeNumber == null) Sql("") else Sql(" AND number < ?", listOf(beforeNumber))
		val sql = """
			SELECT $SUMMARY_COLUMNS, ${matched.text} AS matched_in FROM items
			WHERE ${where.text}${before.text}
			ORDER BY number DESC
			LIMIT ?
		""".trimIndent()
		return jdbc.sql(sql)
			.params(matched.args + where.args + before.args + limit)
			.query(HIT_ROW)
			.list()
	}

	override fun count(userId: UUID, query: SearchQuery): Long {
		val where = conditions(userId, query)
		return jdbc.sql("SELECT count(*) FROM items WHERE ${where.text}")
			.params(where.args)
			.query(Long::class.java)
			.single()
	}

	private fun conditions(userId: UUID, query: SearchQuery): Sql {
		val parts = mutableListOf("user_id = ? AND deleted_at IS NULL")
		query.words.forEach { _ -> parts += "search_text &@ ?" }
		if (query.tags.isNotEmpty()) parts += "ARRAY(SELECT lower(t) FROM unnest(tags) t) @> ${array(query.tags)}"
		val savedArgs = listOfNotNull(query.saved.from, query.saved.to).map { OffsetDateTime.ofInstant(it, ZoneOffset.UTC) }
		if (query.saved.from != null) parts += "created_at >= ?"
		if (query.saved.to != null) parts += "created_at < ?"
		return Sql(parts.joinToString(" AND "), listOf(userId) + query.words + query.tags + savedArgs)
	}

	/**
	 * 낱말 하나라도 맞은 첫 곳(제목 → 출처 → 요약 → 태그). 그 밖이면 본문이고, 이미지 파일의 본문은 이미지 속 글자다.
	 * 태그로만 찾으면 태그다.
	 */
	private fun matchedIn(query: SearchQuery): Sql {
		if (query.words.isEmpty()) return Sql("'${MatchedIn.TAG.value}'")
		val any = "&@| ${array(query.words)}"
		val checks = listOf(
			"title" to MatchedIn.TITLE,
			"coalesce(source, '')" to MatchedIn.SOURCE,
			"concat_ws(' ', user_summary, list_summary, handoff_summary)" to MatchedIn.SUMMARY,
			"array_to_string(tags, ' ')" to MatchedIn.TAG,
		)
		val text = """
			CASE
				${checks.joinToString("\n") { (column, place) -> "WHEN $column $any THEN '${place.value}'" }}
				WHEN file_format IN ('png', 'jpeg', 'webp', 'heic') THEN '${MatchedIn.IMAGE_TEXT.value}'
				ELSE '${MatchedIn.BODY.value}'
			END
		""".trimIndent()
		return Sql(text, checks.flatMap { query.words })
	}

	private fun array(values: List<String>) = "CAST(ARRAY[${values.joinToString(", ") { "?" }}] AS text[])"

	/** SQL 조각과 그 안의 `?` 순서대로의 값. */
	private data class Sql(val text: String, val args: List<Any> = emptyList())

	private companion object {
		val HIT_ROW = RowMapper { rs, rowNum ->
			SearchHit(ITEM_ROW.mapRow(rs, rowNum)!!, MatchedIn.of(rs.getString("matched_in")))
		}
	}
}
