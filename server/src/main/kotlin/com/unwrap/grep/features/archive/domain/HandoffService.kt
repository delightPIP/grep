package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import org.springframework.stereotype.Service
import java.time.Clock
import java.util.UUID

/**
 * POST /handoff와 AI 도구 연결(MCP)이 같이 쓰는 입구. 고른 순서대로, 같은 번호는 처음 것만 쓴다(ARC-001 값).
 * 가져온 자료를 넘기면 기다리는 처리 작업을 보통 우선순위로 올린다(ADR-BCK-017). 요약은 기다리지 않는다.
 * 번호 하나라도 없거나 휴지통에 있거나 남의 것이면 아무것도 만들지 않고 `not_found`로 답한다(ARC-001 규칙 10, COM-006 규칙 6).
 */
@Service
class HandoffService(
	private val sources: HandoffSourceRepository,
	private val bundles: BundleRepository,
	private val items: ItemRepository,
	private val clock: Clock,
) {

	fun compose(userId: UUID, numbers: List<Long>): Handoff {
		val ordered = numbers.distinct()
		val found = sources.findActiveForHandoff(userId, ordered).associateBy { it.number }
		val missing = ordered.filterNot { it in found }
		if (missing.isNotEmpty()) throw ApiProblem(ApiErrorCode.NOT_FOUND, numbers = missing)
		items.raiseProcessingPriority(userId, ordered)
		return HandoffComposer.compose(ordered.map { found.getValue(it) }, clock.instant())
	}

	/**
	 * `넘기기 <이름>`: 휴지통 밖 자료를 번호 큰 순으로 넘기고, 휴지통으로 빠진 수를 함께 준다(ARC-003 규칙 10).
	 * shortcut: 영구 삭제된 자료는 bundle_items가 CASCADE로 지워져 셀 수 없어 removedCount에 들지 않는다. 정책이 그 수까지 요구하면 삭제 기록 열을 더한다.
	 */
	fun composeBundle(userId: UUID, name: String): Handoff {
		val bundle = bundles.find(userId, name) ?: throw ApiProblem(ApiErrorCode.NOT_FOUND)
		val numbers = bundles.findVisible(bundle.id, beforeNumber = null, limit = null).map { it.number }
		val found = sources.findActiveForHandoff(userId, numbers).associateBy { it.number }
		val ordered = numbers.mapNotNull { found[it] }
		items.raiseProcessingPriority(userId, numbers)
		return HandoffComposer.compose(ordered, clock.instant(), bundle.name, bundles.countTrashed(bundle.id))
	}
}
