package com.unwrap.grep.features.archive.api

import java.time.Instant
import java.util.UUID

/** 임베딩 차원(ADR-BCK-016 결정 2, V6 `vector(768)`). */
const val EMBEDDING_DIMENSIONS = 768

/** 임베딩 용도. 자료는 DOCUMENT, 찾기 검색어는 QUERY(제공사 task type). */
enum class EmbeddingPurpose { DOCUMENT, QUERY }

sealed interface EmbeddingResult {
	/** [values]는 [EMBEDDING_DIMENSIONS]개. */
	class Vector(val values: FloatArray, val model: String) : EmbeddingResult

	/** 키 없음, 거절, 시간 초과 등. 찾기는 뜻 결과 없이 답하고, 자료는 나중에 다시 부른다. */
	data class Unavailable(val reason: String) : EmbeddingResult
}

/** 임베딩 제공사(ADR-BCK-016). 호출은 이 포트 뒤 어댑터 하나에만 둔다. */
interface Embedder {
	fun embed(text: String, purpose: EmbeddingPurpose): EmbeddingResult
}

/** 임베딩할 자료 한 건. [text]는 제목·요약·본문 앞부분을 이은 것(ADR-BCK-016 결정 1). */
data class EmbeddingJob(val itemId: UUID, val userId: UUID, val text: String)

/** 임베딩 워커가 archive 테이블을 읽고 쓰는 포트(ADR-BCK-004 결정 3). */
interface EmbeddingQueue {
	/**
	 * 요약이 끝났고(ready) 임베딩이 없는 휴지통 밖 자료 하나를 집고 시도 시각을 남긴다.
	 * 그 사용자가 [dayStart] 뒤에 [dailyLimit]번 넘게 불렀으면 집지 않는다. 실패한 자료는 한 시간 뒤에 다시 집는다.
	 */
	fun claimNext(dayStart: Instant, dailyLimit: Int): EmbeddingJob?

	/** 그 사이 휴지통으로 갔으면 쓰지 않는다. */
	fun save(itemId: UUID, vector: FloatArray, model: String)
}
