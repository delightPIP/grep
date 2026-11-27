package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.domain.ItemRef
import com.unwrap.grep.features.archive.domain.TrashService
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/** openapi `NumbersRequest`. 값 검사는 [numbersOf]가 한다. */
data class NumbersRequest(val numbers: List<Long?>?)

/** openapi `ItemRefList`. */
data class ItemRefListResponse(val items: List<ItemRef>)

/** POST /items/trash(trashItems), POST /items/restore(restoreItems). */
@RestController
class TrashController(private val trash: TrashService) {

	@PostMapping("/items/trash")
	fun moveToTrash(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @RequestBody request: NumbersRequest) =
		ItemRefListResponse(trash.moveToTrash(userId, numbersOf(request)))

	@PostMapping("/items/restore")
	fun restore(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @RequestBody request: NumbersRequest) =
		ItemRefListResponse(trash.restore(userId, numbersOf(request)))
}

internal fun numbersOf(request: NumbersRequest): List<Long> {
	val numbers = request.numbers?.takeIf { it.isNotEmpty() } ?: throw ApiProblem.invalidRequest("numbers is required")
	if (numbers.any { it == null || it < 1 }) throw ApiProblem.invalidRequest("numbers must be positive integers")
	return numbers.filterNotNull()
}
