package com.unwrap.grep.features.archive.api

import java.time.Instant
import java.util.UUID

/** AI 도구 연결(MCP)이 읽은 자료 한 건. [savedAt]은 `connection_read`의 저장 뒤 지난 일수에만 쓴다(D-08). */
data class ConnectionRead(val text: String, val savedAt: Instant)

/**
 * archive가 connection 모듈에 공개하는 읽기 전용 포트(ARC-009, ADR-BCK-015 결정 4).
 * 응답 글은 넘길 글과 같은 함수가 만든다. 휴지통·남의 자료는 나오지 않는다(ARC-008, COM-006).
 */
interface ConnectionReading {
	/** 검색어에 맞는 휴지통 밖 내 자료를 최근 저장 순으로 최대 20건. 낱말이 없으면 null. */
	fun search(userId: UUID, query: String): String?

	/** 자료 하나의 요약과 본문 텍스트. 없거나 휴지통이거나 남의 번호면 null. */
	fun read(userId: UUID, number: Long): ConnectionRead?
}
