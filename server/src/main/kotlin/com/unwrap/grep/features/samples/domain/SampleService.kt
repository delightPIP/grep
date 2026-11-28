package com.unwrap.grep.features.samples.domain

import com.unwrap.grep.features.archive.domain.ObjectStorage
import com.unwrap.grep.features.demoseed.domain.DemoSeedRepository
import com.unwrap.grep.features.demoseed.domain.PremadeItems
import com.unwrap.grep.features.demoseed.domain.SeedEntry
import com.unwrap.grep.features.demoseed.domain.SeedRow
import org.springframework.transaction.support.TransactionTemplate
import java.time.Clock
import java.util.UUID

/** 샘플 한 건. [read]는 그 항목의 파일 경로(textFile·file)를 바이트로 준다. */
class Sample(val entry: SeedEntry, val read: (String) -> ByteArray)

fun interface SampleCatalog {
	/** 저장 순서대로. */
	fun load(): List<Sample>
}

interface SampleRangeRepository {
	/** 사용자 행을 잠그고 받은 범위를 준다. 받은 적이 없으면 null. 트랜잭션 안에서만 부른다. */
	fun lockReceivedRange(userId: UUID): LongRange?

	fun saveReceivedRange(userId: UUID, range: LongRange)
}

sealed interface SampleOutcome {
	val range: LongRange

	data class Saved(override val range: LongRange) : SampleOutcome

	/** 이미 받았다. 처음 받은 범위(ARC-010 규칙 7). */
	data class AlreadyReceived(override val range: LongRange) : SampleOutcome
}

/**
 * 샘플 8건(ARC-010). 다음 번호부터 8개를 한 트랜잭션에 넣고, 하나라도 실패하면 아무것도 남기지 않는다(규칙 2·3).
 * 요약·태그는 미리 만든 값이라 처리 작업을 만들지 않고 하루 AI 처리 한도도 쓰지 않는다(데모 시드 #69와 같은 방식).
 */
class SampleService(
	private val catalog: SampleCatalog,
	private val ranges: SampleRangeRepository,
	private val items: DemoSeedRepository,
	private val storage: ObjectStorage,
	private val transaction: TransactionTemplate,
	private val clock: Clock,
) {

	fun save(userId: UUID): SampleOutcome {
		transaction.execute { ranges.lockReceivedRange(userId) }?.let { return SampleOutcome.AlreadyReceived(it) }

		val samples = catalog.load()
		check(samples.size == SAMPLE_COUNT) { "samples must be $SAMPLE_COUNT, got ${samples.size}" }
		// 저장 시각은 누른 시각이다(seed.json의 savedDaysAgo는 쓰지 않는다).
		val savedAt = clock.instant()
		val prepared = samples.map { PremadeItems.prepare(userId, it.entry, savedAt, it.read) }
		val uploads = prepared.mapNotNull { it.upload }
		PremadeItems.putAll(storage, uploads)
		val outcome = try {
			transaction.execute { insertAll(userId, prepared.map { it.row }) }!!
		} catch (e: RuntimeException) {
			PremadeItems.deleteAll(storage, uploads)
			throw e
		}
		if (outcome is SampleOutcome.AlreadyReceived) PremadeItems.deleteAll(storage, uploads)
		return outcome
	}

	/** 앞의 확인과 이 트랜잭션 사이에 같은 요청이 끼어들 수 있어 잠근 뒤 다시 본다. */
	private fun insertAll(userId: UUID, rows: List<SeedRow>): SampleOutcome {
		ranges.lockReceivedRange(userId)?.let { return SampleOutcome.AlreadyReceived(it) }
		val numbers = rows.map { items.insert(userId, it) }
		val range = numbers.first()..numbers.last()
		ranges.saveReceivedRange(userId, range)
		return SampleOutcome.Saved(range)
	}

	companion object {
		/** ARC-010 값: 마케터 캠페인 이야기 7건 + 그렙 사용법 1건. */
		const val SAMPLE_COUNT = 8
	}
}
