package com.unwrap.grep.features.archive.search.domain

import com.unwrap.grep.features.archive.bundle.domain.ItemFilter
import com.unwrap.grep.features.archive.item.domain.ItemRepository
import com.unwrap.grep.features.archive.item.domain.StoredItem
import java.util.UUID

/** 자료 한 쪽. [nextBeforeNumber]가 null이면 다음 쪽이 없다. [total]은 기간이 있을 때만 그 기간 전체 건수. */
data class ItemPage(val items: List<StoredItem>, val nextBeforeNumber: Long?, val total: Long? = null)

/** 번호로 찾은 결과. [items]는 요청 순서, [missing]은 없거나 휴지통에 있는 번호(ARC-001 규칙 10). */
data class ItemLookup(val items: List<StoredItem>, val missing: List<Long>)

/** 최근 목록, 번호 조회, 찾기. 휴지통 자료는 빼고(ARC-008), 내 자료만 본다(COM-006). */
class BrowseItemsService(
	private val items: ItemRepository,
	private val itemSearch: ItemSearch,
	private val relatedSearch: RelatedSearch,
) {

	/** 한 건 더 읽어 다음 쪽이 있는지 안다. */
	fun recent(
		userId: UUID,
		beforeNumber: Long?,
		limit: Int,
		saved: SavedRange = SavedRange.ANY,
		filter: ItemFilter = ItemFilter.NONE,
	): ItemPage {
		val rows = items.findActive(userId, beforeNumber, limit + 1, saved, filter)
		val page = rows.take(limit)
		val total = if (saved == SavedRange.ANY) null else items.countActive(userId, saved, filter)
		return ItemPage(page, if (rows.size > limit) page.last().number else null, total)
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

	/** 최근 저장 순(commands 3절). 한 건 더 읽어 다음 쪽이 있는지 안다. 0건이면 뜻이 가까운 자료를 보탠다(F15). */
	fun search(userId: UUID, query: SearchQuery, beforeNumber: Long?, limit: Int): SearchPage {
		val rows = itemSearch.find(userId, query, beforeNumber, limit + 1)
		val page = rows.take(limit)
		val total = itemSearch.count(userId, query)
		return SearchPage(
			hits = page,
			total = total,
			nextBeforeNumber = if (rows.size > limit) page.last().item.number else null,
			related = if (total == 0L) relatedSearch.related(userId, query) else emptyList(),
		)
	}
}
