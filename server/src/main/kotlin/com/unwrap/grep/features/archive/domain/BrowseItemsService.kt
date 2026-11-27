package com.unwrap.grep.features.archive.domain

import org.springframework.stereotype.Service
import java.util.UUID

/** 자료 한 쪽. [nextBeforeNumber]가 null이면 다음 쪽이 없다. */
data class ItemPage(val items: List<StoredItem>, val nextBeforeNumber: Long?)

/** 번호로 찾은 결과. [items]는 요청 순서, [missing]은 없거나 휴지통에 있는 번호(ARC-001 규칙 10). */
data class ItemLookup(val items: List<StoredItem>, val missing: List<Long>)

/** 최근 목록과 번호 조회. 휴지통 자료는 빼고(ARC-008), 내 자료만 본다(COM-006). */
@Service
class BrowseItemsService(private val items: ItemRepository) {

	/** 한 건 더 읽어 다음 쪽이 있는지 안다. */
	fun recent(userId: UUID, beforeNumber: Long?, limit: Int): ItemPage {
		val rows = items.findActive(userId, beforeNumber, limit + 1)
		val page = rows.take(limit)
		return ItemPage(page, if (rows.size > limit) page.last().number else null)
	}

	/** 같은 번호를 두 번 써도 한 번으로 본다(ARC-001 값). */
	fun lookup(userId: UUID, numbers: List<Long>): ItemLookup {
		val unique = numbers.distinct()
		val found = items.findActiveByNumbers(userId, unique).associateBy { it.number }
		return ItemLookup(
			items = unique.mapNotNull { found[it] },
			missing = unique.filterNot { it in found },
		)
	}
}
