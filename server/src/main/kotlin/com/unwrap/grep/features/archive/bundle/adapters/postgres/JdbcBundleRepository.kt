package com.unwrap.grep.features.archive.bundle.adapters.postgres

import com.unwrap.grep.features.archive.bundle.domain.BundleRef
import com.unwrap.grep.features.archive.bundle.domain.BundleRepository
import com.unwrap.grep.features.archive.bundle.domain.BundleSummary
import com.unwrap.grep.features.archive.item.adapters.postgres.ITEM_ROW
import com.unwrap.grep.features.archive.item.adapters.postgres.SUMMARY_COLUMNS
import com.unwrap.grep.features.archive.item.domain.StoredItem
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Types
import java.time.OffsetDateTime
import java.util.UUID

/** bundles·bundle_items(V4). 이름은 lower(name) 유일 인덱스로 대소문자를 가리지 않는다. */
@Repository
class JdbcBundleRepository(private val jdbc: JdbcClient) : BundleRepository {

	override fun find(userId: UUID, name: String): BundleRef? =
		jdbc.sql("SELECT id, name FROM bundles WHERE user_id = :userId AND lower(name) = lower(:name)")
			.param("userId", userId)
			.param("name", name)
			.query(REF_ROW)
			.optional()
			.orElse(null)

	/** 같은 이름을 두 기기가 동시에 만들면 뒤 문장은 앞 트랜잭션을 기다렸다가 갱신으로 바뀐다. */
	override fun createOrTouch(userId: UUID, name: String): BundleRef =
		jdbc.sql(
			"""
			INSERT INTO bundles (user_id, name) VALUES (:userId, :name)
			ON CONFLICT (user_id, lower(name)) DO UPDATE SET updated_at = now()
			RETURNING id, name
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("name", name)
			.query(REF_ROW)
			.single()

	override fun touch(bundleId: UUID) {
		jdbc.sql("UPDATE bundles SET updated_at = now() WHERE id = :id").param("id", bundleId).update()
	}

	override fun addItems(userId: UUID, bundleId: UUID, numbers: Collection<Long>): Int =
		jdbc.sql(
			"""
			INSERT INTO bundle_items (bundle_id, item_id)
			SELECT :bundleId, id FROM items
			WHERE user_id = :userId AND deleted_at IS NULL AND number = ANY(:numbers)
			ON CONFLICT DO NOTHING
			""".trimIndent(),
		)
			.param("bundleId", bundleId)
			.param("userId", userId)
			.param("numbers", numbers.toLongArray())
			.update()

	override fun visibleNumbers(bundleId: UUID, numbers: Collection<Long>): Set<Long> =
		jdbc.sql(
			"""
			SELECT i.number FROM bundle_items b JOIN items i ON i.id = b.item_id
			WHERE b.bundle_id = :bundleId AND i.deleted_at IS NULL AND i.number = ANY(:numbers)
			""".trimIndent(),
		)
			.param("bundleId", bundleId)
			.param("numbers", numbers.toLongArray())
			.query { rs, _ -> rs.getLong(1) }
			.set()

	override fun removeItems(userId: UUID, bundleId: UUID, numbers: Collection<Long>) {
		jdbc.sql(
			"""
			DELETE FROM bundle_items b USING items i
			WHERE b.bundle_id = :bundleId AND i.id = b.item_id AND i.user_id = :userId AND i.number = ANY(:numbers)
			""".trimIndent(),
		)
			.param("bundleId", bundleId)
			.param("userId", userId)
			.param("numbers", numbers.toLongArray())
			.update()
	}

	override fun countVisible(bundleId: UUID): Long = countWhere(bundleId, "i.deleted_at IS NULL").toLong()

	override fun countTrashed(bundleId: UUID): Int = countWhere(bundleId, "i.deleted_at IS NOT NULL")

	private fun countWhere(bundleId: UUID, condition: String): Int =
		jdbc.sql("SELECT count(*) FROM bundle_items b JOIN items i ON i.id = b.item_id WHERE b.bundle_id = :bundleId AND $condition")
			.param("bundleId", bundleId)
			.query(Int::class.java)
			.single()

	override fun findVisible(bundleId: UUID, beforeNumber: Long?, limit: Int?): List<StoredItem> =
		jdbc.sql(
			"""
			SELECT $SUMMARY_COLUMNS FROM items
			WHERE id IN (SELECT item_id FROM bundle_items WHERE bundle_id = :bundleId)
			  AND deleted_at IS NULL AND (CAST(:before AS bigint) IS NULL OR number < :before)
			ORDER BY number DESC
			LIMIT :limit
			""".trimIndent(),
		)
			.param("bundleId", bundleId)
			.param("before", beforeNumber, Types.BIGINT)
			.param("limit", limit, Types.INTEGER)
			.query(ITEM_ROW)
			.list()

	override fun list(userId: UUID): List<BundleSummary> =
		jdbc.sql(
			"""
			SELECT bu.name, bu.updated_at,
			       (SELECT count(*) FROM bundle_items b JOIN items i ON i.id = b.item_id
			        WHERE b.bundle_id = bu.id AND i.deleted_at IS NULL) AS item_count
			FROM bundles bu WHERE bu.user_id = :userId
			ORDER BY bu.updated_at DESC, bu.created_at DESC
			""".trimIndent(),
		)
			.param("userId", userId)
			.query { rs, _ ->
				BundleSummary(
					name = rs.getString("name"),
					count = rs.getLong("item_count"),
					updatedAt = rs.getObject("updated_at", OffsetDateTime::class.java).toInstant(),
				)
			}
			.list()

	override fun delete(userId: UUID, name: String): Boolean =
		jdbc.sql("DELETE FROM bundles WHERE user_id = :userId AND lower(name) = lower(:name)")
			.param("userId", userId)
			.param("name", name)
			.update() > 0

	private companion object {
		val REF_ROW = RowMapper { rs, _ -> BundleRef(rs.getObject("id", UUID::class.java), rs.getString("name")) }
	}
}
