package com.unwrap.grep.features.metrics.api

import java.time.Instant
import java.util.UUID

/**
 * metrics가 다른 모듈에 공개하는 포트(ADR-BCK-004 결정 2). 측정 이벤트(PRD 4절, 05 6-5절 D-08).
 * 기록에 실패해도 던지지 않는다. 사용자 동작은 실패로 보이지 않아야 한다.
 */
interface MetricEvents {
	/** 저장 성공(ARC-005 규칙 1) 뒤 한 번. [method]는 자료 종류(`link`·`text`·`file`)다. */
	fun itemSaved(userId: UUID, method: String)

	/** 연결한 AI 도구가 읽기 도구로 자료 하나를 받은 뒤 한 번(05 6-5절). 자료 번호·검색어는 넘기지 않는다. */
	fun connectionRead(userId: UUID, savedAt: Instant)
}
