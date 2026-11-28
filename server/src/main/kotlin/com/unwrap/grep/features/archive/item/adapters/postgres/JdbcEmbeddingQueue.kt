package com.unwrap.grep.features.archive.item.adapters.postgres

import com.unwrap.grep.features.archive.api.EmbeddingJob
import com.unwrap.grep.features.archive.api.EmbeddingQueue
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

/** pgvector 값은 `[0.1,0.2,…]` 글로 넘기고 SQL에서 vector로 바꾼다. */
internal fun vectorLiteral(values: FloatArray): String = values.joinToString(",", "[", "]")

/** items의 임베딩 열(V6). 집기와 시도 시각 쓰기를 한 문장으로 해서 워커가 여럿이어도 겹치지 않는다. */
@Repository
class JdbcEmbeddingQueue(private val jdbc: JdbcClient) : EmbeddingQueue {

	override fun claimNext(dayStart: Instant, dailyLimit: Int): EmbeddingJob? =
		jdbc.sql(
			"""
			UPDATE items SET embedding_attempted_at = now()
			WHERE id = (
				SELECT i.id FROM items i
				WHERE i.status = 'ready' AND i.embedding IS NULL AND i.deleted_at IS NULL
				  AND (i.embedding_attempted_at IS NULL OR i.embedding_attempted_at < now() - interval '1 hour')
				  AND (SELECT count(*) FROM items c WHERE c.user_id = i.user_id AND c.embedding_attempted_at >= :dayStart) < :dailyLimit
				-- 가져온 자료(낮은 우선순위 작업)는 직접 저장한 자료 뒤에 한다(ADR-BCK-017)
				ORDER BY coalesce((SELECT min(j.priority) FROM item_jobs j WHERE j.item_id = i.id), 0), i.updated_at
				LIMIT 1
				FOR UPDATE OF i SKIP LOCKED
			)
			RETURNING id, user_id, title, coalesce(user_summary, handoff_summary) AS summary,
			          left(CASE WHEN kind = 'text' THEN text_body ELSE body_text END, :bodyChars) AS body
			""".trimIndent(),
		)
			.param("dayStart", OffsetDateTime.ofInstant(dayStart, ZoneOffset.UTC))
			.param("dailyLimit", dailyLimit)
			.param("bodyChars", BODY_CHARS)
			.query { rs, _ ->
				EmbeddingJob(
					itemId = rs.getObject("id", UUID::class.java),
					userId = rs.getObject("user_id", UUID::class.java),
					text = listOfNotNull(rs.getString("title"), rs.getString("summary"), rs.getString("body"))
						.filter { it.isNotBlank() }
						.joinToString("\n"),
				)
			}
			.optional()
			.orElse(null)

	override fun save(itemId: UUID, vector: FloatArray, model: String) {
		jdbc.sql(
			"UPDATE items SET embedding = CAST(:vector AS vector), embedding_model = :model WHERE id = :id AND deleted_at IS NULL",
		)
			.param("vector", vectorLiteral(vector))
			.param("model", model)
			.param("id", itemId)
			.update()
	}

	private companion object {
		/** 본문 앞부분(개발자 값). 제목·요약이 뜻을 대부분 담고, 본문은 낱말을 보태는 정도로 쓴다. */
		const val BODY_CHARS = 2_000
	}
}
