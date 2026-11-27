package com.unwrap.grep.shared.kernel

import com.fasterxml.jackson.annotation.JsonInclude
import jakarta.servlet.http.HttpServletResponse

/** api/openapi.yaml `Error`. 서버는 코드만 주고 문구는 클라이언트가 정책 원문으로 보여 준다. */
enum class ApiErrorCode(val value: String, val status: Int) {
	UNAUTHORIZED("unauthorized", 401),
	SESSION_EXPIRED("session_expired", 401),
	INVALID_REQUEST("invalid_request", 400),
	FILE_TOO_LARGE("file_too_large", 413),
	UNSUPPORTED_FORMAT("unsupported_format", 415),
	NOT_FOUND("not_found", 404),
	INVALID_BUNDLE_NAME("invalid_bundle_name", 400),
	NOT_IN_BUNDLE("not_in_bundle", 404),
}

/** openapi `Error` 본문. 코드에 딸린 필드만 넣고 나머지 키는 빼고 보낸다. */
@JsonInclude(JsonInclude.Include.NON_NULL)
data class ApiErrorBody(
	val code: String,
	val reason: String? = null,
	val numbers: List<Long>? = null,
	val fileName: String? = null,
	val bytes: Long? = null,
	val fileExtension: String? = null,
)

/** 기능 모듈이 계약의 오류로 답할 때 던진다. [ApiErrorHandler]가 상태 코드와 본문으로 바꾼다. */
class ApiProblem(
	val code: ApiErrorCode,
	val reason: String? = null,
	val numbers: List<Long>? = null,
	val fileName: String? = null,
	val bytes: Long? = null,
	val fileExtension: String? = null,
	detail: String = code.value,
) : RuntimeException(detail) {
	fun toBody() = ApiErrorBody(code.value, reason, numbers, fileName, bytes, fileExtension)

	companion object {
		fun invalidRequest(detail: String) = ApiProblem(ApiErrorCode.INVALID_REQUEST, detail = detail)
	}
}

object ApiError {
	fun writeUnauthorized(response: HttpServletResponse, code: ApiErrorCode) {
		response.status = HttpServletResponse.SC_UNAUTHORIZED
		response.setHeader("WWW-Authenticate", "Bearer")
		response.contentType = "application/json"
		response.characterEncoding = "UTF-8"
		// code는 고정 enum 값이라 이스케이프할 문자가 없다.
		response.writer.write("""{"code":"${code.value}"}""")
	}
}
