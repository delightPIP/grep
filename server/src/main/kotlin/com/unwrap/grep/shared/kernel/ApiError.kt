package com.unwrap.grep.shared.kernel

import jakarta.servlet.http.HttpServletResponse

/** api/openapi.yaml `Error`. 서버는 코드만 주고 문구는 클라이언트가 정책 원문으로 보여 준다. */
enum class ApiErrorCode(val value: String) {
	UNAUTHORIZED("unauthorized"),
	SESSION_EXPIRED("session_expired"),
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
