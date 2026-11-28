package com.unwrap.grep.features.archive.item.adapters.http

import com.unwrap.grep.features.archive.item.domain.SaveItemCommand
import com.unwrap.grep.features.archive.item.domain.SaveItemService
import com.unwrap.grep.features.archive.item.domain.SaveOutcome
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/** openapi `SaveItemRequest`. oneOf를 한 모양으로 받고 [toCommand]에서 kind별로 검사한다. */
data class SaveItemRequest(val kind: String?, val url: String?, val text: String?, val uploadId: String?)

data class SaveItemResponse(val result: String, val item: ItemSummaryResponse)

@RestController
class ItemsController(private val saveItems: SaveItemService) {

	@PostMapping("/items")
	fun save(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@RequestHeader(IDEMPOTENCY_KEY, required = false) idempotencyKey: String?,
		@RequestBody request: SaveItemRequest,
	): ResponseEntity<SaveItemResponse> {
		val key = idempotencyKey?.let(::parseUuid)
			?: throw ApiProblem.invalidRequest("$IDEMPOTENCY_KEY header must be a UUID")
		val outcome = saveItems.save(userId, key, toCommand(request))
		val (status, result) = when (outcome) {
			is SaveOutcome.Saved -> HttpStatus.CREATED to "saved"
			is SaveOutcome.Replayed -> HttpStatus.OK to "saved"
			is SaveOutcome.Duplicate -> HttpStatus.OK to "duplicate"
			is SaveOutcome.InTrash -> HttpStatus.OK to "inTrash"
		}
		return ResponseEntity.status(status).body(SaveItemResponse(result, ItemSummaryResponse.of(outcome.item)))
	}

	private fun toCommand(request: SaveItemRequest): SaveItemCommand = when (request.kind) {
		"link" -> SaveItemCommand.Link(request.url?.takeIf { it.isNotBlank() } ?: invalid("url is required"))
		"text" -> SaveItemCommand.Text(request.text?.takeIf { it.isNotEmpty() } ?: invalid("text is required"))
		"file" -> SaveItemCommand.File(request.uploadId?.let(::parseUuid) ?: invalid("uploadId must be a UUID"))
		else -> invalid("kind must be link, text or file")
	}

	private fun invalid(detail: String): Nothing = throw ApiProblem.invalidRequest(detail)

	private companion object {
		const val IDEMPOTENCY_KEY = "Idempotency-Key"
	}
}

private val UUID_PATTERN = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

/** UUID.fromString은 `1-1-1-1-1`도 받으므로 openapi `format: uuid` 모양을 먼저 본다. */
internal fun parseUuid(value: String): UUID? = if (UUID_PATTERN.matches(value)) UUID.fromString(value) else null
