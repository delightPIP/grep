package com.unwrap.grep.features.account.domain

/** 서명을 검증한 Supabase 접근 토큰에서 승인 화면이 쓰는 값. 클레임이 모자라면 [identity]가 null이다. */
data class VerifiedSupabaseToken(val identity: TokenIdentity?, val email: String?)

/** 승인 화면 로그인에서 받은 Supabase 접근 토큰을 검증하는 포트. 검증에 실패하면 null. */
fun interface SupabaseTokenVerifier {
	fun verify(accessToken: String): VerifiedSupabaseToken?
}

/** `/oauth/callback` 결과. HTTP 응답 모양은 컨트롤러가 정한다. */
sealed interface ConsentLoginResult {
	/** 진행 중인 승인 요청이 없거나 만료됐다. */
	data object Expired : ConsentLoginResult

	/** 로그인 화면을 [notice](ACC-001 문구)와 함께 다시 보인다. */
	data class Retry(val notice: String) : ConsentLoginResult

	/** 계정을 붙였다. 승인 화면으로 보낸다. */
	data object LoggedIn : ConsentLoginResult
}

/**
 * 승인 화면의 Supabase 로그인 마무리(ADR-BCK-015 결정 2, ACC-001).
 * 인가 코드를 Supabase 세션으로 바꾸고, 계정을 찾아 진행 중인 승인 요청에 붙인 뒤 Supabase 세션을 끝낸다.
 */
class ConsentLoginService(
	private val pending: PendingAuthorizations,
	private val supabase: SupabaseLogin,
	private val tokens: SupabaseTokenVerifier,
	private val accounts: AccountService,
) {

	/** 동의 화면에서 취소하면 [error]가 `access_denied`다(ACC-001 비고). */
	fun completeLogin(requestId: String?, code: String?, error: String?): ConsentLoginResult {
		val current = pending.find(requestId) ?: return ConsentLoginResult.Expired
		val verifier = current.loginVerifier
		if (error != null || code.isNullOrBlank() || verifier == null) {
			val notice = if (error == "access_denied") CANCELLED else "$FAILED$DENIED"
			return ConsentLoginResult.Retry(notice)
		}
		val token = when (val exchanged = supabase.exchange(code, verifier)) {
			is LoginExchange.Failure -> return ConsentLoginResult.Retry("$FAILED${exchanged.reason}")
			is LoginExchange.Success -> exchanged.accessToken
		}
		val account = consentAccount(token) ?: return ConsentLoginResult.Retry("$FAILED$DENIED")
		pending.update(current.copy(loginVerifier = null, account = account))
		supabase.signOut(token)
		return ConsentLoginResult.LoggedIn
	}

	/** 승인 화면 첫 줄의 `<계정>`: 이메일과 로그인 방식. 계정은 로그인 방식마다 따로다(ACC-001 규칙 4). */
	private fun consentAccount(supabaseToken: String): ConsentAccount? {
		val verified = tokens.verify(supabaseToken) ?: return null
		val identity = verified.identity ?: return null
		val account = (accounts.authenticate(identity) as? AuthResult.Active)?.account ?: return null
		val provider = if (account.provider == AuthProvider.GOOGLE) "Google" else "GitHub"
		val label = verified.email?.let { "$it($provider)" } ?: "$provider 계정"
		return ConsentAccount(account.userId, label)
	}

	private companion object {
		const val CANCELLED = "✗ 로그인 취소됨"
		const val FAILED = "✗ 로그인 실패: "
		const val DENIED = "권한 거부"
	}
}
