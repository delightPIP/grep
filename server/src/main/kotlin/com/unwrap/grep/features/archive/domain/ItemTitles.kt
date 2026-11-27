package com.unwrap.grep.features.archive.domain

/** 저장 때 붙이는 제목(openapi `ItemSummary.title`). */
object ItemTitles {
	/** 붙여 넣은 글 제목 길이(PO 결정, 04-po-decision-questions 질문 6). */
	const val TEXT_TITLE_MAX_CHARS = 24

	/**
	 * 첫 줄, 24자를 넘으면 앞 24자. 앞쪽 빈 줄은 건너뛰고 줄 앞뒤 공백은 지운다.
	 * 글자 수는 코드 포인트로 세어 이모지를 반으로 자르지 않는다.
	 */
	fun forText(text: String): String {
		val firstLine = text.lineSequence().map { it.trim() }.firstOrNull { it.isNotEmpty() }.orEmpty()
		val codePoints = firstLine.codePointCount(0, firstLine.length)
		if (codePoints <= TEXT_TITLE_MAX_CHARS) return firstLine
		return firstLine.substring(0, firstLine.offsetByCodePoints(0, TEXT_TITLE_MAX_CHARS))
	}
}
