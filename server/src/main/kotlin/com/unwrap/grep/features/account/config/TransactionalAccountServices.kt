package com.unwrap.grep.features.account.config

import com.unwrap.grep.features.account.domain.AccountService
import com.unwrap.grep.features.account.domain.AuthResult
import com.unwrap.grep.features.account.domain.ConnectionNotice
import com.unwrap.grep.features.account.domain.ConnectionRepository
import com.unwrap.grep.features.account.domain.ConnectionService
import com.unwrap.grep.features.account.domain.ConnectionSummary
import com.unwrap.grep.features.account.domain.IssuedTokens
import com.unwrap.grep.features.account.domain.OAuthClientRepository
import com.unwrap.grep.features.account.domain.OAuthCodeRepository
import com.unwrap.grep.features.account.domain.OAuthError
import com.unwrap.grep.features.account.domain.OAuthService
import com.unwrap.grep.features.account.domain.SessionRepository
import com.unwrap.grep.features.account.domain.TokenIdentity
import com.unwrap.grep.features.account.domain.UserRepository
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.util.UUID

/*
 * 도메인 서비스에 Spring을 들이지 않으려고 트랜잭션 경계를 하위 클래스에 둔다.
 * Spring이 이 클래스들을 CGLIB로 감싸므로 도메인 클래스와 공개 메서드는 모두 open이어야 한다.
 * final 메서드는 프록시가 가로채지 못하고 필드가 빈 프록시 객체에서 돈다.
 */

open class TransactionalAccountService(users: UserRepository, sessions: SessionRepository, clock: Clock) :
	AccountService(users, sessions, clock) {

	@Transactional
	override fun authenticate(identity: TokenIdentity): AuthResult = super.authenticate(identity)
}

open class TransactionalConnectionService(connections: ConnectionRepository, clock: Clock) :
	ConnectionService(connections, clock) {

	@Transactional
	override fun open(userId: UUID, clientId: String): IssuedTokens = super.open(userId, clientId)

	@Transactional
	override fun refresh(refreshToken: String, clientId: String?): IssuedTokens? = super.refresh(refreshToken, clientId)

	@Transactional
	override fun list(userId: UUID): List<ConnectionSummary> = super.list(userId)

	@Transactional
	override fun takeNotices(userId: UUID): List<ConnectionNotice> = super.takeNotices(userId)
}

open class TransactionalOAuthService(
	clients: OAuthClientRepository,
	codes: OAuthCodeRepository,
	connections: ConnectionService,
	clock: Clock,
) : OAuthService(clients, codes, connections, clock) {

	@Transactional(noRollbackFor = [OAuthError::class])
	override fun exchangeCode(code: String?, clientId: String?, redirectUri: String?, codeVerifier: String?): IssuedTokens =
		super.exchangeCode(code, clientId, redirectUri, codeVerifier)
}
