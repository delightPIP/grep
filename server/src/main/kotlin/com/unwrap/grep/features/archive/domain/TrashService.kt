package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionTemplate
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.UUID

/** 번호와 보이는 제목. openapi `ItemRefList`의 한 줄. */
data class ItemRef(val number: Long, val title: String)

/** 휴지통 목록의 위치. 지운 시각 최신순, 같은 시각이면 번호 큰 순. */
data class TrashCursor(val trashedAt: Instant, val number: Long)

data class TrashedItem(val item: StoredItem, val trashedAt: Instant)

data class TrashEntry(val item: StoredItem, val trashedAt: Instant, val daysLeft: Int)

data class TrashPage(val entries: List<TrashEntry>, val total: Long, val next: TrashCursor?)

interface TrashRepository {
	/** [numbers] 중 [inTrash] 상태인 내 자료. 순서는 정하지 않는다. 트랜잭션 안에서 부르면 행을 잠근다. */
	fun findRefsForUpdate(userId: UUID, numbers: Collection<Long>, inTrash: Boolean): List<ItemRef>

	/** [trashedAt]이 null이면 휴지통에서 꺼낸다. */
	fun setTrashedAt(userId: UUID, numbers: Collection<Long>, trashedAt: Instant?)

	/** 휴지통 자료를 [TrashCursor] 순서로 [limit]건. [after]가 있으면 그 뒤부터. */
	fun findTrashed(userId: UUID, after: TrashCursor?, limit: Int): List<TrashedItem>

	fun countTrashed(userId: UUID): Long

	/** 그 사용자의 휴지통 자료를 영구 삭제하고, 지운 자료의 파일 원본 경로(링크·글은 null)를 준다. */
	fun deleteTrashed(userId: UUID): List<String?>

	/** 모든 사용자의 자료 중 [boundary] 전에 휴지통에 들어간 것을 영구 삭제한다. 원본 경로를 준다. */
	fun deleteTrashedBefore(boundary: Instant): List<String?>
}

/**
 * 휴지통(ARC-008). 같은 번호는 처음 것만 쓴다(ARC-001 값).
 * 번호 하나라도 맞지 않으면 아무것도 바꾸지 않고 `not_found`(ARC-001 규칙 10). 남의 자료는 없는 번호와 같다(COM-006).
 */
@Service
class TrashService(
	private val trash: TrashRepository,
	private val storage: ObjectStorage,
	private val transaction: TransactionTemplate,
	private val clock: Clock,
) {

	/** `버리기`(규칙 1). */
	fun moveToTrash(userId: UUID, numbers: List<Long>): List<ItemRef> = change(userId, numbers, fromTrash = false)

	/** `되살리기`(규칙 4). 번호는 그대로다. */
	fun restore(userId: UUID, numbers: List<Long>): List<ItemRef> = change(userId, numbers, fromTrash = true)

	/** `휴지통`(규칙 5·10). 한 건 더 읽어 다음 쪽이 있는지 안다. */
	fun list(userId: UUID, after: TrashCursor?, limit: Int): TrashPage {
		val rows = trash.findTrashed(userId, after, limit + 1)
		val page = rows.take(limit)
		val today = LocalDate.ofInstant(clock.instant(), KOREA)
		return TrashPage(
			entries = page.map { TrashEntry(it.item, it.trashedAt, daysLeft(it.trashedAt, today)) },
			total = trash.countTrashed(userId),
			next = if (rows.size > limit) page.last().let { TrashCursor(it.trashedAt, it.item.number) } else null,
		)
	}

	/** `휴지통 비우기`(규칙 6). 영구 삭제한 건수를 준다. 번호는 다시 쓰지 않는다(규칙 9). */
	fun empty(userId: UUID): Int {
		val objectPaths = transaction.execute { trash.deleteTrashed(userId) }!!
		deleteOriginals(objectPaths)
		return objectPaths.size
	}

	/**
	 * 휴지통에 들어간 지 30일이 지난 자료를 영구 삭제한다(규칙 7). 지운 건수를 준다.
	 * 지운 날(한국 날짜)이 0일째이고 30일째까지 남긴다. 31일째 00시(한국 시간) 전에 지운 것이 대상이다.
	 */
	fun purgeExpired(): Int {
		val today = LocalDate.ofInstant(clock.instant(), KOREA)
		val boundary = today.minusDays(KEEP_DAYS).atStartOfDay(KOREA).toInstant()
		val objectPaths = transaction.execute { trash.deleteTrashedBefore(boundary) }!!
		deleteOriginals(objectPaths)
		return objectPaths.size
	}

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

	/**
	 * 행은 이미 지웠으므로 원본 하나를 못 지워도 다음 원본으로 넘어간다.
	 * shortcut: 못 지운 원본은 로그로만 남는다. 고아 원본을 훑는 작업은 실제 사용자를 받을 때 만든다.
	 */
	private fun deleteOriginals(objectPaths: List<String?>) {
		objectPaths.filterNotNull().forEach { path ->
			runCatching { storage.delete(path) }.onFailure { log.warn("휴지통 원본 삭제 실패: {}", path, it) }
		}
	}

	/** 30일째(ARC-008 값)까지 되살릴 수 있다. 지운 날이 30일 남음, 30일째가 0일 남음. */
	private fun daysLeft(trashedAt: Instant, today: LocalDate): Int {
		val elapsed = ChronoUnit.DAYS.between(LocalDate.ofInstant(trashedAt, KOREA), today)
		return (KEEP_DAYS - elapsed).coerceAtLeast(0).toInt()
	}

	private companion object {
		const val KEEP_DAYS = 30L
		val KOREA: ZoneId = ZoneId.of("Asia/Seoul")
		val log = LoggerFactory.getLogger(TrashService::class.java)
	}
}
