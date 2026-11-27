package com.unwrap.grep.features.archive.adapters.postgres

import com.unwrap.grep.features.archive.domain.ImportRepository
import com.unwrap.grep.features.archive.domain.ImportResult
import com.unwrap.grep.features.archive.domain.ImportStatus
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Types
import java.util.UUID

/** imports(V4). 진행 수는 한 건 끝날 때마다 한 문장으로 더한다. */
@Repository
class JdbcImportRepository(private val jdbc: JdbcClient) : ImportRepository {

	override fun create(userId: UUID, total: Int, overLimit: Int): ImportStatus =
		jdbc.sql("INSERT INTO imports (user_id, total, over_limit) VALUES (:userId, :total, :overLimit) RETURNING $COLUMNS")
			.param("userId", userId)
			.param("total", total)
			.param("overLimit", overLimit)
			.query(STATUS_ROW)
			.single()

	override fun find(userId: UUID, id: UUID): ImportStatus? =
		jdbc.sql("SELECT $COLUMNS FROM imports WHERE id = :id AND user_id = :userId")
			.param("id", id)
			.param("userId", userId)
			.query(STATUS_ROW)
			.optional()
			.orElse(null)

	override fun record(id: UUID, result: ImportResult, failedUrl: String?) {
		jdbc.sql(
			"""
			UPDATE imports SET
				done = done + 1,
				saved = saved + CASE WHEN :result = 'SAVED' THEN 1 ELSE 0 END,
				skipped = skipped + CASE WHEN :result = 'SKIPPED' THEN 1 ELSE 0 END,
				failed = failed + CASE WHEN :result = 'FAILED' THEN 1 ELSE 0 END,
				failed_urls = CASE WHEN CAST(:failedUrl AS text) IS NULL THEN failed_urls ELSE array_append(failed_urls, :failedUrl) END
			WHERE id = :id
			""".trimIndent(),
		)
			.param("id", id)
			.param("result", result.name)
			.param("failedUrl", failedUrl, Types.VARCHAR)
			.update()
	}

	override fun finish(id: UUID) {
		jdbc.sql("UPDATE imports SET state = 'finished', finished_at = now() WHERE id = :id").param("id", id).update()
	}

	private companion object {
		const val COLUMNS = "id, state, total, done, saved, skipped, failed, over_limit, failed_urls"

		val STATUS_ROW = RowMapper { rs, _ ->
			@Suppress("UNCHECKED_CAST")
			val failedUrls = (rs.getArray("failed_urls").array as Array<String>).toList()
			ImportStatus(
				id = rs.getObject("id", UUID::class.java),
				state = rs.getString("state"),
				total = rs.getInt("total"),
				done = rs.getInt("done"),
				saved = rs.getInt("saved"),
				skipped = rs.getInt("skipped"),
				failed = rs.getInt("failed"),
				overLimit = rs.getInt("over_limit"),
				failedUrls = failedUrls,
			)
		}
	}
}
