package com.unwrap.grep.features.account.adapters.http

import com.unwrap.grep.features.account.domain.ClientRegistration
import com.unwrap.grep.features.account.domain.IssuedTokens
import com.unwrap.grep.features.account.domain.OAuthError
import com.unwrap.grep.features.account.domain.OAuthService
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.CacheControl
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

/**
 * OAuth 2.1 인가 서버의 기계용 엔드포인트(ADR-BCK-015 결정 1). MCP 인가 사양(2025-06-18)이 요구하는 것만 둔다.
 * - 보호 자원 메타데이터 RFC 9728, 인가 서버 메타데이터 RFC 8414, 동적 등록 RFC 7591, PKCE RFC 7636
 * 응답 필드 이름은 RFC 그대로(snake_case)라 Map으로 쓴다.
 */
@RestController
class OAuthEndpointsController(
	private val oauth: OAuthService,
	@Value("\${grep.public-url}") publicUrl: String,
) {
	private val baseUrl = publicUrl.trimEnd('/')

	@GetMapping("/.well-known/oauth-protected-resource", "/.well-known/oauth-protected-resource/mcp")
	fun protectedResource(): Map<String, Any> = mapOf(
		"resource" to "$baseUrl/mcp",
		"authorization_servers" to listOf(baseUrl),
		"bearer_methods_supported" to listOf("header"),
		"resource_name" to "그렙",
	)

	@GetMapping("/.well-known/oauth-authorization-server")
	fun authorizationServer(): Map<String, Any> = mapOf(
		"issuer" to baseUrl,
		"authorization_endpoint" to "$baseUrl/oauth/authorize",
		"token_endpoint" to "$baseUrl/oauth/token",
		"registration_endpoint" to "$baseUrl/oauth/register",
		"response_types_supported" to listOf("code"),
		"grant_types_supported" to GRANT_TYPES,
		"code_challenge_methods_supported" to listOf("S256"),
		"token_endpoint_auth_methods_supported" to listOf(AUTH_METHOD_NONE),
		"authorization_response_iss_parameter_supported" to true,
	)

	/** 공개 클라이언트만 받는다. 요청한 인증 방식과 관계없이 `none`으로 등록한다(RFC 7591 3.2.1, 서버가 값을 바꿀 수 있음). */
	@PostMapping("/oauth/register", consumes = [MediaType.APPLICATION_JSON_VALUE])
	fun register(@RequestBody body: Map<String, Any?>): ResponseEntity<Map<String, Any>> {
		val uris = (body["redirect_uris"] as? List<*>)?.map { it as? String ?: throw OAuthError("invalid_redirect_uri", "redirect_uris must be strings") }
			?: throw OAuthError("invalid_redirect_uri", "redirect_uris is required")
		val client = oauth.register(ClientRegistration(body["client_name"] as? String, uris))
		return ResponseEntity.status(HttpStatus.CREATED).cacheControl(CacheControl.noStore()).body(
			mapOf(
				"client_id" to client.id,
				"client_name" to client.name,
				"redirect_uris" to client.redirectUris,
				"grant_types" to GRANT_TYPES,
				"response_types" to listOf("code"),
				"token_endpoint_auth_method" to AUTH_METHOD_NONE,
			),
		)
	}

	@PostMapping("/oauth/token", consumes = [MediaType.APPLICATION_FORM_URLENCODED_VALUE])
	fun token(
		@RequestParam("grant_type", required = false) grantType: String?,
		@RequestParam(required = false) code: String?,
		@RequestParam("redirect_uri", required = false) redirectUri: String?,
		@RequestParam("client_id", required = false) clientId: String?,
		@RequestParam("code_verifier", required = false) codeVerifier: String?,
		@RequestParam("refresh_token", required = false) refreshToken: String?,
	): ResponseEntity<Map<String, Any>> {
		val tokens = when (grantType) {
			"authorization_code" -> oauth.exchangeCode(code, clientId, redirectUri, codeVerifier)
			"refresh_token" -> oauth.refresh(refreshToken, clientId)
			else -> throw OAuthError("unsupported_grant_type", "grant_type must be authorization_code or refresh_token")
		}
		return ResponseEntity.ok().cacheControl(CacheControl.noStore()).header("Pragma", "no-cache").body(tokenBody(tokens))
	}

	@ExceptionHandler(OAuthError::class)
	fun oauthError(e: OAuthError): ResponseEntity<Map<String, Any>> =
		ResponseEntity.badRequest().cacheControl(CacheControl.noStore())
			.body(mapOf("error" to e.code, "error_description" to e.description))

	private fun tokenBody(tokens: IssuedTokens): Map<String, Any> = mapOf(
		"access_token" to tokens.accessToken,
		"token_type" to "Bearer",
		"expires_in" to tokens.expiresInSeconds,
		"refresh_token" to tokens.refreshToken,
	)

	private companion object {
		const val AUTH_METHOD_NONE = "none"
		val GRANT_TYPES = listOf("authorization_code", "refresh_token")
	}
}
