package com.unwrap.grep.features.archive.adapters.http

import com.jayway.jsonpath.JsonPath
import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.archive.testing.SearchRow
import com.unwrap.grep.features.archive.testing.insertSearchRow
import org.hamcrest.Matchers.contains
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.patch
import org.springframework.test.web.servlet.post
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** PATCH /items/{number}(reviseItem). 근거: commands 3절, ARC-002 규칙 2·3·5, ARC-004, ARC-001 규칙 10, COM-006. */
class ReviseItemApiTest : ArchiveApiTestSupport() {

	private fun revise(token: String, number: String, body: String) = mockMvc.patch("/items/$number") {
		header("Authorization", "Bearer $token")
		contentType = MediaType.APPLICATION_JSON
		content = body
	}

	private fun newUserWithItem(tags: List<String> = listOf("결제", "Widget", "토스")): String {
		val token = newUser()
		jdbc.insertSearchRow(
			userIdOf(token),
			SearchRow(number = 1, kind = "link", title = "원래 제목", searchText = "원래 제목 결제", tags = tags, listSummary = "AI 한 줄"),
		)
		return token
	}

	private fun removedTags(token: String): List<String> =
		jdbc.sql("SELECT array_to_string(removed_tags, ',') FROM items WHERE user_id = :userId AND number = 1")
			.param("userId", userIdOf(token)).query(String::class.java).single().split(',').filter { it.isNotEmpty() }

	@Test
	fun `제목과요약을고쳤을때_고치면_고친값과요약출처user를주는지`() {
		// given
		val token = newUserWithItem()

		// when
		val result = revise(token, "1", """{"title":" 새 제목 ","summary":"내가 쓴 요약"}""")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.number") { value(1) }
			jsonPath("$.title") { value("새 제목") }
			jsonPath("$.listSummary") { value("내가 쓴 요약") }
			jsonPath("$.summarySource") { value("user") }
		}
		listItems(token).andExpect { jsonPath("$.items[0].title") { value("새 제목") } }
	}

	@Test
	fun `요약을고쳤을때_넘기면_요약직접고침으로나가는지`() {
		// given
		val token = newUserWithItem()
		revise(token, "1", """{"summary":"내가 쓴 요약"}""").andExpect { status { isOk() } }

		// when
		val body = mockMvc.post("/handoff") {
			header("Authorization", "Bearer $token")
			contentType = MediaType.APPLICATION_JSON
			content = """{"numbers":[1]}"""
		}.andReturn().response.contentAsString

		// then
		assertTrue(JsonPath.read<String>(body, "$.text").contains("- 요약(직접 고침): 내가 쓴 요약"))
	}

	@Test
	fun `태그를지웠을때_고치면_대소문자상관없이그태그만빠지고지운태그를기록하는지`() {
		// given
		val token = newUserWithItem()

		// when
		val result = revise(token, "1", """{"removeTags":["#widget","없는태그"]}""")

		// then
		result.andExpect { jsonPath("$.tags") { value(contains("결제", "토스")) } }
		assertEquals(setOf("widget", "없는태그"), removedTags(token).toSet())
		mockMvc.get("/items/search") {
			header("Authorization", "Bearer $token")
			param("tag", "widget")
		}.andExpect { jsonPath("$.total") { value(0) } }
	}

	@Test
	fun `고친제목으로찾을때_찾으면_그자료가나오는지`() {
		// given
		val token = newUserWithItem()
		revise(token, "1", """{"title":"포트원 정리"}""").andExpect { status { isOk() } }

		// when
		val result = mockMvc.get("/items/search") {
			header("Authorization", "Bearer $token")
			param("q", "포트원")
		}

		// then
		result.andExpect { jsonPath("$.items[*].number") { value(contains(1)) } }
	}

	@Test
	fun `휴지통이나없는번호나남의자료일때_고치면_404not_found인지`() {
		// given
		val token = newUserWithItem()
		moveToTrash(token, 1)
		val other = newUserWithItem()

		// when
		val trashed = revise(token, "1", """{"title":"x"}""").andReturn().response
		val missing = revise(other, "9", """{"title":"x"}""").andReturn().response
		val others = revise(newUser(), "1", """{"title":"x"}""").andReturn().response

		// then
		assertEquals(listOf(404, 404, 404), listOf(trashed.status, missing.status, others.status))
		assertTrue(trashed.contentAsString.contains("not_found"))
	}

	@Test
	fun `바꿀값이없거나비었을때_고치면_400invalid_request인지`() {
		// given
		val token = newUserWithItem()
		val bodies = listOf("{}", """{"title":"  "}""", """{"summary":""}""", """{"removeTags":[]}""", """{"removeTags":["#"]}""")

		// when
		val statuses = bodies.map { revise(token, "1", it).andReturn().response.status } +
			revise(token, "0", """{"title":"x"}""").andReturn().response.status

		// then
		assertEquals(List(6) { 400 }, statuses)
	}
}
