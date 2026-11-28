package com.unwrap.grep.features.archive.item.domain

import kotlin.test.Test
import kotlin.test.assertEquals

class ItemTitlesTest {

	@Test
	fun `글이여러줄일때_제목을만들면_첫줄만쓰는지`() {
		// given
		val text = "회의 메모\r\n둘째 줄"

		// when
		val title = ItemTitles.forText(text)

		// then
		assertEquals("회의 메모", title)
	}

	@Test
	fun `첫줄이24자를넘을때_제목을만들면_앞24자까지만쓰는지`() {
		// given
		val text = "가나다라마바사아자차카타파하가나다라마바사아자차카타파하"

		// when
		val title = ItemTitles.forText(text)

		// then
		assertEquals("가나다라마바사아자차카타파하가나다라마바사아자차", title)
	}

	@Test
	fun `이모지가24자경계에걸렸을때_제목을만들면_글자를반으로자르지않는지`() {
		// given
		val text = "a".repeat(23) + "😀😀"

		// when
		val title = ItemTitles.forText(text)

		// then
		assertEquals("a".repeat(23) + "😀", title)
	}

	@Test
	fun `앞줄이비어있을때_제목을만들면_처음글자가있는줄을쓰는지`() {
		// given
		val text = "\n   \n  본문 시작  \n다음"

		// when
		val title = ItemTitles.forText(text)

		// then
		assertEquals("본문 시작", title)
	}
}
