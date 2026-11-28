package com.unwrap.grep.features.metrics.domain

import com.unwrap.grep.features.archive.api.ItemSavedTimes
import com.unwrap.grep.features.metrics.api.MetricEvents
import org.slf4j.LoggerFactory
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.UUID

/**
 * V3 `events` 한 행. 사용자 내부 ID·한국 날짜·방식·건수·저장 뒤 지난 일수만 둔다.
 * 제목·본문·검색어·파일 이름·주소·자료 번호는 넣지 않는다(08 T-14 기본값, V3 주석).
 */
data class MetricEvent(
	val userId: UUID,
	val name: String,
	val method: String?,
	val itemCount: Int,
	val daysSinceSaved: List<Int>,
	val dayKst: LocalDate,
)

fun interface MetricEventRepository {
	fun insert(event: MetricEvent)
}

class MetricEventService(
	private val events: MetricEventRepository,
	private val savedTimes: ItemSavedTimes,
	private val clock: Clock,
) : MetricEvents {

	override fun itemSaved(userId: UUID, method: String) = recordQuietly {
		MetricEvent(userId, ITEM_SAVED, method, itemCount = 1, daysSinceSaved = emptyList(), dayKst = today())
	}

	/** 방식은 `connection`, 건수 1, 지난 일수 하나(05 6-5절 D-08). */
	override fun connectionRead(userId: UUID, savedAt: Instant) = recordQuietly {
		val today = today()
		MetricEvent(userId, CONNECTION_READ, CONNECTION_METHOD, itemCount = 1, daysSinceSaved = listOf(daysBetween(savedAt, today)), dayKst = today)
	}

	/**
	 * 넘길 글 복사 성공(클라이언트 보고, 08 6절 개발 답 9). 번호는 건수와 지난 일수를 세는 데만 쓴다.
	 * 휴지통·없는 번호·남의 번호는 세지 않는다.
	 */
	fun handoffCopied(userId: UUID, numbers: List<Long>, method: String) = recordQuietly {
		val today = today()
		val days = savedTimes.savedTimes(userId, numbers.distinct()).map { daysBetween(it, today) }.sorted()
		MetricEvent(userId, HANDOFF_COPIED, method, itemCount = days.size, daysSinceSaved = days, dayKst = today)
	}

	private fun recordQuietly(build: () -> MetricEvent) {
		runCatching { events.insert(build()) }.onFailure { log.warn("측정 이벤트 기록 실패", it) }
	}

	private fun today(): LocalDate = LocalDate.ofInstant(clock.instant(), KOREA)

	private fun daysBetween(savedAt: Instant, today: LocalDate): Int =
		ChronoUnit.DAYS.between(LocalDate.ofInstant(savedAt, KOREA), today).toInt().coerceAtLeast(0)

	companion object {
		const val ITEM_SAVED = "item_saved"
		const val HANDOFF_COPIED = "handoff_copied"
		const val CONNECTION_READ = "connection_read"
		const val CONNECTION_METHOD = "connection"
		val HANDOFF_METHODS = setOf("pick", "pipe")
		private val KOREA: ZoneId = ZoneId.of("Asia/Seoul")
		private val log = LoggerFactory.getLogger(MetricEventService::class.java)
	}
}
