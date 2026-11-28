package com.unwrap.grep.features.account.api

import java.util.UUID

/** 살아 있는 AI 도구 연결 하나와 그 주인. */
data class ConnectionPrincipal(val connectionId: UUID, val userId: UUID)

/**
 * account가 mcp 모듈에 공개하는 포트(ADR-BCK-004 결정 2·5). `/mcp` 요청마다 연결 토큰을 확인한다.
 * 끊긴 연결은 다음 요청부터 거부한다(ACC-002 규칙 6).
 */
interface ConnectionAccess {
	/** 끊기지 않았고 만료 전인 접근 토큰이면 그 연결. 아니면 null. */
	fun authenticate(accessToken: String): ConnectionPrincipal?

	/** `연결` 목록의 `읽음 <날짜>`(ACC-002 규칙 7). */
	fun markRead(connectionId: UUID)
}
