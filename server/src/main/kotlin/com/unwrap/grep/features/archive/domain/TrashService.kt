package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionTemplate
import java.time.Clock
import java.time.Instant
import java.util.UUID

/** 번호와 보이는 제목. openapi `ItemRefList`의 한 줄. */
data class ItemRef(val number: Long, val title: String)

interface TrashRepository {
	/** [numbers] 중 [inTrash] 상태인 내 자료. 순서는 정하지 않는다. 트랜잭션 안에서 부르면 행을 잠근다. */
	fun findRefsForUpdate(userId: UUID, numbers: Collection<Long>, inTrash: Boolean): List<ItemRef>

	/** [trashedAt]이 null이면 휴지통에서 꺼낸다. */
	fun setTrashedAt(userId: UUID, numbers: Collection<Long>, trashedAt: Instant?)
}

/**
 * `버리기`(ARC-008 규칙 1)와 `되살리기`(규칙 4). 같은 번호는 처음 것만 쓴다(ARC-001 값).
 * 번호 하나라도 맞지 않으면 아무것도 바꾸지 않고 `not_found`(ARC-001 규칙 10). 남의 자료는 없는 번호와 같다(COM-006).
 */
@Service
class TrashService(
	private val trash: TrashRepository,
	private val transaction: TransactionTemplate,
	private val clock: Clock,
) {

	fun moveToTrash(userId: UUID, numbers: List<Long>): List<ItemRef> = change(userId, numbers, fromTrash = false)

	fun restore(userId: UUID, numbers: List<Long>): List<ItemRef> = change(userId, numbers, fromTrash = true)

	private fun change(userId: UUID, numbers: List<Long>, fromTrash: Boolean): List<ItemRef> {
		val ordered = numbers.distinct()
		return transaction.execute {
			val found = trash.findRefsForUpdate(userId, ordered, inTrash = fromTrash).associateBy { it.number }
			val missing = ordered.filterNot { it in found }
			if (missing.isNotEmpty()) throw ApiProblem(ApiErrorCode.NOT_FOUND, numbers = missing)
			trash.setTrashedAt(userId, ordered, if (fromTrash) null else clock.instant())
			ordered.map { found.getValue(it) }
		}!!
	}
}
