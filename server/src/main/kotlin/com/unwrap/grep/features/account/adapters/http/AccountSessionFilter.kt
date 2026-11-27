package com.unwrap.grep.features.account.adapters.http

import com.unwrap.grep.features.account.domain.AccountService
import com.unwrap.grep.features.account.domain.AuthProvider
import com.unwrap.grep.features.account.domain.AuthResult
import com.unwrap.grep.features.account.domain.TokenIdentity
import com.unwrap.grep.shared.kernel.ApiError
import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken
import org.springframework.web.filter.OncePerRequestFilter
import java.util.UUID

/**
 * JWT 검증 뒤에 돈다. 토큰의 sub·app_metadata.provider·session_id로 계정과 세션을 확인하고,
 * 통과하면 요청 속성 [CURRENT_ACCOUNT]에 계정을, [CURRENT_USER_ID]에 사용자 ID를 넣는다.
 * 클레임 이름 근거: https://supabase.com/docs/guides/auth/jwt-fields
 */
class AccountSessionFilter(private val accountService: AccountService) : OncePerRequestFilter() {

	override fun doFilterInternal(request: HttpServletRequest, response: HttpServletResponse, chain: FilterChain) {
		val authentication = SecurityContextHolder.getContext().authentication
		if (authentication !is JwtAuthenticationToken) {
			chain.doFilter(request, response)
			return
		}
		val identity = toIdentity(authentication.token)
		val result = if (identity == null) AuthResult.Rejected else accountService.authenticate(identity)
		when (result) {
			is AuthResult.Active -> {
				request.setAttribute(CURRENT_ACCOUNT, result.account)
				request.setAttribute(CURRENT_USER_ID, result.account.userId)
				chain.doFilter(request, response)
			}
			AuthResult.SessionExpired -> ApiError.writeUnauthorized(response, ApiErrorCode.SESSION_EXPIRED)
			AuthResult.Rejected -> ApiError.writeUnauthorized(response, ApiErrorCode.UNAUTHORIZED)
		}
	}

	private fun toIdentity(jwt: Jwt): TokenIdentity? {
		val appMetadata = jwt.getClaimAsMap("app_metadata") ?: return null
		val provider = AuthProvider.fromClaim(appMetadata["provider"] as? String) ?: return null
		val externalId = jwt.subject?.takeIf { it.isNotBlank() } ?: return null
		val sessionId = jwt.getClaimAsString("session_id")
			?.let { runCatching { UUID.fromString(it) }.getOrNull() }
			?: return null
		return TokenIdentity(provider, externalId, sessionId)
	}

	companion object {
		const val CURRENT_ACCOUNT = "grep.currentAccount"
	}
}
