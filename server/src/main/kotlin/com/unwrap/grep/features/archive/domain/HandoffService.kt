package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import org.springframework.stereotype.Service
import java.time.Clock
import java.util.UUID

/**
 * POST /handoff와 AI 도구 연결(MCP)이 같이 쓰는 입구. 고른 순서대로, 같은 번호는 처음 것만 쓴다(ARC-001 값).
 * 번호 하나라도 없거나 휴지통에 있거나 남의 것이면 아무것도 만들지 않고 `not_found`로 답한다(ARC-001 규칙 10, COM-006 규칙 6).
 */
@Service
class HandoffService(private val sources: HandoffSourceRepository, private val clock: Clock) {

	fun compose(userId: UUID, numbers: List<Long>): Handoff {
		val ordered = numbers.distinct()
		val found = sources.findActiveForHandoff(userId, ordered).associateBy { it.number }
		val missing = ordered.filterNot { it in found }
		if (missing.isNotEmpty()) throw ApiProblem(ApiErrorCode.NOT_FOUND, numbers = missing)
		return HandoffComposer.compose(ordered.map { found.getValue(it) }, clock.instant())
	}
}
