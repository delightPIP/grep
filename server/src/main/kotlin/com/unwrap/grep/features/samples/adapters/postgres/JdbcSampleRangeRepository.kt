package com.unwrap.grep.features.samples.adapters.postgres

import com.unwrap.grep.features.samples.domain.SampleRangeRepository
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.util.UUID

/** V3 `users.sample_first_number`·`sample_last_number`. 둘 다 NULL이거나 last = first + 7이다(users_sample_range_check). */
@Repository
class JdbcSampleRangeRepository(private val jdbc: JdbcClient) : SampleRangeRepository {

	override fun lockReceivedRange(userId: UUID): LongRange? =
		jdbc.sql("SELECT sample_first_number, sample_last_number FROM users WHERE id = :userId FOR UPDATE")
			.param("userId", userId)
			.query { rs, _ ->
				val first = rs.getLong("sample_first_number")
				if (rs.wasNull()) null else first..rs.getLong("sample_last_number")
			}
			// 받은 적이 없으면 행 값이 null이라 single() 대신 list()로 읽는다.
			.list()
			.single()

	override fun saveReceivedRange(userId: UUID, range: LongRange) {
		jdbc.sql("UPDATE users SET sample_first_number = :first, sample_last_number = :last WHERE id = :userId")
			.param("first", range.first)
			.param("last", range.last)
			.param("userId", userId)
			.update()
	}
}
