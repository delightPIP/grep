package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionTemplate
import java.util.UUID

/**
 * 묶음(ARC-003). 같은 번호는 처음 것만 쓴다(ARC-001 값). 남의 묶음·자료는 없는 것과 같다(COM-006).
 * 없는 묶음은 이름 규칙과 상관없이 `not_found`다. 이름 판정은 새로 만들 수 있는 넣기에서만 한다.
 */
@Service
class BundleService(
	private val bundles: BundleRepository,
	private val items: ItemRepository,
	private val transaction: TransactionTemplate,
) {

	fun list(userId: UUID): List<BundleSummary> = bundles.list(userId)

	/** 번호 큰 순(규칙 5). 한 건 더 읽어 다음 쪽이 있는지 안다. */
	fun view(userId: UUID, name: String, beforeNumber: Long?, limit: Int): BundlePage {
		val bundle = require(userId, name)
		val rows = bundles.findVisible(bundle.id, beforeNumber, limit + 1)
		val page = rows.take(limit)
		return BundlePage(
			name = bundle.name,
			total = bundles.countVisible(bundle.id),
			items = page,
			nextBeforeNumber = if (rows.size > limit) page.last().number else null,
		)
	}

	/** 없는 이름이면 만든다(규칙 4). 번호 하나라도 없거나 휴지통이면 아무것도 넣지 않는다(ARC-001 규칙 10). */
	fun add(userId: UUID, name: String, numbers: List<Long>): BundleAddResult {
		BundleName.validate(name)
		val unique = numbers.distinct()
		val found = items.findActiveByNumbers(userId, unique).map { it.number }.toSet()
		val missing = unique.filterNot { it in found }
		if (missing.isNotEmpty()) throw ApiProblem(ApiErrorCode.NOT_FOUND, numbers = missing)
		return transaction.execute {
			val bundle = bundles.createOrTouch(userId, name)
			val inserted = bundles.addItems(userId, bundle.id, unique)
			BundleAddResult(bundle.name, bundles.countVisible(bundle.id), unique.size - inserted)
		}!!
	}

	/** 묶음에서만 뺀다(규칙 7). 묶음에 없는 번호가 하나라도 있으면 아무것도 빼지 않는다. 남은 건수를 준다. */
	fun remove(userId: UUID, name: String, numbers: List<Long>): Long = transaction.execute {
		val bundle = require(userId, name)
		val unique = numbers.distinct()
		val inBundle = bundles.visibleNumbers(bundle.id, unique)
		val missing = unique.filterNot { it in inBundle }
		if (missing.isNotEmpty()) throw ApiProblem(ApiErrorCode.NOT_IN_BUNDLE, numbers = missing)
		bundles.removeItems(userId, bundle.id, unique)
		bundles.touch(bundle.id)
		bundles.countVisible(bundle.id)
	}!!

	fun delete(userId: UUID, name: String) {
		if (!bundles.delete(userId, name)) throw ApiProblem(ApiErrorCode.NOT_FOUND)
	}

	internal fun require(userId: UUID, name: String): BundleRef =
		bundles.find(userId, name) ?: throw ApiProblem(ApiErrorCode.NOT_FOUND)
}
