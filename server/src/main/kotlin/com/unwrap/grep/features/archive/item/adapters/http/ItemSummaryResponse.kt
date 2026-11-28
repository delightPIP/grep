package com.unwrap.grep.features.archive.item.adapters.http

import com.unwrap.grep.features.archive.search.domain.MatchedIn
import com.unwrap.grep.features.archive.item.domain.StoredItem
import java.time.Instant

/**
 * openapi `ItemSummary`. 필드 12개를 null이어도 모두 키로 넣는다(코어 ItemsAPI.swift가 이 모양으로 읽는다).
 * 내부 id는 싣지 않고 번호로만 가리킨다(ARC-001).
 */
data class ItemSummaryResponse(
	val number: Long,
	val kind: String,
	val title: String,
	val source: String?,
	val status: String,
	val blockedReason: String?,
	val listSummary: String?,
	val summarySource: String?,
	val partialNote: String?,
	val tags: List<String>,
	val matchedIn: String?,
	val savedAt: Instant,
) {
	companion object {
		/** 직접 고친 요약이 AI 요약보다 앞선다(ARC-004 규칙 5). 찾기가 아니면 matchedIn은 null. */
		fun of(item: StoredItem, matchedIn: MatchedIn? = null) = ItemSummaryResponse(
			number = item.number,
			kind = item.kind.value,
			title = item.title,
			source = item.source,
			status = item.status.value,
			blockedReason = item.blockedReason,
			listSummary = item.userSummary ?: item.listSummary,
			summarySource = when {
				item.userSummary != null -> "user"
				item.listSummary != null -> "ai"
				else -> null
			},
			partialNote = item.partialNote,
			tags = item.tags,
			matchedIn = matchedIn?.value,
			savedAt = item.savedAt,
		)
	}
}
