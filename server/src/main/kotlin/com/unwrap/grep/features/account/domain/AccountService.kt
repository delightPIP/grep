package com.unwrap.grep.features.account.domain

import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock

/** 인증된 요청마다 계정을 찾거나 만들고(ACC-001 규칙 3), 세션 만료를 판정한다(규칙 5). */
@Service
class AccountService(
	private val users: UserRepository,
	private val sessions: SessionRepository,
	private val clock: Clock,
) {
	@Transactional
	fun authenticate(identity: TokenIdentity): AuthResult {
		val account = users.findOrCreate(identity.provider, identity.externalId)
		val now = clock.instant()
		val session = sessions.findOrStart(identity.sessionId, account.userId, now)
		if (session.userId != account.userId) return AuthResult.Rejected
		if (SessionPolicy.isExpired(session.startedAt, session.lastSeenAt, now)) return AuthResult.SessionExpired
		sessions.touch(identity.sessionId, now)
		return AuthResult.Active(account)
	}
}
