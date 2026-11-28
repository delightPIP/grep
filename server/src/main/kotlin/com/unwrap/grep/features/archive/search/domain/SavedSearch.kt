package com.unwrap.grep.features.archive.search.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import java.util.UUID

/** openapi `SavedSearch`. [count]는 부를 때마다 다시 센 휴지통 밖 자료 수. */
data class SavedSearch(val query: String, val count: Long)

data class SavedSearchSave(val search: SavedSearch, val created: Boolean)

interface SavedSearchRepository {
	/** 새로 넣었으면 true. 같은 검색어가 이미 있으면 그대로 두고 false. */
	fun insertIfAbsent(userId: UUID, query: String): Boolean

	/** 만든 순 최신부터(ARC-012 규칙 6). */
	fun queries(userId: UUID): List<String>

	fun delete(userId: UUID, query: String): Boolean
}

/**
 * 찾아둔 검색어를 찾기 조건으로 읽는다. 앱 `찾기`(SeekCommand)와 같이 `#`으로 시작하는 낱말은 태그, 나머지는 검색어 낱말이다.
 * 같은 검색어인지는 공백을 정리한 문자열로 본다(ARC-012 규칙 2). 낱말 차례가 다르면 다른 검색어다.
 */
object SearchTerms {
	const val MAX_LENGTH = 40
	private val WHITESPACE = Regex("\\s+")

	/** 앞뒤 공백을 지우고 낱말 사이 공백을 하나로 줄인다. */
	fun normalize(query: String): String = query.trim().replace(WHITESPACE, " ")

	/** 찾기 API(`q`·`tag`)와 같은 꼴: 낱말은 겹치지 않게, 태그는 `#` 없이 소문자로. `#`만 있는 낱말이 있으면 null. */
	fun parse(query: String): Pair<List<String>, List<String>>? {
		val tokens = normalize(query).split(' ').filter { it.isNotEmpty() }
		val tags = tokens.filter { it.startsWith("#") }.map { it.drop(1).lowercase() }
		if (tags.any { it.isEmpty() }) return null
		val words = tokens.filterNot { it.startsWith("#") }.distinct()
		return words to tags.distinct()
	}
}

/** 찾아두기(ARC-012). 시점 낱말은 클라이언트가 먼저 거른다(규칙 4). 남의 찾아둔 것은 없는 것과 같다(COM-006). */
class SavedSearchService(private val searches: SavedSearchRepository, private val itemSearch: ItemSearch) {

	fun save(userId: UUID, query: String): SavedSearchSave {
		val normalized = SearchTerms.normalize(query)
		if (normalized.isEmpty()) throw ApiProblem.invalidRequest("query is required")
		if (normalized.codePointCount(0, normalized.length) > SearchTerms.MAX_LENGTH) {
			throw ApiProblem.invalidRequest("query must be at most 40 characters")
		}
		if (SearchTerms.parse(normalized) == null) throw ApiProblem.invalidRequest("tag must not be empty")
		val created = searches.insertIfAbsent(userId, normalized)
		return SavedSearchSave(SavedSearch(normalized, count(userId, normalized)), created)
	}

	/** shortcut: 찾아둔 것마다 건수 쿼리를 한 번씩 부른다. 상한(열린 질문)이 정해져 수가 커지면 한 문장으로 모은다. */
	fun list(userId: UUID): List<SavedSearch> = searches.queries(userId).map { SavedSearch(it, count(userId, it)) }

	fun delete(userId: UUID, query: String) {
		if (!searches.delete(userId, SearchTerms.normalize(query))) throw ApiProblem(ApiErrorCode.NOT_FOUND)
	}

	/** 찾기 결과의 `찾아두기` 칩을 숨길지(ARC-012 규칙 9). 시점은 비교하지 않는다. */
	fun isSaved(userId: UUID, words: List<String>, tags: List<String>): Boolean =
		searches.queries(userId).any { SearchTerms.parse(it) == (words to tags) }

	private fun count(userId: UUID, query: String): Long {
		val (words, tags) = SearchTerms.parse(query) ?: return 0
		return itemSearch.count(userId, SearchQuery(words, tags))
	}
}
