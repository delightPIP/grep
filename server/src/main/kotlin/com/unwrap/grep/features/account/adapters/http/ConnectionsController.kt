package com.unwrap.grep.features.account.adapters.http

import com.unwrap.grep.features.account.domain.ConnectionEndReason
import com.unwrap.grep.features.account.domain.ConnectionService
import com.unwrap.grep.features.account.domain.EndConnectionResult
import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.beans.factory.annotation.Value
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.util.UUID

/** openapi `Connection`. */
data class ConnectionResponse(val number: Int, val client: String, val connectedAt: Instant, val lastReadAt: Instant?)

/** openapi `ConnectionList`. */
data class ConnectionListResponse(val mcpUrl: String, val connections: List<ConnectionResponse>)

/** openapi `EndConnectionResult`. */
data class EndConnectionResponse(val result: String, val client: String)

/** openapi `CountResult`. */
data class CountResponse(val count: Int)

/** openapi `ConnectionNotices`. */
data class ConnectionNoticesResponse(val ended: List<EndedConnection>) {
	data class EndedConnection(val client: String, val reason: String)
}

/** AI 도구 연결 목록과 끊기(ACC-002 규칙 4·6~11). 그렙 앱이 Supabase 토큰으로 부른다. */
@RestController
class ConnectionsController(
	private val connections: ConnectionService,
	@Value("\${grep.public-url}") publicUrl: String,
) {
	private val mcpUrl = "${publicUrl.trimEnd('/')}/mcp"

	@GetMapping("/connections")
	fun list(@RequestAttribute(CURRENT_USER_ID) userId: UUID) = ConnectionListResponse(
		mcpUrl = mcpUrl,
		connections = connections.list(userId).map { ConnectionResponse(it.number, it.client, it.connectedAt, it.lastReadAt) },
	)

	@DeleteMapping("/connections/{number}")
	fun end(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @PathVariable number: String): EndConnectionResponse {
		val parsed = number.toIntOrNull()?.takeIf { it >= 1 } ?: throw ApiProblem.invalidRequest("number must be a positive integer")
		return when (val result = connections.end(userId, parsed)) {
			is EndConnectionResult.Ended -> EndConnectionResponse("ended", result.client)
			is EndConnectionResult.AlreadyEnded -> EndConnectionResponse("alreadyEnded", result.client)
			EndConnectionResult.NotFound -> throw ApiProblem(ApiErrorCode.NOT_FOUND)
		}
	}

	@PostMapping("/connections/revoke-all")
	fun endAll(@RequestAttribute(CURRENT_USER_ID) userId: UUID) = CountResponse(connections.endAll(userId))

	@PostMapping("/connections/notices")
	fun notices(@RequestAttribute(CURRENT_USER_ID) userId: UUID) = ConnectionNoticesResponse(
		connections.takeNotices(userId).map {
			ConnectionNoticesResponse.EndedConnection(it.client, if (it.reason == ConnectionEndReason.EXPIRED) "expired" else "revoked")
		},
	)
}
