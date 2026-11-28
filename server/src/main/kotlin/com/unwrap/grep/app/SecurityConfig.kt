package com.unwrap.grep.app

import com.unwrap.grep.features.account.adapters.http.AccountSessionFilter
import com.unwrap.grep.features.account.api.ConnectionAccess
import com.unwrap.grep.features.account.domain.AccountService
import com.unwrap.grep.features.mcp.adapters.http.McpTokenFilter
import com.unwrap.grep.shared.kernel.ApiError
import com.unwrap.grep.shared.kernel.ApiErrorCode
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.core.annotation.Order
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.web.AuthenticationEntryPoint
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.authentication.AnonymousAuthenticationFilter
import org.springframework.security.oauth2.server.resource.web.authentication.BearerTokenAuthenticationFilter
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.cors.CorsConfiguration
import org.springframework.web.cors.UrlBasedCorsConfigurationSource
import java.time.Clock

/**
 * 모든 API는 Supabase 접근 토큰이 있어야 한다(ACC-001). 예외는 /health와 AI 도구 연결 경로다.
 * 토큰 검증은 표준 JWKS(ES256)로 한다(ADR-BCK-006 결정 5). 설정값은 application.properties.
 * AI 도구 연결(ADR-BCK-015)의 OAuth 경로는 누구나 부를 수 있고, `/mcp`는 연결 토큰만 받는다([McpTokenFilter]).
 */
@Configuration
class SecurityConfig {

	@Bean
	fun clock(): Clock = Clock.systemUTC()

	@Bean
	@Order(0)
	fun connectionFilterChain(
		http: HttpSecurity,
		connections: ConnectionAccess,
		@Value("\${grep.public-url}") publicUrl: String,
	): SecurityFilterChain {
		val resourceMetadata = "${publicUrl.trimEnd('/')}/.well-known/oauth-protected-resource"
		http
			.securityMatcher("/.well-known/**", "/oauth/**", McpTokenFilter.MCP_PATH)
			.csrf { it.disable() }
			.cors { it.configurationSource(connectionCorsSource()) }
			.sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
			.authorizeHttpRequests { it.anyRequest().permitAll() }
			.addFilterBefore(McpTokenFilter(connections, resourceMetadata), AnonymousAuthenticationFilter::class.java)
		return http.build()
	}

	@Bean
	@Order(1)
	fun securityFilterChain(
		http: HttpSecurity,
		accountService: AccountService,
		@Value("\${grep.web-origin}") webOrigin: String,
	): SecurityFilterChain {
		val unauthorized = AuthenticationEntryPoint { _, response, _ ->
			ApiError.writeUnauthorized(response, ApiErrorCode.UNAUTHORIZED)
		}
		http
			.csrf { it.disable() }
			.cors { it.configurationSource(corsSource(webOrigin)) }
			.sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
			.authorizeHttpRequests {
				it.requestMatchers("/health", "/error").permitAll()
				it.anyRequest().authenticated()
			}
			.oauth2ResourceServer {
				it.jwt { }
				it.authenticationEntryPoint(unauthorized)
			}
			.exceptionHandling { it.authenticationEntryPoint(unauthorized) }
			.addFilterAfter(AccountSessionFilter(accountService), BearerTokenAuthenticationFilter::class.java)
		return http.build()
	}

	/** 브라우저에서 도는 MCP 클라이언트(검사 도구 등)가 메타데이터·등록·토큰·`/mcp`를 부를 수 있게 한다. 쿠키는 쓰지 않는다. */
	private fun connectionCorsSource() = UrlBasedCorsConfigurationSource().apply {
		val open = CorsConfiguration().apply {
			allowedOrigins = listOf("*")
			allowedMethods = listOf("GET", "POST", "OPTIONS")
			allowedHeaders = listOf("Authorization", "Content-Type", "Mcp-Protocol-Version", "Mcp-Session-Id")
			exposedHeaders = listOf("WWW-Authenticate")
		}
		registerCorsConfiguration("/.well-known/**", open)
		registerCorsConfiguration("/oauth/register", open)
		registerCorsConfiguration("/oauth/token", open)
		registerCorsConfiguration(McpTokenFilter.MCP_PATH, open)
	}

	private fun corsSource(webOrigin: String) = UrlBasedCorsConfigurationSource().apply {
		registerCorsConfiguration(
			"/**",
			CorsConfiguration().apply {
				allowedOrigins = listOf(webOrigin)
				allowedMethods = listOf("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
				// 계약(api/openapi.yaml)이 요청 헤더로 받는 것만 허용한다. 빠지면 브라우저가 사전 요청에서 막는다.
				allowedHeaders = listOf("Authorization", "Content-Type", "Idempotency-Key")
			},
		)
	}
}

data class HealthResponse(val status: String)

@RestController
class HealthController {
	@GetMapping("/health")
	fun health() = HealthResponse(status = "ok")
}
