package com.unwrap.grep.features.account.adapters.supabase

import com.unwrap.grep.features.account.adapters.http.SupabaseClaims
import com.unwrap.grep.features.account.domain.SupabaseTokenVerifier
import com.unwrap.grep.features.account.domain.VerifiedSupabaseToken
import org.springframework.security.oauth2.jwt.JwtDecoder
import org.springframework.security.oauth2.jwt.JwtException
import org.springframework.stereotype.Component

/** 리소스 서버와 같은 [JwtDecoder]로 서명·만료를 검증한다. */
@Component
class JwtSupabaseTokenVerifier(private val jwtDecoder: JwtDecoder) : SupabaseTokenVerifier {

	override fun verify(accessToken: String): VerifiedSupabaseToken? {
		val jwt = try {
			jwtDecoder.decode(accessToken)
		} catch (e: JwtException) {
			return null
		}
		return VerifiedSupabaseToken(SupabaseClaims.identity(jwt), SupabaseClaims.email(jwt))
	}
}
