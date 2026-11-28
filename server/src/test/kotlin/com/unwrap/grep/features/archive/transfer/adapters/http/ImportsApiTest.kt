package com.unwrap.grep.features.archive.transfer.adapters.http

import com.jayway.jsonpath.JsonPath
import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import org.hamcrest.Matchers.contains
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import tools.jackson.module.kotlin.jacksonObjectMapper
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.fail

/** 북마크 가져오기(F8, user-flow 10절). 근거: openapi startImport·getImport, COM-001(같은 링크), ADR-BCK-008(처리 미룸), COM-006. */
class ImportsApiTest : ArchiveApiTestSupport() {

	private fun start(token: String, html: String) = mockMvc.post("/imports") {
		header("Authorization", "Bearer $token")
		contentType = MediaType.APPLICATION_JSON
		content = jacksonObjectMapper().writeValueAsString(mapOf("html" to html))
	}

	private fun status(token: String, id: String) = mockMvc.get("/imports/{id}", id) { header("Authorization", "Bearer $token") }

	private fun bookmarks(vararg hrefs: String) =
		hrefs.joinToString("\n", "<DL><p>\n", "\n</DL><p>") { """<DT><A HREF="$it">제목 $it</A>""" }

	/** 뒤에서 도는 가져오기가 끝날 때까지 기다린 뒤 마지막 상태 본문을 준다. */
	private fun awaitFinished(token: String, id: String): String {
		repeat(100) {
			val body = status(token, id).andReturn().response.contentAsString
			if (JsonPath.read<String>(body, "$.state") == "finished") return body
			Thread.sleep(50)
		}
		fail("import $id did not finish")
	}

	private fun startAndAwait(token: String, html: String): String {
		val started = start(token, html).andExpect { status { isAccepted() } }.andReturn().response.contentAsString
		return awaitFinished(token, JsonPath.read(started, "$.id"))
	}

	@Test
	fun `새링크와이미저장한링크와파일안중복과잘못된주소가섞였을때_가져오면_저장건너뜀실패를세고실패주소를주는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/old").andExpect { status { isCreated() } }
		val html = bookmarks(
			"https://example.com/new", "https://example.com/old?utm_source=x", "https://example.com/new", "javascript:alert(1)",
		)

		// when
		val body = startAndAwait(token, html)

		// then
		assertEquals(4, JsonPath.read<Int>(body, "$.total"))
		assertEquals(4, JsonPath.read<Int>(body, "$.done"))
		assertEquals(1, JsonPath.read<Int>(body, "$.saved"))
		assertEquals(2, JsonPath.read<Int>(body, "$.skipped"))
		assertEquals(1, JsonPath.read<Int>(body, "$.failed"))
		assertEquals(0, JsonPath.read<Int>(body, "$.overLimit"))
		assertEquals(listOf("javascript:alert(1)"), JsonPath.read<List<String>>(body, "$.failedUrls"))
		assertEquals(2, countItems(token))
	}

	@Test
	fun `200건을넘는북마크일때_가져오면_앞200건만가져오고넘친수를overLimit로주는지`() {
		// given
		val token = newUser()
		val html = bookmarks(*Array(203) { "https://example.com/n/$it" })

		// when
		val body = startAndAwait(token, html)

		// then
		assertEquals(200, JsonPath.read<Int>(body, "$.total"))
		assertEquals(200, JsonPath.read<Int>(body, "$.saved"))
		assertEquals(3, JsonPath.read<Int>(body, "$.overLimit"))
		assertEquals(200, countItems(token))
	}

	@Test
	fun `가져온자료일때_가져오면_낮은우선순위처리작업을하나씩만들고열어도새로만들지않는지`() {
		// given
		val token = newUser()
		startAndAwait(token, bookmarks("https://example.com/1", "https://example.com/2"))
		listItems(token).andExpect { jsonPath("$.items[*].title") { value(contains("제목 https://example.com/2", "제목 https://example.com/1")) } }

		// when
		mockMvc.get("/items/{number}", 1) { header("Authorization", "Bearer $token") }.andExpect { status { isOk() } }

		// then
		assertEquals(listOf(0, 1), priorities(token))
	}

	private fun priorities(token: String): List<Int> =
		jdbc.sql(
			"SELECT j.priority FROM item_jobs j JOIN items i ON i.id = j.item_id WHERE i.user_id = :userId ORDER BY i.number",
		).param("userId", userIdOf(token)).query { rs, _ -> rs.getInt(1) }.list()

	@Test
	fun `남의가져오기이거나없는id일때_진행을부르면_404인지`() {
		// given
		val owner = newUser()
		val started = start(owner, bookmarks("https://example.com/x")).andReturn().response.contentAsString
		val id = JsonPath.read<String>(started, "$.id")

		// when
		val others = status(newUser(), id)
		val unknown = status(owner, "00000000-0000-0000-0000-000000000000")
		val malformed = status(owner, "nope")

		// then
		others.andExpect { status { isNotFound() } }
		unknown.andExpect { status { isNotFound() } }
		malformed.andExpect { status { isBadRequest() } }
		awaitFinished(owner, id)
	}

	@Test
	fun `html이비었을때_가져오면_400invalid_request인지`() {
		// given
		val token = newUser()

		// when
		val result = start(token, "")

		// then
		result.andExpect {
			status { isBadRequest() }
			jsonPath("$.code") { value("invalid_request") }
		}
	}
}
