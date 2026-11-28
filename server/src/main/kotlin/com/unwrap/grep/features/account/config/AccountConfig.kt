package com.unwrap.grep.features.account.config

import com.unwrap.grep.features.account.domain.AccountService
import com.unwrap.grep.features.account.domain.ConnectionRepository
import com.unwrap.grep.features.account.domain.ConnectionService
import com.unwrap.grep.features.account.domain.OAuthClientRepository
import com.unwrap.grep.features.account.domain.OAuthCodeRepository
import com.unwrap.grep.features.account.domain.OAuthService
import com.unwrap.grep.features.account.domain.PendingAuthorizations
import com.unwrap.grep.features.account.domain.SessionRepository
import com.unwrap.grep.features.account.domain.UserRepository
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import java.time.Clock

/** account 도메인 빈. 트랜잭션 경계는 [TransactionalAccountService] 등 하위 클래스가 진다. */
@Configuration(proxyBeanMethods = false)
class AccountConfig {

	@Bean
	fun accountService(users: UserRepository, sessions: SessionRepository, clock: Clock): AccountService =
		TransactionalAccountService(users, sessions, clock)

	@Bean
	fun connectionService(connections: ConnectionRepository, clock: Clock): ConnectionService =
		TransactionalConnectionService(connections, clock)

	@Bean
	fun oAuthService(
		clients: OAuthClientRepository,
		codes: OAuthCodeRepository,
		connections: ConnectionService,
		clock: Clock,
	): OAuthService = TransactionalOAuthService(clients, codes, connections, clock)

	@Bean
	fun pendingAuthorizations(clock: Clock) = PendingAuthorizations(clock)
}
