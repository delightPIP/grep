package com.unwrap.grep.shared.kernel

import org.springframework.http.ResponseEntity
import org.springframework.http.converter.HttpMessageNotReadableException
import org.springframework.web.HttpMediaTypeNotSupportedException
import org.springframework.web.bind.MissingRequestHeaderException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice

/** 계약(openapi `Error`) 모양으로 오류를 돌려준다. 본문이 계약과 다르면 모두 `invalid_request`다. */
@RestControllerAdvice
class ApiErrorHandler {

	@ExceptionHandler(ApiProblem::class)
	fun problem(e: ApiProblem): ResponseEntity<ApiErrorBody> = ResponseEntity.status(e.code.status).body(e.toBody())

	@ExceptionHandler(
		HttpMessageNotReadableException::class,
		HttpMediaTypeNotSupportedException::class,
		MissingRequestHeaderException::class,
	)
	fun unreadable(e: Exception): ResponseEntity<ApiErrorBody> =
		problem(ApiProblem.invalidRequest(e.message ?: "invalid request"))
}
