package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.domain.BundleAddResult
import com.unwrap.grep.features.archive.domain.BundleService
import com.unwrap.grep.features.archive.domain.BundleSummary
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import com.unwrap.grep.shared.kernel.CountResponse
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/** openapi `BundleList`. */
data class BundleListResponse(val bundles: List<BundleSummary>)

/** openapi `BundlePage`. */
data class BundlePageResponse(val name: String, val total: Long, val items: List<ItemSummaryResponse>, val nextCursor: String?)

/**
 * 묶음(ARC-003): GET /bundles(listBundles), GET·DELETE /bundles/{name}(getBundle·deleteBundle),
 * POST /bundles/{name}/items(addToBundle), POST /bundles/{name}/items/remove(removeFromBundle).
 * 커서는 앞 쪽 마지막 자료 번호다. 클라이언트는 뜻을 모르는 문자열로만 다룬다.
 */
@RestController
class BundlesController(private val bundles: BundleService) {

	@GetMapping("/bundles")
	fun list(@RequestAttribute(CURRENT_USER_ID) userId: UUID) = BundleListResponse(bundles.list(userId))

	@GetMapping("/bundles/{name}")
	fun view(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@PathVariable name: String,
		@RequestParam(required = false) cursor: String?,
		@RequestParam(required = false) limit: String?,
	): BundlePageResponse {
		val before = cursor?.let { value -> value.toLongOrNull()?.takeIf { it >= 1 } ?: throw ApiProblem.invalidRequest("cursor is invalid") }
		val page = bundles.view(userId, name, before, pageSizeOf(limit))
		return BundlePageResponse(page.name, page.total, page.items.map { ItemSummaryResponse.of(it) }, page.nextBeforeNumber?.toString())
	}

	@DeleteMapping("/bundles/{name}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	fun delete(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @PathVariable name: String) = bundles.delete(userId, name)

	@PostMapping("/bundles/{name}/items")
	fun add(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@PathVariable name: String,
		@RequestBody request: NumbersRequest,
	): BundleAddResult = bundles.add(userId, name, numbersOf(request))

	@PostMapping("/bundles/{name}/items/remove")
	fun remove(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@PathVariable name: String,
		@RequestBody request: NumbersRequest,
	) = CountResponse(bundles.remove(userId, name, numbersOf(request)).toInt())
}
