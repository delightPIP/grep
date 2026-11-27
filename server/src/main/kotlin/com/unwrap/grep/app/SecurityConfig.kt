package com.unwrap.grep.app

import com.unwrap.grep.features.account.adapters.http.AccountSessionFilter
import com.unwrap.grep.features.account.domain.AccountService
import com.unwrap.grep.shared.kernel.ApiError
import com.unwrap.grep.shared.kernel.ApiErrorCode
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.web.AuthenticationEntryPoint
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.oauth2.server.resource.web.authentication.BearerTokenAuthenticationFilter
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.cors.CorsConfiguration
import org.springframework.web.cors.UrlBasedCorsConfigurationSource
import java.time.Clock

/**
 * 모든 API는 Supabase 접근 토큰이 있어야 한다(ACC-001). 예외는 /health뿐이다.
 * 토큰 검증은 표준 JWKS(ES256)로 한다(ADR-BCK-006 결정 5). 설정값은 application.properties.
 */
@Configuration
class SecurityConfig {

	@Bean
	fun clock(): Clock = Clock.systemUTC()

	@Bean
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

	private fun corsSource(webOrigin: String) = UrlBasedCorsConfigurationSource().apply {
		registerCorsConfiguration(
			"/**",
			CorsConfiguration().apply {
				allowedOrigins = listOf(webOrigin)
				allowedMethods = listOf("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
				allowedHeaders = listOf("Authorization", "Content-Type")
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
