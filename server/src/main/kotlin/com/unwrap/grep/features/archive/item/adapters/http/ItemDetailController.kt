package com.unwrap.grep.features.archive.item.adapters.http

import com.unwrap.grep.features.archive.item.domain.ItemDetailService
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RestController
import java.net.URI
import java.util.UUID

/** openapi `ItemDetail`. 필드는 null이어도 모두 키로 싣는다. */
data class ItemDetailResponse(
	val item: ItemSummaryResponse,
	val url: String?,
	val handoffSummary: String?,
	val allTags: List<String>,
	val bundles: List<String>,
	val bodyLength: Int?,
	val body: String?,
	val bodyFromImage: Boolean,
	val originalUrl: URI?,
	val previewUrl: URI?,
)

/** GET /items/{number}(getItemDetail, ARC-011). */
@RestController
class ItemDetailController(private val details: ItemDetailService) {

	@GetMapping("/items/{number}")
	fun detail(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @PathVariable number: String): ItemDetailResponse {
		val itemNumber = number.toLongOrNull()?.takeIf { it >= 1 }
			?: throw ApiProblem.invalidRequest("number must be a positive integer")
		val detail = details.detail(userId, itemNumber)
		return ItemDetailResponse(
			item = ItemSummaryResponse.of(detail.item),
			url = detail.url,
			handoffSummary = detail.handoffSummary,
			allTags = detail.allTags,
			bundles = detail.bundles,
			bodyLength = detail.bodyLength,
			body = detail.body,
			bodyFromImage = detail.bodyFromImage,
			originalUrl = detail.originalUrl,
			previewUrl = detail.previewUrl,
		)
	}
}
