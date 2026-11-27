package com.unwrap.grep.features.archive.domain

import kotlin.test.Test
import kotlin.test.assertEquals

/** 브라우저 북마크 내보내기(Netscape 형식) 읽기. 근거: openapi ImportRequest, F8. */
class BookmarkHtmlTest {

	@Test
	fun `폴더가섞인북마크파일일때_읽으면_파일차례대로주소와제목을주는지`() {
		// given
		val html = """
			<!DOCTYPE NETSCAPE-Bookmark-file-1>
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
			<TITLE>Bookmarks</TITLE>
			<DL><p>
			    <DT><H3>캠페인</H3>
			    <DL><p>
			        <DT><A HREF="https://example.com/a?utm_source=x" ADD_DATE="1700000000">결제 위젯 &amp; 비교</A>
			    </DL><p>
			    <DT><A HREF="https://example.com/b">  </A>
			    <DT><A HREF="javascript:alert(1)">북마클릿</A>
			</DL><p>
		""".trimIndent()

		// when
		val links = BookmarkHtml.parse(html)

		// then
		assertEquals(
			listOf(
				Bookmark("https://example.com/a?utm_source=x", "결제 위젯 & 비교"),
				Bookmark("https://example.com/b", null),
				Bookmark("javascript:alert(1)", "북마클릿"),
			),
			links,
		)
	}
}
