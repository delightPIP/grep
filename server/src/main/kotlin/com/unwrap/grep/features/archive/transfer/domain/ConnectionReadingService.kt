package com.unwrap.grep.features.archive.transfer.domain

import com.unwrap.grep.features.archive.api.ConnectionRead
import com.unwrap.grep.features.archive.api.ConnectionReading
import com.unwrap.grep.features.archive.item.domain.ItemDetailRepository
import com.unwrap.grep.features.archive.item.domain.ItemRepository
import com.unwrap.grep.features.archive.search.domain.ItemSearch
import com.unwrap.grep.features.archive.search.domain.SearchQuery
import java.time.Clock
import java.util.UUID

/**
 * AI 도구 연결의 검색·읽기(ARC-009). 찾기와 같은 검색(ARC-002)을 쓰고, 응답 글은 [HandoffComposer]가 만든다.
 * 검색어에서 `#`으로 시작하는 낱말은 태그로 본다(앱의 `찾기 #태그`와 같다).
 */
class ConnectionReadingService(
	private val itemSearch: ItemSearch,
	private val sources: HandoffSourceRepository,
	private val details: ItemDetailRepository,
	private val items: ItemRepository,
	private val clock: Clock,
) : ConnectionReading {

	override fun search(userId: UUID, query: String): String? {
		val parsed = parse(query) ?: return null
		val numbers = itemSearch.find(userId, parsed, beforeNumber = null, limit = SEARCH_LIMIT).map { it.item.number }
		val total = if (numbers.size < SEARCH_LIMIT) numbers.size.toLong() else itemSearch.count(userId, parsed)
		val found = sources.findActiveForHandoff(userId, numbers).associateBy { it.number }
		return HandoffComposer.connectionSearch(numbers.mapNotNull { found[it] }, clock.instant(), total)
	}

	/** 가져온 자료를 읽으면 `열기`처럼 기다리는 처리 작업을 올린다(ADR-BCK-017). 요약은 기다리지 않는다. */
	override fun read(userId: UUID, number: Long): ConnectionRead? {
		val source = sources.findActiveForHandoff(userId, listOf(number)).singleOrNull() ?: return null
		val body = details.findActiveDetail(userId, number)?.body
		items.raiseProcessingPriority(userId, listOf(number))
		return ConnectionRead(HandoffComposer.connectionRead(source, body, clock.instant()), source.savedAt)
	}

	private fun parse(query: String): SearchQuery? {
		val tokens = query.split(WHITESPACE).filter { it.isNotEmpty() }.distinct()
		val (tagTokens, words) = tokens.partition { it.startsWith('#') }
		val tags = tagTokens.map { it.removePrefix("#").lowercase() }.filter { it.isNotEmpty() }.distinct()
		if (words.isEmpty() && tags.isEmpty()) return null
		return SearchQuery(words, tags)
	}

	private companion object {
		/** ARC-009 값: 검색 한 번에 20건. */
		const val SEARCH_LIMIT = 20
		val WHITESPACE = Regex("\\s+")
	}
}
