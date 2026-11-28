package com.unwrap.grep.features.processing.domain

import com.unwrap.grep.features.archive.api.LowPriorityGate
import java.time.Instant

/**
 * 계정당 하루 AI 처리 한도(COM-005)와 직접 저장 몫(ADR-BCK-017). [dailyLimit]이 0이면 제한이 없다.
 * 보통 작업은 [dailyLimit]까지, 낮은 작업(가져온 자료)은 [dailyLimit] − [directSaveReserve]까지만 그날 처리한다.
 */
data class ProcessingLimits(val dailyLimit: Int, val directSaveReserve: Int) {
	init {
		require(dailyLimit >= 0 && directSaveReserve >= 0) { "limits must not be negative" }
	}

	/** [claimedToday]는 지금 작업을 포함한 그날 집힌 수. */
	fun exceeded(claimedToday: Int): Boolean = dailyLimit > 0 && claimedToday > dailyLimit

	fun lowPriorityGate(dayStart: Instant): LowPriorityGate? =
		if (dailyLimit == 0) null else LowPriorityGate(dayStart, (dailyLimit - directSaveReserve).coerceAtLeast(0))

	companion object {
		const val DEFAULT_DAILY_LIMIT = 50
	}
}
