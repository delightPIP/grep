package com.unwrap.grep.features.metrics.adapters.http

import com.unwrap.grep.features.metrics.domain.MetricEventService
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/** openapi `EventRequest`. 계약 밖 필드는 읽지 않는다. */
data class EventRequest(val name: String?, val numbers: List<Long?>?, val method: String?)

/** POST /events(recordEvent). 지금은 `handoff_copied`만 받는다. 기록에 실패해도 204다. */
@RestController
class EventsController(private val events: MetricEventService) {

	@PostMapping("/events")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	fun record(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @RequestBody request: EventRequest) {
		if (request.name != MetricEventService.HANDOFF_COPIED) invalid("name must be handoff_copied")
		val method = request.method?.takeIf { it in MetricEventService.HANDOFF_METHODS } ?: invalid("method must be pick or pipe")
		val numbers = request.numbers?.takeIf { it.isNotEmpty() } ?: invalid("numbers is required")
		if (numbers.any { it == null || it < 1 }) invalid("numbers must be positive integers")
		events.handoffCopied(userId, numbers.filterNotNull(), method)
	}

	private fun invalid(detail: String): Nothing = throw ApiProblem.invalidRequest(detail)
}
