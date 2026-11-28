package com.unwrap.grep.features.processing.domain

import com.unwrap.grep.features.archive.api.Embedder
import com.unwrap.grep.features.archive.api.EmbeddingPurpose
import com.unwrap.grep.features.archive.api.EmbeddingQueue
import com.unwrap.grep.features.archive.api.EmbeddingResult
import org.slf4j.LoggerFactory
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

/**
 * 요약이 끝난 자료의 임베딩(ADR-BCK-016). 요약 처리(ProcessingWorker)와 따로 돌아 요약 한도와 따로 센다(결정 4).
 * 한도에 닿으면 그날은 임베딩만 미루고, 실패한 자료는 큐가 한 시간 뒤에 다시 준다.
 */
class EmbeddingWorker(private val queue: EmbeddingQueue, private val embedder: Embedder, private val clock: Clock) {

	/** 한 건을 불렀으면 true, 집을 자료가 없으면 false. */
	fun runOnce(): Boolean {
		val today = LocalDate.ofInstant(clock.instant(), KOREA).atStartOfDay(KOREA).toInstant()
		val job = queue.claimNext(today, DAILY_LIMIT) ?: return false
		when (val result = embedder.embed(job.text, EmbeddingPurpose.DOCUMENT)) {
			is EmbeddingResult.Vector -> queue.save(job.itemId, result.values, result.model)
			is EmbeddingResult.Unavailable -> log.info("embedding for item {} deferred: {}", job.itemId, result.reason)
		}
		return true
	}

	companion object {
		/** 계정당 하루 임베딩 호출 수. shortcut: 무료 한도를 AI Studio에서 확인하기 전 임시값으로 요약 한도(COM-005)와 같게 둔다. */
		const val DAILY_LIMIT = 50
		private val KOREA: ZoneId = ZoneId.of("Asia/Seoul")
		private val log = LoggerFactory.getLogger(EmbeddingWorker::class.java)
	}
}
