package com.unwrap.grep.features.samples.adapters.http

import com.unwrap.grep.features.samples.domain.SampleOutcome
import com.unwrap.grep.features.samples.domain.SampleService
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/** openapi `SampleResult`. */
data class SampleResultResponse(val firstNumber: Long, val lastNumber: Long)

/** POST /samples(saveSamples). 새로 저장하면 201, 이미 받았으면 처음 범위로 200(ARC-010 규칙 7). */
@RestController
class SamplesController(private val samples: SampleService) {

	@PostMapping("/samples")
	fun save(@RequestAttribute(CURRENT_USER_ID) userId: UUID): ResponseEntity<SampleResultResponse> {
		val outcome = samples.save(userId)
		val status = if (outcome is SampleOutcome.Saved) HttpStatus.CREATED else HttpStatus.OK
		return ResponseEntity.status(status).body(SampleResultResponse(outcome.range.first, outcome.range.last))
	}
}
