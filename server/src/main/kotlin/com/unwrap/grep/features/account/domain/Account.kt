package com.unwrap.grep.features.account.domain

import java.time.Duration
import java.time.Instant
import java.util.UUID

/** 로그인 방식(ACC-001 값). claimValue는 Supabase 토큰 app_metadata.provider 값이다. */
enum class AuthProvider(val claimValue: String) {
	GOOGLE("google"),
	GITHUB("github");

	companion object {
		fun fromClaim(value: String?): AuthProvider? = entries.firstOrNull { it.claimValue == value }
	}
}

/** 검증된 접근 토큰에서 읽은 사용자 확인 정보. 사용자 ID는 여기서만 나온다(COM-006 규칙 1). */
data class TokenIdentity(val provider: AuthProvider, val externalId: String, val sessionId: UUID)

/** 계정은 (로그인 방식, 외부 계정 ID) 한 쌍이다(ACC-001 규칙 4). */
data class Account(val userId: UUID, val provider: AuthProvider)

data class SessionRecord(val userId: UUID, val startedAt: Instant, val lastSeenAt: Instant)

/** ACC-001 값: 미사용 30일, 최대 90일. 경계값(정확히 30일·90일)은 유지한다. */
object SessionPolicy {
	val IDLE_LIMIT: Duration = Duration.ofDays(30)
	val MAX_LIFETIME: Duration = Duration.ofDays(90)

	fun isExpired(startedAt: Instant, lastSeenAt: Instant, now: Instant): Boolean =
		Duration.between(lastSeenAt, now) > IDLE_LIMIT || Duration.between(startedAt, now) > MAX_LIFETIME
}

sealed interface AuthResult {
	data class Active(val account: Account) : AuthResult
	data object SessionExpired : AuthResult
	data object Rejected : AuthResult
}

interface UserRepository {
	fun findOrCreate(provider: AuthProvider, externalId: String): Account
}

interface SessionRepository {
	/** 처음 보는 세션이면 now로 시작한다. 이미 있으면 그대로 돌려준다. */
	fun findOrStart(sessionId: UUID, userId: UUID, now: Instant): SessionRecord

	fun touch(sessionId: UUID, now: Instant)
}
