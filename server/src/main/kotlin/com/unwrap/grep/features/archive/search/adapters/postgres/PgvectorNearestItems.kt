package com.unwrap.grep.features.archive.search.adapters.postgres

import com.unwrap.grep.features.archive.item.adapters.postgres.ITEM_ROW
import com.unwrap.grep.features.archive.item.adapters.postgres.SUMMARY_COLUMNS
import com.unwrap.grep.features.archive.item.adapters.postgres.vectorLiteral
import com.unwrap.grep.features.archive.item.domain.StoredItem
import com.unwrap.grep.features.archive.search.domain.NearestItems
import com.unwrap.grep.features.archive.search.domain.SavedRange
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

/** pgvector 코사인 거리(`<=>`). user_id로 먼저 좁힌다(V6 주석). */
@Repository
class PgvectorNearestItems(private val jdbc: JdbcClient) : NearestItems {

	override fun nearest(userId: UUID, vector: FloatArray, saved: SavedRange, maxDistance: Double, limit: Int): List<StoredItem> =
		jdbc.sql(
			"""
			SELECT $SUMMARY_COLUMNS FROM (
				SELECT *, embedding <=> CAST(:vector AS vector) AS distance FROM items
				WHERE user_id = :userId AND deleted_at IS NULL AND embedding IS NOT NULL
				  AND (CAST(:from AS timestamptz) IS NULL OR created_at >= CAST(:from AS timestamptz))
				  AND (CAST(:to AS timestamptz) IS NULL OR created_at < CAST(:to AS timestamptz))
			) near
			WHERE distance <= :maxDistance
			ORDER BY distance, number DESC
			LIMIT :limit
			""".trimIndent(),
		)
			.param("vector", vectorLiteral(vector))
			.param("userId", userId)
			.param("from", saved.from?.let { OffsetDateTime.ofInstant(it, ZoneOffset.UTC) })
			.param("to", saved.to?.let { OffsetDateTime.ofInstant(it, ZoneOffset.UTC) })
			.param("maxDistance", maxDistance)
			.param("limit", limit)
			.query(ITEM_ROW)
			.list()
}
