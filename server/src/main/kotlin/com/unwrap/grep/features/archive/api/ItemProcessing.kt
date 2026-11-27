package com.unwrap.grep.features.archive.api

import java.time.Duration
import java.time.Instant
import java.util.UUID

/**
 * 처리 워커(processing)가 집은 작업 한 건. archive 테이블은 이 포트로만 읽고 쓴다(ADR-BCK-004 결정 3).
 * [kind]는 `link`·`text`·`file`, [fileFormat]은 COM-004 형식 값(`pdf`, `png` …).
 */
data class ProcessingJob(
	val jobId: Long,
	val userId: UUID,
	val attempts: Int,
	val inTrash: Boolean,
	val kind: String,
	val title: String,
	val source: String?,
	val url: String?,
	val textBody: String?,
	val objectPath: String?,
	val fileFormat: String?,
)

/** 처리 결과. [searchBody]는 찾기용 본문 일부(제목·출처·요약·태그는 저장소가 더한다). */
sealed interface ProcessingOutcome {
	val searchBody: String?

	data class Ready(
		val fetchedTitle: String?,
		val listSummary: String,
		val handoffSummary: String,
		val tags: List<String>,
		val partialNote: String?,
		val model: String,
		val promptVersion: String,
		override val searchBody: String?,
	) : ProcessingOutcome

	/** ARC-005 `blocked`. [reason]은 V2 `blocked_reason` 값. */
	data class Blocked(val reason: String, override val searchBody: String?) : ProcessingOutcome

	/** ARC-005 `failed`. [error]는 작업 기록용(사용자에게 보이지 않는다). */
	data class Failed(val error: String, override val searchBody: String?) : ProcessingOutcome
}

interface ProcessingQueue {
	/**
	 * 때가 된 작업 또는 [lease]보다 오래 `running`인 작업 하나를 `SKIP LOCKED`로 집는다(ADR-BCK-002).
	 * 집으면 시도 횟수를 늘리고, 휴지통 밖 자료면 상태를 `processing`으로 바꾼다.
	 * 큐의 시각은 모두 DB `now()`로 잰다(run_at 기본값과 같은 시계).
	 */
	fun claimNext(lease: Duration): ProcessingJob?

	/** [since] 뒤에 집힌 그 사용자의 작업 수(지금 작업 포함). 하루 한도(COM-005)를 센다. */
	fun countClaimedSince(userId: UUID, since: Instant): Int

	/** 결과를 쓰고 작업을 끝낸다. 그 사이 자료가 휴지통으로 갔으면 결과를 버리고 false(ARC-005 규칙 7). */
	fun finish(job: ProcessingJob, outcome: ProcessingOutcome): Boolean

	/** 휴지통 자료의 작업을 결과 없이 끝낸다(ARC-005 규칙 7). */
	fun discard(job: ProcessingJob)

	/** 일시적 오류. 자료는 `processing` 그대로 두고 [delay] 뒤에 다시 집게 한다(ARC-005 규칙 5). */
	fun retryLater(job: ProcessingJob, delay: Duration, error: String)
}

/** 파일 원본 읽기. 없으면 null, [maxBytes]를 넘으면 null. */
interface ItemOriginals {
	fun read(objectPath: String, maxBytes: Long): ByteArray?
}
