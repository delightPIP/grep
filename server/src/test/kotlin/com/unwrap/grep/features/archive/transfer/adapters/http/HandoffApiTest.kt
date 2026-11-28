package com.unwrap.grep.features.archive.transfer.adapters.http

import com.jayway.jsonpath.JsonPath
import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import org.hamcrest.Matchers.contains
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.post
import kotlin.test.Test
import kotlin.test.assertEquals

/** POST /handoff(createHandoff). 근거: handoff-format 2·3절, ARC-001 규칙 10, ARC-004, COM-006 규칙 6, 05 H-03. */
class HandoffApiTest : ArchiveApiTestSupport() {

	private fun handoff(token: String, body: String) = mockMvc.post("/handoff") {
		header("Authorization", "Bearer $token")
		contentType = MediaType.APPLICATION_JSON
		content = body
	}

	private fun setHandoffSummary(token: String, number: Long, summary: String) {
		jdbc.sql(
			"UPDATE items SET status = 'ready', handoff_summary = :summary WHERE user_id = :userId AND number = :number",
		).param("summary", summary).param("userId", userIdOf(token)).param("number", number).update()
	}

	@Test
	fun `처리중자료가섞였을때_넘기면_기다리지않고고른순서대로요약없음이유를쓰는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		setHandoffSummary(token, 3, "셋째 자료 요약.")

		// when
		val result = handoff(token, """{"numbers":[3,1,3]}""")

		// then
		val body = result.andExpect {
			status { isOk() }
			jsonPath("$.items[*].number") { value(contains(3, 1)) }
			jsonPath("$.missingSummaryCount") { value(1) }
		}.andReturn().response.contentAsString
		val text = JsonPath.read<String>(body, "$.text")
		val lines = text.lines()
		assertEquals("[자료 1] https://example.com/item/3", lines[3])
		assertEquals("- AI 요약: 셋째 자료 요약.", lines[6])
		assertEquals("- AI 요약: (요약 없음: 아직 만드는 중)", lines[11])
		assertEquals(text.codePointCount(0, text.length), JsonPath.read<Int>(body, "$.charCount"))
	}

	@Test
	fun `없는번호나휴지통번호가하나라도있을때_넘기면_404not_found와그번호들을주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 2)
		moveToTrash(token, 2)

		// when
		val result = handoff(token, """{"numbers":[1,2,9]}""")

		// then
		result.andExpect {
			status { isNotFound() }
			jsonPath("$.code") { value("not_found") }
			jsonPath("$.numbers") { value(contains(2, 9)) }
		}
	}

	@Test
	fun `남의자료에만있는번호일때_넘기면_없는번호와같은본문을주는지`() {
		// given
		val owner = newUser()
		saveLinks(owner, 1)

		// when
		val othersNumber = handoff(newUser(), """{"numbers":[1]}""").andReturn().response
		val neverIssued = handoff(newUser(), """{"numbers":[1]}""").andReturn().response

		// then
		assertEquals(404, othersNumber.status)
		assertEquals(neverIssued.contentAsString, othersNumber.contentAsString)
	}

	@Test
	fun `numbers가없거나비었거나양의정수가아닐때_넘기면_400invalid_request인지`() {
		// given
		val token = newUser()
		val invalid = listOf("""{}""", """{"numbers":[]}""", """{"numbers":[0]}""", """{"numbers":[1,null]}""", """{"numbers":["a"]}""")

		// when
		val responses = invalid.map { handoff(token, it).andReturn().response }

		// then
		responses.forEach { response ->
			assertEquals(400, response.status)
			assertEquals(true, response.contentAsString.contains("invalid_request"))
		}
	}
}
