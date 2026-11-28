package com.unwrap.grep.features.account.adapters.http

import com.unwrap.grep.features.account.domain.AccountService
import com.unwrap.grep.features.account.domain.AuthProvider
import com.unwrap.grep.features.account.domain.AuthorizationRedirectError
import com.unwrap.grep.features.account.domain.AuthResult
import com.unwrap.grep.features.account.domain.ConnectionTokens
import com.unwrap.grep.features.account.domain.ConsentAccount
import com.unwrap.grep.features.account.domain.LoginExchange
import com.unwrap.grep.features.account.domain.OAuthError
import com.unwrap.grep.features.account.domain.OAuthService
import com.unwrap.grep.features.account.domain.PendingAuthorization
import com.unwrap.grep.features.account.domain.PendingAuthorizations
import com.unwrap.grep.features.account.domain.SupabaseLogin
import com.unwrap.grep.features.account.domain.UntrustedAuthorizationRequest
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseCookie
import org.springframework.http.ResponseEntity
import org.springframework.security.oauth2.jwt.JwtDecoder
import org.springframework.security.oauth2.jwt.JwtException
import org.springframework.web.bind.annotation.CookieValue
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.util.UriComponentsBuilder
import java.net.URI
import java.time.Duration

/**
 * 연결 승인 화면 흐름(ADR-BCK-015 결정 1·2, ARC-009 규칙 7·9).
 * `/oauth/authorize` → 로그인 화면(ACC-001) → Supabase 로그인 → `/oauth/callback` → `/oauth/consent` → `/oauth/decision`.
 * 브라우저는 진행 중인 요청 ID만 쿠키로 든다. 쿠키가 SameSite=Lax라 다른 사이트에서 보낸 허용 요청에는 실리지 않는다.
 */
@RestController
class ConsentController(
	private val oauth: OAuthService,
	private val pending: PendingAuthorizations,
	private val supabase: SupabaseLogin,
	private val jwtDecoder: JwtDecoder,
	private val accounts: AccountService,
	@Value("\${grep.public-url}") publicUrl: String,
) {
	private val baseUrl = publicUrl.trimEnd('/')
	private val secureCookie = baseUrl.startsWith("https://")

	@GetMapping("/oauth/authorize")
	fun authorize(
		@RequestParam("client_id", required = false) clientId: String?,
		@RequestParam("redirect_uri", required = false) redirectUri: String?,
		@RequestParam("response_type", required = false) responseType: String?,
		@RequestParam("code_challenge", required = false) codeChallenge: String?,
		@RequestParam("code_challenge_method", required = false) codeChallengeMethod: String?,
		@RequestParam(required = false) state: String?,
	): ResponseEntity<String> {
		val request = try {
			oauth.authorizationRequest(clientId, redirectUri, responseType, codeChallenge, codeChallengeMethod, state)
		} catch (e: UntrustedAuthorizationRequest) {
			return html(HttpStatus.BAD_REQUEST, ConsentPages.invalid())
		} catch (e: AuthorizationRedirectError) {
			val location = withParams(e.redirectUri, "error" to e.code, "state" to e.state, "iss" to baseUrl)
			return ResponseEntity.status(HttpStatus.FOUND).location(URI(location)).build()
		}
		val started = try {
			pending.start(request)
		} catch (e: OAuthError) {
			return html(HttpStatus.SERVICE_UNAVAILABLE, ConsentPages.expired())
		}
		return html(HttpStatus.OK, ConsentPages.login(notice = null), cookie(started.id))
	}

	@GetMapping("/oauth/login")
	fun login(
		@RequestParam(required = false) provider: String?,
		@CookieValue(COOKIE, required = false) requestId: String?,
	): ResponseEntity<String> {
		val current = pending.find(requestId) ?: return html(HttpStatus.BAD_REQUEST, ConsentPages.expired())
		val authProvider = AuthProvider.fromClaim(provider) ?: return html(HttpStatus.BAD_REQUEST, ConsentPages.login(notice = null))
		val verifier = ConnectionTokens.newSecret("")
		pending.update(current.copy(loginVerifier = verifier))
		val location = supabase.authorizeUrl(authProvider, "$baseUrl$CALLBACK_PATH", ConnectionTokens.s256(verifier))
		return ResponseEntity.status(HttpStatus.FOUND).location(location).build()
	}

	/** Supabase가 돌려보내는 곳. 동의 화면에서 취소하면 `error=access_denied`가 온다(ACC-001 비고). */
	@GetMapping(CALLBACK_PATH)
	fun callback(
		@RequestParam(required = false) code: String?,
		@RequestParam(required = false) error: String?,
		@CookieValue(COOKIE, required = false) requestId: String?,
	): ResponseEntity<String> {
		val current = pending.find(requestId) ?: return html(HttpStatus.BAD_REQUEST, ConsentPages.expired())
		val verifier = current.loginVerifier
		if (error != null || code.isNullOrBlank() || verifier == null) {
			val notice = if (error == "access_denied") CANCELLED else "$FAILED$DENIED"
			return html(HttpStatus.OK, ConsentPages.login(notice))
		}
		val token = when (val exchanged = supabase.exchange(code, verifier)) {
			is LoginExchange.Failure -> return html(HttpStatus.OK, ConsentPages.login("$FAILED${exchanged.reason}"))
			is LoginExchange.Success -> exchanged.accessToken
		}
		val account = consentAccount(token) ?: return html(HttpStatus.OK, ConsentPages.login("$FAILED$DENIED"))
		pending.update(current.copy(loginVerifier = null, account = account))
		supabase.signOut(token)
		return ResponseEntity.status(HttpStatus.SEE_OTHER).location(URI("$baseUrl$CONSENT_PATH")).build()
	}

	@GetMapping(CONSENT_PATH)
	fun consent(@CookieValue(COOKIE, required = false) requestId: String?): ResponseEntity<String> {
		val current = pending.find(requestId) ?: return html(HttpStatus.BAD_REQUEST, ConsentPages.expired())
		val account = current.account ?: return html(HttpStatus.OK, ConsentPages.login(notice = null))
		return html(HttpStatus.OK, ConsentPages.consent(current.request.client.name, account.label, current.id))
	}

	/** 허용·거부. 폼의 요청 ID와 쿠키가 같아야 한다. 한 요청은 한 번만 결정한다. */
	@PostMapping("/oauth/decision", consumes = [MediaType.APPLICATION_FORM_URLENCODED_VALUE])
	fun decide(
		@RequestParam("request", required = false) formRequestId: String?,
		@RequestParam(required = false) decision: String?,
		@CookieValue(COOKIE, required = false) requestId: String?,
	): ResponseEntity<String> {
		if (requestId == null || formRequestId == null || !ConnectionTokens.matches(requestId, formRequestId)) {
			return html(HttpStatus.BAD_REQUEST, ConsentPages.expired())
		}
		val current = pending.find(requestId)?.takeIf { it.account != null } ?: return html(HttpStatus.BAD_REQUEST, ConsentPages.expired())
		if (decision != ALLOW && decision != DENY) return html(HttpStatus.BAD_REQUEST, ConsentPages.invalid())
		val taken = pending.take(current.id) ?: return html(HttpStatus.BAD_REQUEST, ConsentPages.expired())
		return if (decision == ALLOW) allow(taken) else deny(taken)
	}

	private fun allow(taken: PendingAuthorization): ResponseEntity<String> {
		val request = taken.request
		val code = oauth.approve(request, taken.account!!.userId)
		val redirect = withParams(request.redirectUri, "code" to code, "state" to request.state, "iss" to baseUrl)
		return html(HttpStatus.OK, ConsentPages.allowed(request.client.name, redirect), clearCookie())
	}

	private fun deny(taken: PendingAuthorization): ResponseEntity<String> {
		val request = taken.request
		val redirect = withParams(request.redirectUri, "error" to "access_denied", "state" to request.state, "iss" to baseUrl)
		return html(HttpStatus.OK, ConsentPages.denied(request.client.name, redirect), clearCookie())
	}

	/** 승인 화면 첫 줄의 `<계정>`: 이메일과 로그인 방식. 계정은 로그인 방식마다 따로다(ACC-001 규칙 4). */
	private fun consentAccount(supabaseToken: String): ConsentAccount? {
		val jwt = try {
			jwtDecoder.decode(supabaseToken)
		} catch (e: JwtException) {
			return null
		}
		val identity = SupabaseClaims.identity(jwt) ?: return null
		val account = (accounts.authenticate(identity) as? AuthResult.Active)?.account ?: return null
		val provider = if (account.provider == AuthProvider.GOOGLE) "Google" else "GitHub"
		val label = SupabaseClaims.email(jwt)?.let { "$it($provider)" } ?: "$provider 계정"
		return ConsentAccount(account.userId, label)
	}

	private fun withParams(uri: String, vararg params: Pair<String, String?>): String {
		val builder = UriComponentsBuilder.fromUriString(uri)
		params.forEach { (name, value) -> if (value != null) builder.queryParam(name, value) }
		return builder.encode().build().toUriString()
	}

	private fun cookie(value: String): ResponseCookie =
		ResponseCookie.from(COOKIE, value).path("/oauth").httpOnly(true).secure(secureCookie).sameSite("Lax")
			.maxAge(COOKIE_TTL).build()

	private fun clearCookie(): ResponseCookie =
		ResponseCookie.from(COOKIE, "").path("/oauth").httpOnly(true).secure(secureCookie).sameSite("Lax").maxAge(0).build()

	/** 다른 사이트가 승인 화면을 틀 안에 넣어 누르게 하지 못하게 한다. */
	private fun html(status: HttpStatus, body: String, cookie: ResponseCookie? = null): ResponseEntity<String> {
		val builder = ResponseEntity.status(status)
			.contentType(MediaType("text", "html", Charsets.UTF_8))
			.header(HttpHeaders.CACHE_CONTROL, "no-store")
			.header("Content-Security-Policy", CSP)
			.header("Referrer-Policy", "no-referrer")
		cookie?.let { builder.header(HttpHeaders.SET_COOKIE, it.toString()) }
		return builder.body(body)
	}

	private companion object {
		const val COOKIE = "grep_connect"
		const val CALLBACK_PATH = "/oauth/callback"
		const val CONSENT_PATH = "/oauth/consent"
		const val ALLOW = "allow"
		const val DENY = "deny"
		const val CANCELLED = "✗ 로그인 취소됨"
		const val FAILED = "✗ 로그인 실패: "
		const val DENIED = "권한 거부"
		const val CSP = "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'"
		val COOKIE_TTL: Duration = Duration.ofMinutes(10)
	}
}
