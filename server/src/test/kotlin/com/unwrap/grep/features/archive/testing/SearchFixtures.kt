package com.unwrap.grep.features.archive.testing

import org.springframework.jdbc.core.simple.JdbcClient
import tools.jackson.module.kotlin.jacksonObjectMapper
import java.io.File
import java.sql.Types
import java.util.UUID

/** 찾기 테스트용 자료 한 건. search_text는 처리 워커가 만들 값을 테스트가 대신 넣는다. */
data class SearchRow(
	val number: Long,
	val kind: String,
	val title: String,
	val searchText: String,
	val tags: List<String> = emptyList(),
	val source: String? = null,
	val textBody: String? = null,
	val fileFormat: String? = null,
	val listSummary: String? = null,
	val status: String = "ready",
	val inTrash: Boolean = false,
)

/** items에 바로 넣는다. 저장 API를 거치지 않아 처리 결과(요약·태그·search_text)를 정할 수 있다. */
fun JdbcClient.insertSearchRow(userId: UUID, row: SearchRow) {
	val unique = UUID.randomUUID().toString()
	sql(
		"""
		INSERT INTO items (user_id, number, kind, url, normalized_url, text_body, object_path, file_format, content_hash,
		                   title, source, status, blocked_reason, list_summary, tags, search_text, deleted_at)
		VALUES (:userId, :number, :kind, :url, :url, :textBody, :objectPath, :fileFormat, :contentHash,
		        :title, :source, :status, :blockedReason, :listSummary, string_to_array(:tags, ','),
		        :searchText, CASE WHEN :inTrash THEN now() END)
		""".trimIndent(),
	)
		.param("userId", userId)
		.param("number", row.number)
		.param("kind", row.kind)
		.param("url", if (row.kind == "link") "https://example.com/$unique" else null, Types.VARCHAR)
		.param("textBody", row.textBody ?: if (row.kind == "text") row.title else null, Types.VARCHAR)
		.param("objectPath", if (row.kind == "file") "items/$unique" else null, Types.VARCHAR)
		.param("fileFormat", if (row.kind == "file") row.fileFormat ?: "pdf" else null, Types.VARCHAR)
		.param("contentHash", if (row.kind == "file") unique else null, Types.VARCHAR)
		.param("title", row.title)
		.param("source", row.source, Types.VARCHAR)
		.param("status", row.status)
		.param("blockedReason", if (row.status == "blocked") "access_denied" else null, Types.VARCHAR)
		.param("listSummary", row.listSummary, Types.VARCHAR)
		.param("tags", row.tags.joinToString(","))
		.param("searchText", row.searchText)
		.param("inTrash", row.inTrash)
		.update()
}

/**
 * db/seed/demo/seed.json 34건. 번호는 목록 순서대로 1부터(S01 = 1번).
 * search_text는 제목·출처·요약·태그·본문을 잇는다(V2 주석).
 */
fun demoSeedRows(): List<SearchRow> {
	val items = jacksonObjectMapper().readTree(File("../db/seed/demo/seed.json"))["items"]
	return items.mapIndexed { index, item ->
		val tags: List<String> = item["tags"]?.toList()?.map { it.asString() } ?: emptyList()
		val texts = listOf("title", "url", "listSummary", "handoffSummary", "body").mapNotNull { item[it]?.asString() }
		SearchRow(
			number = index + 1L,
			kind = item["kind"].asString(),
			title = item["title"].asString(),
			searchText = (texts + tags).joinToString("\n"),
			tags = tags,
			fileFormat = item["format"]?.asString(),
			listSummary = item["listSummary"]?.asString(),
			status = item["status"].asString(),
		)
	}
}
