package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.domain.ItemRef
import com.unwrap.grep.features.archive.domain.TrashCursor
import com.unwrap.grep.features.archive.domain.TrashService
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import com.unwrap.grep.shared.kernel.CountResponse
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

/** openapi `NumbersRequest`. 값 검사는 [numbersOf]가 한다. */
data class NumbersRequest(val numbers: List<Long?>?)

/** openapi `ItemRefList`. */
data class ItemRefListResponse(val items: List<ItemRef>)

/** openapi `TrashItem`. */
data class TrashItemResponse(val item: ItemSummaryResponse, val trashedAt: Instant, val daysLeft: Int)

/** openapi `TrashPage`. */
data class TrashPageResponse(val items: List<TrashItemResponse>, val total: Long, val nextCursor: String?)

/**
 * 휴지통(ARC-008): POST /items/trash(trashItems), POST /items/restore(restoreItems),
 * GET /items/trash(listTrash), DELETE /items/trash(emptyTrash).
 * 목록 커서는 앞 쪽 마지막 자료의 지운 시각(에포크 마이크로초)과 번호다. 클라이언트는 뜻을 모르는 문자열로만 다룬다.
 */
@RestController
class TrashController(private val trash: TrashService) {

	@PostMapping("/items/trash")
	fun moveToTrash(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @RequestBody request: NumbersRequest) =
		ItemRefListResponse(trash.moveToTrash(userId, numbersOf(request)))

	@PostMapping("/items/restore")
	fun restore(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @RequestBody request: NumbersRequest) =
		ItemRefListResponse(trash.restore(userId, numbersOf(request)))

	@GetMapping("/items/trash")
	fun list(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@RequestParam(required = false) cursor: String?,
		@RequestParam(required = false) limit: String?,
	): TrashPageResponse {
		val page = trash.list(userId, cursor?.let { parseCursor(it) }, pageSizeOf(limit))
		return TrashPageResponse(
			items = page.entries.map { TrashItemResponse(ItemSummaryResponse.of(it.item), it.trashedAt, it.daysLeft) },
			total = page.total,
			nextCursor = page.next?.let { "${ChronoUnit.MICROS.between(Instant.EPOCH, it.trashedAt)}_${it.number}" },
		)
	}

	@DeleteMapping("/items/trash")
	fun empty(@RequestAttribute(CURRENT_USER_ID) userId: UUID) = CountResponse(trash.empty(userId))

	private fun parseCursor(value: String): TrashCursor {
		val parts = value.split('_')
		val micros = parts.getOrNull(0)?.toLongOrNull()
		val number = parts.getOrNull(1)?.toLongOrNull()?.takeIf { it >= 1 }
		if (parts.size != 2 || micros == null || number == null) throw ApiProblem.invalidRequest("cursor is invalid")
		return TrashCursor(Instant.EPOCH.plus(micros, ChronoUnit.MICROS), number)
	}
}

internal fun numbersOf(request: NumbersRequest): List<Long> {
	val numbers = request.numbers?.takeIf { it.isNotEmpty() } ?: throw ApiProblem.invalidRequest("numbers is required")
	if (numbers.any { it == null || it < 1 }) throw ApiProblem.invalidRequest("numbers must be positive integers")
	return numbers.filterNotNull()
}
