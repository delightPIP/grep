package com.unwrap.grep.features.account.domain

import java.net.URI
import java.time.Clock
import java.time.Instant
import java.util.UUID

/** 동적 등록으로 만든 OAuth 클라이언트 하나 = AI 도구 하나(V4 `oauth_clients`). */
data class OAuthClient(val id: String, val name: String, val redirectUris: List<String>)

/** 쓰고 나서 돌려받은 인가 코드(V4 `oauth_codes`). */
data class RedeemedCode(val clientId: String, val userId: UUID, val redirectUri: String, val codeChallenge: String)

interface OAuthClientRepository {
	fun insert(client: OAuthClient)
	fun find(id: String): OAuthClient?
}

interface OAuthCodeRepository {
	fun insert(codeHash: String, clientId: String, userId: UUID, redirectUri: String, codeChallenge: String, expiresAt: Instant)

	/** 만료 전이고 안 쓴 코드면 쓴 것으로 표시하고 돌려준다. 같은 코드를 두 번 내도 한 번만 성공한다. */
	fun redeem(codeHash: String, now: Instant): RedeemedCode?
}

/** 동적 등록 요청(RFC 7591)에서 쓰는 값만. */
data class ClientRegistration(val clientName: String?, val redirectUris: List<String>)

/** 확인을 마친 인가 요청(`GET /oauth/authorize`). */
data class AuthorizationRequest(
	val client: OAuthClient,
	val redirectUri: String,
	val codeChallenge: String,
	val state: String?,
)

/** OAuth 오류. [code]는 RFC 6749 5.2·RFC 7591 3.2.2의 `error` 값이다. */
class OAuthError(val code: String, val description: String) : RuntimeException(description)

/** 클라이언트에 돌려보낼 인가 요청 오류(RFC 6749 4.1.2.1). [redirectUri]는 확인을 마친 주소다. */
class AuthorizationRedirectError(val redirectUri: String, val code: String, val state: String?) : RuntimeException(code)

/** 클라이언트에 돌려보낼 수 없는 인가 요청 오류(클라이언트·돌아갈 주소를 믿을 수 없음, RFC 6749 4.1.2.1). */
class UntrustedAuthorizationRequest(message: String) : RuntimeException(message)

/**
 * OAuth 2.1 인가 서버의 동적 등록·인가 코드·토큰 교환(ADR-BCK-015 결정 1). 공개 클라이언트만 받고 PKCE S256을 요구한다.
 * shortcut: 등록·토큰 엔드포인트에 호출 횟수 제한이 없다. 실제 사용자를 받을 때 정한다(ARC-009 비고).
 */
open class OAuthService(
	private val clients: OAuthClientRepository,
	private val codes: OAuthCodeRepository,
	private val connections: ConnectionService,
	private val clock: Clock,
) {

	open fun register(registration: ClientRegistration): OAuthClient {
		val uris = registration.redirectUris.distinct()
		if (uris.isEmpty() || uris.size > MAX_REDIRECT_URIS) throw OAuthError("invalid_redirect_uri", "redirect_uris must have 1 to $MAX_REDIRECT_URIS entries")
		uris.forEach { if (!isAllowedRedirect(it)) throw OAuthError("invalid_redirect_uri", "redirect_uri must be https or loopback http") }
		val client = OAuthClient(ConnectionTokens.newClientId(), clientName(registration.clientName), uris)
		clients.insert(client)
		return client
	}

	/**
	 * 클라이언트와 돌아갈 주소가 틀리면 [UntrustedAuthorizationRequest](돌려보내지 않고 화면에 알림),
	 * 그 밖의 오류는 [AuthorizationRedirectError](클라이언트로 돌려보냄, RFC 6749 4.1.2.1).
	 */
	open fun authorizationRequest(
		clientId: String?,
		redirectUri: String?,
		responseType: String?,
		codeChallenge: String?,
		codeChallengeMethod: String?,
		state: String?,
	): AuthorizationRequest {
		val client = clientId?.let { clients.find(it) } ?: throw UntrustedAuthorizationRequest("unknown client_id")
		val uri = redirectUri ?: client.redirectUris.singleOrNull() ?: throw UntrustedAuthorizationRequest("redirect_uri is required")
		if (uri !in client.redirectUris) throw UntrustedAuthorizationRequest("redirect_uri is not registered")
		if (responseType != "code") throw AuthorizationRedirectError(uri, "unsupported_response_type", state)
		if (codeChallenge.isNullOrBlank() || codeChallengeMethod != "S256") throw AuthorizationRedirectError(uri, "invalid_request", state)
		return AuthorizationRequest(client, uri, codeChallenge, state)
	}

	/** 허용(ARC-009 `허용`). 돌려보낼 인가 코드 원문을 준다. */
	open fun approve(request: AuthorizationRequest, userId: UUID): String {
		val code = ConnectionTokens.newSecret(CODE_PREFIX)
		codes.insert(ConnectionTokens.hash(code), request.client.id, userId, request.redirectUri, request.codeChallenge, clock.instant().plus(ConnectionTokens.CODE_TTL))
		return code
	}

	/** `grant_type=authorization_code`. 코드는 한 번만 쓰고, 클라이언트·돌아갈 주소·PKCE가 모두 맞아야 연결을 만든다. */
	open fun exchangeCode(code: String?, clientId: String?, redirectUri: String?, codeVerifier: String?): IssuedTokens {
		if (code.isNullOrBlank() || clientId.isNullOrBlank() || codeVerifier.isNullOrBlank()) {
			throw OAuthError("invalid_request", "code, client_id and code_verifier are required")
		}
		val redeemed = codes.redeem(ConnectionTokens.hash(code), clock.instant()) ?: throw invalidGrant()
		val sameClient = redeemed.clientId == clientId
		val sameRedirect = redirectUri == null || redirectUri == redeemed.redirectUri
		val verified = ConnectionTokens.matches(redeemed.codeChallenge, ConnectionTokens.s256(codeVerifier))
		if (!sameClient || !sameRedirect || !verified) throw invalidGrant()
		return connections.open(redeemed.userId, redeemed.clientId)
	}

	open fun refresh(refreshToken: String?, clientId: String?): IssuedTokens {
		if (refreshToken.isNullOrBlank()) throw OAuthError("invalid_request", "refresh_token is required")
		return connections.refresh(refreshToken, clientId) ?: throw invalidGrant()
	}

	private fun invalidGrant() = OAuthError("invalid_grant", "authorization grant is invalid, expired or revoked")

	/** 이름은 승인 화면·연결 목록에 그대로 보이므로 제어 문자를 빼고 줄인다. 화면에 넣을 때는 HTML 이스케이프한다. */
	private fun clientName(raw: String?): String {
		val cleaned = raw.orEmpty().filterNot { it.isISOControl() }.trim().take(MAX_NAME_CHARS)
		return cleaned.ifEmpty { DEFAULT_CLIENT_NAME }
	}

	/** https, 또는 이 기기 안에서만 열리는 http(RFC 8252 7.3). 조각(#)은 받지 않는다(RFC 6749 3.1.2). */
	private fun isAllowedRedirect(value: String): Boolean {
		if (value.length > MAX_URI_CHARS) return false
		val uri = runCatching { URI(value) }.getOrNull() ?: return false
		if (uri.fragment != null || uri.host.isNullOrEmpty()) return false
		return when (uri.scheme?.lowercase()) {
			"https" -> true
			"http" -> uri.host in LOOPBACK_HOSTS
			else -> false
		}
	}

	private companion object {
		const val CODE_PREFIX = "gco_"
		const val DEFAULT_CLIENT_NAME = "AI 도구"
		const val MAX_REDIRECT_URIS = 5
		const val MAX_URI_CHARS = 2000
		const val MAX_NAME_CHARS = 60
		val LOOPBACK_HOSTS = setOf("localhost", "127.0.0.1", "[::1]")
	}
}
