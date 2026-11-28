package com.unwrap.grep.features.account.adapters.http

import com.unwrap.grep.features.account.domain.AuthProvider
import com.unwrap.grep.features.account.domain.TokenIdentity
import org.springframework.security.oauth2.jwt.Jwt
import java.util.UUID

/** 검증된 Supabase 접근 토큰의 클레임. 이름 근거: https://supabase.com/docs/guides/auth/jwt-fields */
object SupabaseClaims {
	fun identity(jwt: Jwt): TokenIdentity? {
		val appMetadata = jwt.getClaimAsMap("app_metadata") ?: return null
		val provider = AuthProvider.fromClaim(appMetadata["provider"] as? String) ?: return null
		val externalId = jwt.subject?.takeIf { it.isNotBlank() } ?: return null
		val sessionId = jwt.getClaimAsString("session_id")
			?.let { runCatching { UUID.fromString(it) }.getOrNull() }
			?: return null
		return TokenIdentity(provider, externalId, sessionId)
	}

	fun email(jwt: Jwt): String? = jwt.getClaimAsString("email")?.takeIf { it.isNotBlank() }
}
