package com.unwrap.grep.features.account.domain

import java.net.URI

/** 승인 화면의 로그인 결과. 실패 이유는 ACC-001 문구 `✗ 로그인 실패: <이유>`의 낱말이다. */
sealed interface LoginExchange {
	data class Success(val accessToken: String) : LoginExchange
	data class Failure(val reason: String) : LoginExchange
}

/**
 * 승인 화면이 기존 Supabase 로그인(ACC-001)을 쓰는 포트(ADR-BCK-015 결정 2). 서버가 PKCE로 직접 로그인을 받는다.
 * 돌아올 주소는 Supabase 대시보드의 Redirect URLs에 있어야 한다.
 */
interface SupabaseLogin {
	fun authorizeUrl(provider: AuthProvider, redirectTo: String, codeChallenge: String): URI

	fun exchange(authCode: String, codeVerifier: String): LoginExchange

	/** 승인에 쓴 Supabase 세션은 더 쓰지 않으므로 끝낸다. 실패해도 승인은 계속한다. */
	fun signOut(accessToken: String)
}
