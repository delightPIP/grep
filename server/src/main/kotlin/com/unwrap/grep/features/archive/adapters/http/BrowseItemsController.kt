package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.domain.BrowseItemsService
import com.unwrap.grep.features.archive.domain.SavedRange
import com.unwrap.grep.features.archive.domain.SavedSearchService
import com.unwrap.grep.features.archive.domain.SearchQuery
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.time.OffsetDateTime
import java.util.UUID

/** openapi `ItemPage`. [total]은 기간이 있을 때만 숫자, 없으면 null로 싣는다. */
data class ItemPageResponse(val items: List<ItemSummaryResponse>, val total: Long?, val nextCursor: String?)

/** openapi `SearchPage`. [isSavedSearch]는 같은 검색어를 찾아뒀는지(ARC-012 규칙 9, 시점은 비교하지 않음). */
data class SearchPageResponse(
	val items: List<ItemSummaryResponse>,
	val total: Long,
	val nextCursor: String?,
	val isSavedSearch: Boolean,
)

/** openapi `ItemLookup`. */
data class ItemLookupResponse(val items: List<ItemSummaryResponse>, val missing: List<Long>)

/**
 * GET /items(listRecentItems), GET /items/search(searchItems), GET /items/status(getItemStatuses).
 * 쿼리 값은 문자열로 받아 직접 검사한다. 틀리면 Spring 기본 오류가 아니라 `invalid_request`로 답한다.
 * 커서는 앞 쪽 마지막 자료 번호다. 클라이언트는 뜻을 모르는 문자열로만 다룬다.
 */
@RestController
class BrowseItemsController(private val browse: BrowseItemsService, private val savedSearches: SavedSearchService) {

	@GetMapping("/items")
	fun recent(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@RequestParam(required = false) cursor: String?,
		@RequestParam(required = false) limit: String?,
		@RequestParam(required = false) from: String?,
		@RequestParam(required = false) to: String?,
	): ItemPageResponse {
		val page = browse.recent(userId, beforeNumber(cursor), pageSizeOf(limit), savedRange(from, to))
		return ItemPageResponse(page.items.map { ItemSummaryResponse.of(it) }, page.total, page.nextBeforeNumber?.toString())
	}

	/** 검색어는 띄어쓰기로 낱말을 나눈다. 태그는 `#` 없이 받고 소문자로 맞춘다(ARC-002 규칙 5). */
	@GetMapping("/items/search")
	fun search(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@RequestParam(required = false) q: String?,
		@RequestParam(required = false) tag: List<String>?,
		@RequestParam(required = false) cursor: String?,
		@RequestParam(required = false) limit: String?,
		@RequestParam(required = false) from: String?,
		@RequestParam(required = false) to: String?,
	): SearchPageResponse {
		val words = q?.split(WHITESPACE)?.filter { it.isNotEmpty() }?.distinct().orEmpty()
		val tags = tag.orEmpty().map { it.trim().ifEmpty { invalid("tag must not be empty") }.lowercase() }.distinct()
		if (words.isEmpty() && tags.isEmpty()) invalid("q or tag is required")
		val page = browse.search(userId, SearchQuery(words, tags, savedRange(from, to)), beforeNumber(cursor), pageSizeOf(limit))
		return SearchPageResponse(
			items = page.hits.map { ItemSummaryResponse.of(it.item, it.matchedIn) },
			total = page.total,
			nextCursor = page.nextBeforeNumber?.toString(),
			isSavedSearch = savedSearches.isSaved(userId, words, tags),
		)
	}

	@GetMapping("/items/status")
	fun statuses(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@RequestParam(required = false) numbers: String?,
	): ItemLookupResponse {
		val parsed = numbers?.takeIf { it.isNotEmpty() }?.split(',')
			?.map { positiveLong(it) ?: invalid("numbers must be positive integers") }
			?: invalid("numbers is required")
		val lookup = browse.lookup(userId, parsed)
		return ItemLookupResponse(lookup.items.map { ItemSummaryResponse.of(it) }, lookup.missing)
	}

	private fun beforeNumber(cursor: String?): Long? = cursor?.let { positiveLong(it) ?: invalid("cursor is invalid") }

	/** RFC 3339 시각(openapi SavedFrom·SavedTo). 시간대 없는 값은 받지 않는다. */
	private fun savedRange(from: String?, to: String?): SavedRange =
		SavedRange(from?.let { instant(it, "from") }, to?.let { instant(it, "to") })

	private fun instant(value: String, name: String): Instant =
		runCatching { OffsetDateTime.parse(value).toInstant() }.getOrElse { invalid("$name must be an RFC 3339 date-time") }

	private fun positiveLong(value: String): Long? = value.toLongOrNull()?.takeIf { it >= 1 }

	private fun invalid(detail: String): Nothing = throw ApiProblem.invalidRequest(detail)

	private companion object {
		val WHITESPACE = Regex("\\s+")
	}
}

private const val DEFAULT_LIMIT = 10
private val LIMIT_RANGE = 1..50

/** openapi `Limit`. 없으면 10, 1..50 밖이면 `invalid_request`. */
internal fun pageSizeOf(limit: String?): Int =
	limit?.let { value ->
		value.toIntOrNull()?.takeIf { it in LIMIT_RANGE } ?: throw ApiProblem.invalidRequest("limit must be 1..50")
	} ?: DEFAULT_LIMIT
