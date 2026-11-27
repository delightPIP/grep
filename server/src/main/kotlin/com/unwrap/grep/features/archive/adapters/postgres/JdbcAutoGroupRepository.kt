package com.unwrap.grep.features.archive.adapters.postgres

import com.unwrap.grep.features.archive.domain.AutoGroupRepository
import com.unwrap.grep.features.archive.domain.GroupCount
import com.unwrap.grep.features.archive.domain.GroupKind
import com.unwrap.grep.features.archive.domain.ItemFilter
import com.unwrap.grep.features.archive.domain.PeriodStarts
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

/** 자동 묶음 형식(ARC-007 값): 이미지 파일은 image, 그 밖의 파일은 file. */
internal const val GROUP_KIND_SQL =
	"CASE WHEN kind = 'file' AND file_format IN ('png', 'jpeg', 'webp', 'heic') THEN 'image' ELSE kind END"

/** 자동 묶음 출처: 링크는 저장 때 넣은 호스트(items.source), 링크가 아니면 `direct`. */
internal const val GROUP_SOURCE_SQL = "CASE WHEN kind = 'link' THEN source ELSE '${ItemFilter.DIRECT}' END"

/** GET /items 자동 묶음 조건. 값이 null이면 그 조건을 보지 않는다. :kind·:source·:tag를 바인딩한다. */
internal const val GROUP_FILTER_SQL = """
	AND (CAST(:kind AS text) IS NULL OR $GROUP_KIND_SQL = :kind)
	AND (CAST(:source AS text) IS NULL OR $GROUP_SOURCE_SQL = :source)
	AND (CAST(:tag AS text) IS NULL OR :tag = ANY(tags))
"""

/** 보관함 자동 묶음 건수. 모두 휴지통 밖 내 자료만 센다(ARC-007 규칙 8, COM-006). */
@Repository
class JdbcAutoGroupRepository(private val jdbc: JdbcClient) : AutoGroupRepository {

	override fun countByKind(userId: UUID): Map<GroupKind, Long> =
		jdbc.sql("SELECT $GROUP_KIND_SQL AS g, count(*) AS n FROM items WHERE user_id = :userId AND deleted_at IS NULL GROUP BY 1")
			.param("userId", userId)
			.query { rs, _ -> GroupKind.of(rs.getString("g"))!! to rs.getLong("n") }
			.list()
			.toMap()

	override fun countBySource(userId: UUID): List<GroupCount> = grouped(
		"SELECT $GROUP_SOURCE_SQL AS g, count(*) AS n FROM items WHERE user_id = :userId AND deleted_at IS NULL AND $GROUP_SOURCE_SQL IS NOT NULL GROUP BY 1",
		userId,
	)

	override fun countByTag(userId: UUID): List<GroupCount> = grouped(
		"SELECT t AS g, count(*) AS n FROM items, unnest(tags) AS t WHERE user_id = :userId AND deleted_at IS NULL GROUP BY 1",
		userId,
	)

	private fun grouped(select: String, userId: UUID): List<GroupCount> =
		jdbc.sql("$select ORDER BY n DESC, g")
			.param("userId", userId)
			.query { rs, _ -> GroupCount(rs.getString("g"), rs.getLong("n")) }
			.list()

	override fun countByPeriod(userId: UUID, starts: PeriodStarts): List<GroupCount> =
		jdbc.sql(
			"""
			SELECT count(*) FILTER (WHERE created_at >= :today) AS today,
			       count(*) FILTER (WHERE created_at >= :week) AS week,
			       count(*) FILTER (WHERE created_at >= :month) AS month,
			       count(*) FILTER (WHERE created_at < :month) AS earlier
			FROM items WHERE user_id = :userId AND deleted_at IS NULL
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("today", OffsetDateTime.ofInstant(starts.today, ZoneOffset.UTC))
			.param("week", OffsetDateTime.ofInstant(starts.thisWeek, ZoneOffset.UTC))
			.param("month", OffsetDateTime.ofInstant(starts.thisMonth, ZoneOffset.UTC))
			.query { rs, _ ->
				listOf(
					GroupCount("today", rs.getLong("today")),
					GroupCount("thisWeek", rs.getLong("week")),
					GroupCount("thisMonth", rs.getLong("month")),
					GroupCount("earlier", rs.getLong("earlier")),
				)
			}
			.single()
}
