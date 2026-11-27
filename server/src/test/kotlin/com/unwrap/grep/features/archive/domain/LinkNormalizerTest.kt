package com.unwrap.grep.features.archive.domain

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** COM-001 값 표의 규칙별 테스트 벡터. */
class LinkNormalizerTest {

	private fun normalized(raw: String) = LinkNormalizer.normalize(raw)?.value

	@Test
	fun `http와https주소일때_정규화하면_같은값이되는지`() {
		// given
		val http = "http://example.com/a"
		val https = "https://example.com/a"

		// when
		val results = listOf(normalized(http), normalized(https))

		// then
		assertEquals(listOf("https://example.com/a", "https://example.com/a"), results)
	}

	@Test
	fun `http나https가아닌스킴일때_정규화하면_링크로보지않는지`() {
		// given
		val others = listOf("ftp://example.com/a", "mailto:a@example.com", "javascript:alert(1)", "example.com/a", "")

		// when
		val results = others.map { normalized(it) }

		// then
		results.forEach { assertNull(it) }
	}

	@Test
	fun `호스트가대문자이고www가붙었을때_정규화하면_소문자로바꾸고www를지우는지`() {
		// given
		val raw = "https://WWW.Example.COM/Path"

		// when
		val result = LinkNormalizer.normalize(raw)

		// then
		assertEquals("https://example.com/Path", result?.value)
		assertEquals("example.com", result?.host)
	}

	@Test
	fun `www가아닌하위도메인일때_정규화하면_그대로두는지`() {
		// given
		val raw = "https://m.example.com/a"

		// when
		val result = normalized(raw)

		// then
		assertEquals("https://m.example.com/a", result)
	}

	@Test
	fun `경로끝에슬래시가있을때_정규화하면_하나를지우고루트는빈경로로보는지`() {
		// given
		val withSlash = "https://example.com/a/"
		val root = "https://example.com/"
		val bare = "https://example.com"

		// when
		val results = listOf(normalized(withSlash), normalized(root), normalized(bare))

		// then
		assertEquals(listOf("https://example.com/a", "https://example.com", "https://example.com"), results)
	}

	@Test
	fun `샵뒤가있을때_정규화하면_지우되샵슬래시로시작하면남기는지`() {
		// given
		val anchor = "https://example.com/a#section"
		val hashRoute = "https://example.com/app#/inbox/1"

		// when
		val results = listOf(normalized(anchor), normalized(hashRoute))

		// then
		assertEquals(listOf("https://example.com/a", "https://example.com/app#/inbox/1"), results)
	}

	@Test
	fun `쿼리파라미터가섞여있을때_정규화하면_이름순으로정렬하는지`() {
		// given
		val raw = "https://example.com/s?b=2&a=1&c=3"

		// when
		val result = normalized(raw)

		// then
		assertEquals("https://example.com/s?a=1&b=2&c=3", result)
	}

	@Test
	fun `추적용꼬리표가있을때_정규화하면_지우고비면물음표도지우는지`() {
		// given
		val mixed = "https://example.com/a?utm_source=x&id=7&fbclid=1&gclid=2&igsh=3&si=4&ref_src=5&utm_medium=y"
		val onlyTracking = "https://example.com/a?utm_source=x&si=abc"

		// when
		val results = listOf(normalized(mixed), normalized(onlyTracking))

		// then
		assertEquals(listOf("https://example.com/a?id=7", "https://example.com/a"), results)
	}

	@Test
	fun `youtube짧은주소일때_정규화하면_watch주소로바꾸는지`() {
		// given
		val short = "https://youtu.be/dQw4w9WgXcQ?si=abc&t=42"
		val long = "https://www.youtube.com/watch?t=42&v=dQw4w9WgXcQ"

		// when
		val results = listOf(normalized(short), normalized(long))

		// then
		assertEquals("https://youtube.com/watch?t=42&v=dQw4w9WgXcQ", results[0])
		assertEquals(results[0], results[1])
	}

	@Test
	fun `호스트가없거나공백이든주소일때_정규화하면_링크로보지않는지`() {
		// given
		val invalid = listOf("https://", "https:///a", "https://exa mple.com/a")

		// when
		val results = invalid.map { normalized(it) }

		// then
		results.forEach { assertNull(it) }
	}
}
