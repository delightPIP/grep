package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import java.time.Instant
import java.util.UUID

/** 내 묶음 하나. [name]은 처음 만든 표기(ARC-003 규칙 11). */
data class BundleRef(val id: UUID, val name: String)

/** openapi `BundleSummary`. [count]는 휴지통 밖 자료 수. */
data class BundleSummary(val name: String, val count: Long, val updatedAt: Instant)

/** 묶음 안 자료 한 쪽. [nextBeforeNumber]가 null이면 다음 쪽이 없다. */
data class BundlePage(val name: String, val total: Long, val items: List<StoredItem>, val nextBeforeNumber: Long?)

/** 넣은 뒤 건수와 요청 중 이미 있던 자료 수(`✓ 묶음 <이름>: N건 (이미 있음 M건)`). */
data class BundleAddResult(val name: String, val count: Long, val alreadyCount: Int)

/** bundles·bundle_items(V4). 모든 쿼리는 user_id로 거른다(COM-006). 휴지통 자료는 행을 남기고 보일 때만 뺀다. */
interface BundleRepository {
	/** 영문 대소문자를 가리지 않고 찾는다. */
	fun find(userId: UUID, name: String): BundleRef?

	/** 없으면 만들고 있으면 바뀐 시각만 새로 한다. 동시에 불러도 묶음은 하나다. */
	fun createOrTouch(userId: UUID, name: String): BundleRef

	fun touch(bundleId: UUID)

	/** 휴지통 밖 내 자료 [numbers]를 넣는다. 이미 있는 자료는 건너뛰고, 새로 넣은 수를 준다. */
	fun addItems(userId: UUID, bundleId: UUID, numbers: Collection<Long>): Int

	/** [numbers] 중 묶음에 들어 있고 휴지통 밖인 번호. */
	fun visibleNumbers(bundleId: UUID, numbers: Collection<Long>): Set<Long>

	fun removeItems(userId: UUID, bundleId: UUID, numbers: Collection<Long>)

	fun countVisible(bundleId: UUID): Long

	fun countTrashed(bundleId: UUID): Int

	/** 휴지통 밖 자료를 번호 큰 순으로. [limit]이 null이면 모두. */
	fun findVisible(bundleId: UUID, beforeNumber: Long?, limit: Int?): List<StoredItem>

	/** 최근에 바뀐 순(ARC-003 규칙 3). */
	fun list(userId: UUID): List<BundleSummary>

	/** 지웠으면 true. 자료는 남는다(규칙 8). */
	fun delete(userId: UUID, name: String): Boolean
}

/** 묶음 이름 판정(ARC-003 값). 금지 이름을 먼저 보고, 그다음 글자·길이를 본다. */
object BundleName {
	private const val MAX_LENGTH = 20
	private val ALLOWED = Regex("^[\\p{IsHangul}A-Za-z0-9_-]+$")
	private val DIGITS_ONLY = Regex("^[0-9]+$")
	private val SUBCOMMANDS = setOf("빼기", "지우기")

	fun validate(name: String): String {
		if (name.startsWith("#") || DIGITS_ONLY.matches(name) || name in SUBCOMMANDS) throw invalid("reserved")
		val length = name.codePointCount(0, name.length)
		if (length !in 1..MAX_LENGTH || !ALLOWED.matches(name)) throw invalid("format")
		return name
	}

	private fun invalid(reason: String) = ApiProblem(ApiErrorCode.INVALID_BUNDLE_NAME, reason = reason)
}
