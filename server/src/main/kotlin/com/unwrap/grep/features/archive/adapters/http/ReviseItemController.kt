package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.domain.ItemRevision
import com.unwrap.grep.features.archive.domain.ReviseItemService
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/** openapi `ReviseItemRequest`. 값 검사는 [ReviseItemController]가 한다. */
data class ReviseItemRequest(val title: String?, val summary: String?, val removeTags: List<String?>?)

/** PATCH /items/{number}(reviseItem). 응답은 고친 자료의 `ItemSummary`다. */
@RestController
class ReviseItemController(private val revise: ReviseItemService) {

	@PatchMapping("/items/{number}")
	fun revise(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@PathVariable number: String,
		@RequestBody request: ReviseItemRequest,
	): ItemSummaryResponse {
		val itemNumber = number.toLongOrNull()?.takeIf { it >= 1 } ?: invalid("number must be a positive integer")
		return ItemSummaryResponse.of(revise.revise(userId, itemNumber, revisionOf(request)))
	}

	/** 빈 값·공백뿐인 값은 받지 않는다. 지울 태그 앞의 `#`는 떼어 받는다. */
	private fun revisionOf(request: ReviseItemRequest): ItemRevision {
		if (request.title == null && request.summary == null && request.removeTags == null) {
			invalid("title, summary or removeTags is required")
		}
		val title = request.title?.trim()?.ifEmpty { invalid("title must not be blank") }
		val summary = request.summary?.trim()?.ifEmpty { invalid("summary must not be blank") }
		val removeTags = request.removeTags?.let { tags ->
			if (tags.isEmpty()) invalid("removeTags must not be empty")
			tags.map { tag -> tag?.trim()?.removePrefix("#")?.lowercase()?.ifEmpty { null } ?: invalid("tag must not be blank") }
				.distinct()
		}.orEmpty()
		return ItemRevision(title, summary, removeTags)
	}

	private fun invalid(detail: String): Nothing = throw ApiProblem.invalidRequest(detail)
}
