package com.unwrap.grep.features.archive.item.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import java.net.URI
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.UUID

data class CreatedUpload(val uploadId: UUID, val uploadUrl: URI, val expiresAt: Instant)

/**
 * 업로드 자리와 서명 PUT URL(ADR-BCK-002 결정 2). 여기서는 크기만 거른다.
 * 형식은 내용으로 정하므로(COM-004 규칙 2) 저장 때 [SaveItemService]가 판정한다.
 */
class UploadService(
	private val uploads: UploadRepository,
	private val storage: ObjectStorage,
	private val clock: Clock,
) {
	fun create(userId: UUID, fileName: String, size: Long): CreatedUpload {
		if (size > SaveItemService.MAX_FILE_BYTES) {
			throw ApiProblem(ApiErrorCode.FILE_TOO_LARGE, fileName = fileName, bytes = size)
		}
		val now = clock.instant()
		val uploadId = UUID.randomUUID()
		// 경로 앞을 사용자 ID로 둬 사용자별로 객체를 나눈다(COM-006).
		val slot = UploadSlot(uploadId, userId, "$userId/$uploadId", fileName)
		uploads.create(slot, size, now)
		val url = storage.presignPut(slot.objectPath, UPLOAD_URL_TTL)
		return CreatedUpload(uploadId, url, now.plus(UPLOAD_URL_TTL))
	}

	companion object {
		/** 서명 URL 유효 시간. 20MB를 느린 망에서 올려도 남는 길이로 개발자가 정했다. */
		val UPLOAD_URL_TTL: Duration = Duration.ofMinutes(15)

		/** COM-004 값 표의 받는 형식. 순서는 openapi `UploadLimits.formats`와 같다. */
		val ACCEPTED_FORMATS: List<FileFormat> = FileFormat.entries
	}
}
