package com.unwrap.grep.features.processing.domain

import java.net.InetAddress
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** 열지 않는 주소(ARC-006), 태그 값(ARC-002), HTML 글 꺼내기. */
class ProcessingPureTest {

	@Test
	fun `사설루프백링크로컬CGNAT주소일때_검사하면_막고공인주소는통과시키는지`() {
		// given
		val blocked = listOf("127.0.0.1", "10.1.2.3", "172.16.0.1", "192.168.0.1", "169.254.169.254", "100.64.0.1", "0.0.0.0", "::1", "fd00::1", "fe80::1")
		val allowed = listOf("93.184.216.34", "8.8.8.8", "2606:4700::1111")

		// when
		val blockedResults = blocked.map { AddressGuard.isPublic(InetAddress.getByName(it)) }
		val allowedResults = allowed.map { AddressGuard.isPublic(InetAddress.getByName(it)) }

		// then
		assertTrue(blockedResults.none { it }, "blocked: ${blocked.zip(blockedResults)}")
		assertTrue(allowedResults.all { it })
	}

	@Test
	fun `http가아니거나아이디비밀번호가든주소일때_검사하면_막는지`() {
		// given
		val uris = listOf("ftp://example.com/a", "file:///etc/passwd", "https://user:pw@example.com/", "https:///nohost")

		// when
		val results = uris.map { AddressGuard.isAllowedUri(URI(it)) }

		// then
		assertTrue(results.none { it })
		assertTrue(AddressGuard.isAllowedUri(URI("https://example.com/a?b=1")))
	}

	@Test
	fun `모델이태그를규칙밖으로줄때_정리하면_샵과띄어쓰기를빼고20자넘는것을버리고5개만두는지`() {
		// given
		val raw = listOf("#결제", "Payment Widget", "결제", "가".repeat(21), "UI", "토스", "온보딩", "여섯째")

		// when
		val tags = Tags.normalize(raw)

		// then
		assertEquals(listOf("결제", "paymentwidget", "ui", "토스", "온보딩"), tags)
	}

	@Test
	fun `스크립트와엔티티가든HTML일때_꺼내면_og제목과읽을글만남기는지`() {
		// given
		val html = """
			<html><head><title>대체 제목</title><meta property="og:title" content="겨울 음료 &amp; 트렌드">
			<style>.a{color:red}</style><script>alert('x')</script></head>
			<body><h1>머리말</h1><p>첫 문단 &lt;강조&gt;</p><!-- 숨김 --><p>둘째&nbsp;문단 &#44228;</p></body></html>
		""".trimIndent()

		// when
		val page = HtmlText.parse(html)

		// then
		assertEquals("겨울 음료 & 트렌드", page.title)
		assertEquals("머리말\n첫 문단 <강조>\n둘째 문단 계", page.text)
		assertFalse("alert" in page.text)
	}
}
