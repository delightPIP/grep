package com.unwrap.grep.features.archive.item.adapters.postgres

import com.unwrap.grep.features.archive.item.domain.UploadRepository
import com.unwrap.grep.features.archive.item.domain.UploadSlot
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

/** uploads(V2). 쓰이지 않은 자리와 그 객체를 지우는 청소 작업은 아직 없다(#59 이후). */
@Repository
class JdbcUploadRepository(private val jdbc: JdbcClient) : UploadRepository {

	override fun create(slot: UploadSlot, declaredSize: Long, createdAt: Instant) {
		jdbc.sql(
			"""
			INSERT INTO uploads (id, user_id, object_path, file_name, declared_size, created_at)
			VALUES (:id, :userId, :objectPath, :fileName, :declaredSize, :createdAt)
			""".trimIndent(),
		)
			.param("id", slot.id)
			.param("userId", slot.userId)
			.param("objectPath", slot.objectPath)
			.param("fileName", slot.fileName)
			.param("declaredSize", declaredSize)
			.param("createdAt", OffsetDateTime.ofInstant(createdAt, ZoneOffset.UTC))
			.update()
	}

	override fun findUnconsumed(userId: UUID, uploadId: UUID): UploadSlot? =
		jdbc.sql(
			"""
			SELECT id, user_id, object_path, file_name FROM uploads
			WHERE id = :id AND user_id = :userId AND consumed_at IS NULL
			""".trimIndent(),
		)
			.param("id", uploadId)
			.param("userId", userId)
			.query { rs, _ ->
				UploadSlot(
					id = rs.getObject("id", UUID::class.java),
					userId = rs.getObject("user_id", UUID::class.java),
					objectPath = rs.getString("object_path"),
					fileName = rs.getString("file_name"),
				)
			}
			.optional()
			.orElse(null)

	override fun claim(uploadId: UUID, at: Instant): Boolean =
		jdbc.sql("UPDATE uploads SET consumed_at = :at WHERE id = :id AND consumed_at IS NULL")
			.param("at", OffsetDateTime.ofInstant(at, ZoneOffset.UTC))
			.param("id", uploadId)
			.update() == 1

	override fun delete(uploadId: UUID) {
		jdbc.sql("DELETE FROM uploads WHERE id = :id").param("id", uploadId).update()
	}
}
