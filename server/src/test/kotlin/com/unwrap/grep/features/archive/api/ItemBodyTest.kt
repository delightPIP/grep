package com.unwrap.grep.features.archive.api

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** 처리 때 남기는 본문(V5). 근거: openapi ItemDetail.body(앞 2만 자)·bodyLength, ARC-009 읽기 2만 자. */
class ItemBodyTest {

	@Test
	fun `2만자를넘는본문일때_만들면_앞2만자와전체글자수를남기고이모지를가르지않는지`() {
		// given
		val full = "가".repeat(19_999) + "😀" + "나"

		// when
		val body = ItemBody.of(full)!!

		// then
		assertEquals(20_001, body.length)
		assertEquals(20_000, body.text.codePointCount(0, body.text.length))
		assertEquals(true, body.text.endsWith("😀"))
	}

	@Test
	fun `공백뿐인본문일때_만들면_없는것으로보는지`() {
		// given
		val full = "  \n "

		// when
		val body = ItemBody.of(full)

		// then
		assertNull(body)
	}
}
