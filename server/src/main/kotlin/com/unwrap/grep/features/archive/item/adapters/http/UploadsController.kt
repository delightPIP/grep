package com.unwrap.grep.features.archive.item.adapters.http

import com.unwrap.grep.features.archive.item.domain.SaveItemService
import com.unwrap.grep.features.archive.item.domain.UploadService
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.util.UUID

data class CreateUploadRequest(val fileName: String?, val size: Long?)

data class UploadResponse(val uploadId: UUID, val uploadUrl: String, val expiresAt: Instant)

data class UploadLimitsResponse(val formats: List<String>, val maxBytes: Long)

@RestController
class UploadsController(private val uploads: UploadService) {

	@PostMapping("/uploads")
	@ResponseStatus(HttpStatus.CREATED)
	fun create(
		@RequestAttribute(CURRENT_USER_ID) userId: UUID,
		@RequestBody request: CreateUploadRequest,
	): UploadResponse {
		val fileName = request.fileName?.takeIf { it.isNotBlank() }
			?: throw ApiProblem.invalidRequest("fileName is required")
		val size = request.size?.takeIf { it >= 0 } ?: throw ApiProblem.invalidRequest("size must be >= 0")
		val created = uploads.create(userId, fileName, size)
		return UploadResponse(created.uploadId, created.uploadUrl.toString(), created.expiresAt)
	}

	@GetMapping("/uploads/limits")
	fun limits() = UploadLimitsResponse(
		formats = UploadService.ACCEPTED_FORMATS.map { it.value },
		maxBytes = SaveItemService.MAX_FILE_BYTES,
	)
}
