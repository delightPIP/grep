package com.unwrap.grep.features.mcp.adapters.http

import com.unwrap.grep.features.account.api.ConnectionAccess
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.web.filter.OncePerRequestFilter

/**
 * `/mcp`는 연결 토큰(Authorization: Bearer)만 받는다. 토큰은 주소에 넣지 않는다(MCP 인가 사양).
 * 없거나 끊긴 토큰이면 401과 보호 자원 메타데이터 주소를 준다(RFC 9728 5.1). 끊긴 연결은 다음 요청부터 거부된다(ACC-002 규칙 6).
 */
class McpTokenFilter(
	private val connections: ConnectionAccess,
	private val resourceMetadataUrl: String,
) : OncePerRequestFilter() {

	override fun shouldNotFilter(request: HttpServletRequest): Boolean = request.requestURI != MCP_PATH

	override fun doFilterInternal(request: HttpServletRequest, response: HttpServletResponse, chain: FilterChain) {
		val header = request.getHeader("Authorization")
		val token = header?.takeIf { it.startsWith(BEARER, ignoreCase = true) }?.substring(BEARER.length)?.trim()
		val principal = token?.takeIf { it.isNotEmpty() }?.let { connections.authenticate(it) }
		if (principal == null) {
			val error = if (token.isNullOrEmpty()) "" else ", error=\"invalid_token\""
			response.status = HttpServletResponse.SC_UNAUTHORIZED
			response.setHeader("WWW-Authenticate", "Bearer resource_metadata=\"$resourceMetadataUrl\"$error")
			return
		}
		request.setAttribute(CURRENT_USER_ID, principal.userId)
		request.setAttribute(CURRENT_CONNECTION_ID, principal.connectionId)
		chain.doFilter(request, response)
	}

	companion object {
		const val MCP_PATH = "/mcp"
		const val CURRENT_CONNECTION_ID = "grep.currentConnectionId"
		private const val BEARER = "Bearer "
	}
}
