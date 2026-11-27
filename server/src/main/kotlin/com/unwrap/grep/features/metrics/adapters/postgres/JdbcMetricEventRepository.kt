package com.unwrap.grep.features.metrics.adapters.postgres

import com.unwrap.grep.features.metrics.domain.MetricEvent
import com.unwrap.grep.features.metrics.domain.MetricEventRepository
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Types

/** V3 `events`. */
@Repository
class JdbcMetricEventRepository(private val jdbc: JdbcClient) : MetricEventRepository {

	override fun insert(event: MetricEvent) {
		jdbc.sql(
			"""
			INSERT INTO events (user_id, name, method, item_count, days_since_saved, day_kst)
			VALUES (:userId, :name, :method, :itemCount, CAST(:days AS integer[]), :dayKst)
			""".trimIndent(),
		)
			.param("userId", event.userId)
			.param("name", event.name)
			.param("method", event.method, Types.VARCHAR)
			.param("itemCount", event.itemCount)
			.param("days", event.daysSinceSaved.toTypedArray())
			.param("dayKst", event.dayKst)
			.update()
	}
}
