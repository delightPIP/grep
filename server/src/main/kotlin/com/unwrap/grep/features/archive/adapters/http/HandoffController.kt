package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.domain.Handoff
import com.unwrap.grep.features.archive.domain.HandoffService
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/** openapi `HandoffRequest`. 값 검사는 [HandoffController]가 한다. */
data class HandoffRequest(val numbers: List<Long?>?)

/** POST /handoff(createHandoff). 응답은 openapi `Handoff` 모양 그대로다. */
@RestController
class HandoffController(private val handoffs: HandoffService) {

	@PostMapping("/handoff")
	fun create(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @RequestBody request: HandoffRequest): Handoff {
		val numbers = request.numbers?.takeIf { it.isNotEmpty() }
			?: throw ApiProblem.invalidRequest("numbers is required")
		if (numbers.any { it == null || it < 1 }) throw ApiProblem.invalidRequest("numbers must be positive integers")
		return handoffs.compose(userId, numbers.filterNotNull())
	}
}
