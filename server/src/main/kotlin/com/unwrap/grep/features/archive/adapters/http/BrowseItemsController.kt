package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.domain.BrowseItemsService
import com.unwrap.grep.features.archive.domain.SearchQuery
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/** openapi `ItemPage`. */
data class ItemPageResponse(val items: List<ItemSummaryResponse>, val nextCursor: String?)

/** openapi `SearchPage`. */
data class SearchPageResponse(val items: List<ItemSummaryResponse>, val total: Long, val nextCursor: String?)

/** openapi `ItemLookup`. */
data class ItemLookupResponse(val items: List<ItemSummaryResponse>, val missing: List<Long>)

/**
 * GET /items(listRecentItems), GET /items/search(searchItems), GET /items/status(getItemStatuses).
 * 쿼리 값은 문자열로 받아 직접 검사한다. 틀리면 Spring 기본 오류가 아니라 `invalid_request`로 답한다.
 * 커서는 앞 쪽 마지막 자료 번호다. 클라이언트는 뜻을 모르는 문자열로만 다룬다.
 */
@RestController
class BrowseItemsController(private val browse: BrowseItemsService) {

	@GetMapping("/items")
	fun recent(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@RequestParam(required = false) cursor: String?,
		@RequestParam(required = false) limit: String?,
	): ItemPageResponse {
		val page = browse.recent(userId, beforeNumber(cursor), pageSizeOf(limit))
		return ItemPageResponse(page.items.map { ItemSummaryResponse.of(it) }, page.nextBeforeNumber?.toString())
	}

	/** 검색어는 띄어쓰기로 낱말을 나눈다. 태그는 `#` 없이 받고 소문자로 맞춘다(ARC-002 규칙 5). */
	@GetMapping("/items/search")
	fun search(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@RequestParam(required = false) q: String?,
		@RequestParam(required = false) tag: List<String>?,
		@RequestParam(required = false) cursor: String?,
		@RequestParam(required = false) limit: String?,
	): SearchPageResponse {
		val words = q?.split(WHITESPACE)?.filter { it.isNotEmpty() }?.distinct().orEmpty()
		val tags = tag.orEmpty().map { it.trim().ifEmpty { invalid("tag must not be empty") }.lowercase() }.distinct()
		if (words.isEmpty() && tags.isEmpty()) invalid("q or tag is required")
		val page = browse.search(userId, SearchQuery(words, tags), beforeNumber(cursor), pageSizeOf(limit))
		return SearchPageResponse(
			items = page.hits.map { ItemSummaryResponse.of(it.item, it.matchedIn) },
			total = page.total,
			nextCursor = page.nextBeforeNumber?.toString(),
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
