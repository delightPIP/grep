package com.unwrap.grep.features.archive.domain

import java.time.Instant
import java.util.UUID

/** openapi `ItemSummary.matchedIn`. 찾기 결과에서 일치한 곳(commands 6절 요약 줄 끝 표시). */
enum class MatchedIn(val value: String) {
	TITLE("title"), SOURCE("source"), SUMMARY("summary"), TAG("tag"), BODY("body"), IMAGE_TEXT("imageText");

	companion object {
		fun of(value: String): MatchedIn = entries.first { it.value == value }
	}
}

/** 저장 시각 기간(F22 시점). [from] 이상 [to] 미만의 반열린 구간이고, null이면 그쪽 끝이 없다. 경계는 클라이언트가 한국 시간으로 계산한다. */
data class SavedRange(val from: Instant? = null, val to: Instant? = null) {
	companion object {
		val ANY = SavedRange()
	}
}

/**
 * 찾기 조건. [words]는 띄어쓰기로 나눈 검색어 낱말, [tags]는 `#` 없는 소문자 태그다.
 * 둘 다 있으면 모든 조건을 만족해야 한다(ARC-002 규칙 6). 둘 중 하나는 비어 있지 않다.
 */
data class SearchQuery(val words: List<String>, val tags: List<String>, val saved: SavedRange = SavedRange.ANY) {
	init {
		require(words.isNotEmpty() || tags.isNotEmpty()) { "words or tags is required" }
	}
}

data class SearchHit(val item: StoredItem, val matchedIn: MatchedIn)

/** 찾은 자료 한 쪽. [total]은 조건에 맞는 전체 건수, [nextBeforeNumber]가 null이면 다음 쪽이 없다. */
data class SearchPage(val hits: List<SearchHit>, val total: Long, val nextBeforeNumber: Long?)

/** 찾기 쿼리 포트. 구현은 PGroonga 어댑터 하나뿐이다(V2 주석, ADR-BCK-002 결정 4). */
interface ItemSearch {
	/** 휴지통 밖 내 자료 중 [query]에 맞는 것을 번호 내림차순으로 [limit]건. [beforeNumber]가 있으면 그보다 작은 번호만. */
	fun find(userId: UUID, query: SearchQuery, beforeNumber: Long?, limit: Int): List<SearchHit>

	/** [query]에 맞는 휴지통 밖 내 자료 수. */
	fun count(userId: UUID, query: SearchQuery): Long
}
