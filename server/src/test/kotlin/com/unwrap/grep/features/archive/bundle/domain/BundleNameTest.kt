package com.unwrap.grep.features.archive.bundle.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/** 묶음 이름 판정. 근거: ARC-003 값(1~20자, 한글·영문·숫자·`-`·`_`, 숫자만·`#` 시작·`빼기`·`지우기` 금지). */
class BundleNameTest {

	private fun reasonOf(name: String): String? {
		val problem = assertFailsWith<ApiProblem> { BundleName.validate(name) }
		assertEquals(ApiErrorCode.INVALID_BUNDLE_NAME, problem.code)
		return problem.reason
	}

	@Test
	fun `한글영문숫자와하이픈밑줄로20자일때_판정하면_그대로받는지`() {
		// given
		val name = "결제조사_Q4-2026abcdefgh"

		// when
		val result = BundleName.validate(name)

		// then
		assertEquals(20, result.length)
		assertEquals(name, result)
	}

	@Test
	fun `0자이거나21자이거나띄어쓰기나기호가있을때_판정하면_format인지`() {
		// given
		val names = listOf("", "가".repeat(21), "결제 조사", "결제!", "a.b")

		// when
		val reasons = names.map { reasonOf(it) }

		// then
		assertEquals(List(names.size) { "format" }, reasons)
	}

	@Test
	fun `숫자만이거나샵시작이거나빼기지우기일때_판정하면_reserved인지`() {
		// given
		val names = listOf("123", "#태그", "빼기", "지우기")

		// when
		val reasons = names.map { reasonOf(it) }

		// then
		assertEquals(List(names.size) { "reserved" }, reasons)
	}
}
