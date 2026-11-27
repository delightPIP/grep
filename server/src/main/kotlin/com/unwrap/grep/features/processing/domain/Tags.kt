package com.unwrap.grep.features.processing.domain

/** ARC-002 값 표: 자료당 최대 5개, 하나 1~20자, `#`·띄어쓰기 없음, 영문 소문자. */
object Tags {
	const val MAX_COUNT = 5
	const val MAX_CHARS = 20
	private val SPACES = Regex("\\s+")

	/** 20자를 넘는 태그는 버리고, 겹치면 하나만, 앞 5개만 둔다. 글자 수는 코드 포인트로 센다. */
	fun normalize(raw: List<String>): List<String> = raw
		.map { it.replace("#", "").replace(SPACES, "").lowercase() }
		.filter { it.isNotEmpty() && it.codePointCount(0, it.length) <= MAX_CHARS }
		.distinct()
		.take(MAX_COUNT)
}
