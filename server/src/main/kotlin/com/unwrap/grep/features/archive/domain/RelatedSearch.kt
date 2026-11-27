package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.features.archive.api.Embedder
import com.unwrap.grep.features.archive.api.EmbeddingPurpose
import com.unwrap.grep.features.archive.api.EmbeddingResult
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.util.UUID

/** 임베딩 거리로 찾는 쿼리 포트(V6 pgvector). */
interface NearestItems {
	/** 휴지통 밖 내 자료 중 임베딩이 있고 코사인 거리가 [maxDistance] 이하인 것을 가까운 순으로 [limit]건. [saved] 기간 안만. */
	fun nearest(userId: UUID, vector: FloatArray, saved: SavedRange, maxDistance: Double, limit: Int): List<StoredItem>
}

/**
 * 찾기 0건일 때 뜻이 가까운 자료(F15, ADR-BCK-016 결정 3, openapi SearchPage.related).
 * 검색어 임베딩을 못 받으면 뜻 결과 없이 답한다(찾기 자체는 실패하지 않는다).
 * shortcut: 검색어 임베딩 호출은 자료 임베딩 하루 한도에 넣지 않는다. 0건 찾기가 잦아 무료 한도에 닿으면 사용자별로 센다.
 */
@Service
class RelatedSearch(
	private val embedder: Embedder,
	private val nearest: NearestItems,
	@Value("\${grep.semantic.max-distance}") private val maxDistance: Double,
) {
	fun related(userId: UUID, query: SearchQuery): List<StoredItem> {
		val text = (query.words + query.tags).joinToString(" ")
		val vector = embedder.embed(text, EmbeddingPurpose.QUERY) as? EmbeddingResult.Vector ?: return emptyList()
		return nearest.nearest(userId, vector.values, query.saved, maxDistance, LIMIT)
	}

	companion object {
		/** 뜻 결과 최대 건수(통합 세션 계약). */
		const val LIMIT = 3
	}
}
