package com.unwrap.grep.features.metrics.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.post
import java.time.LocalDate
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

/** item_saved(서버 기록)와 POST /events(recordEvent). 근거: PRD 4절, 05 6-5절 D-08, 08 T-14·6절 개발 답 9, V3 events. */
class EventsApiTest : ArchiveApiTestSupport() {

	private fun postEvent(token: String, body: String) = mockMvc.post("/events") {
		header("Authorization", "Bearer $token")
		contentType = MediaType.APPLICATION_JSON
		content = body
	}

	private fun events(token: String, name: String): List<Map<String, Any?>> =
		jdbc.sql(
			"""
			SELECT method, item_count, array_to_string(days_since_saved, ',') AS days, day_kst FROM events
			WHERE user_id = :userId AND name = :name ORDER BY id
			""".trimIndent(),
		).param("userId", userIdOf(token)).param("name", name).query().listOfRows()

	/** events 표의 칸 이름. 검색어·본문·번호를 담을 칸이 없어야 한다. */
	private fun eventColumns(): List<String> =
		jdbc.sql("SELECT column_name FROM information_schema.columns WHERE table_name = 'events' ORDER BY ordinal_position")
			.query(String::class.java).list().filterNotNull()

	private fun todayKst(): LocalDate = LocalDate.now(ZoneId.of("Asia/Seoul"))

	@Test
	fun `새로저장했을때_저장하면_item_saved를한번남기고같은자료는남기지않는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/event").andExpect { status { isCreated() } }

		// when
		saveLink(token, "https://example.com/event").andExpect { status { isOk() } }
		saveItem(token, """{"kind":"text","text":"메모"}""").andExpect { status { isCreated() } }

		// then
		val rows = events(token, "item_saved")
		assertEquals(listOf("link", "text"), rows.map { it["method"] })
		assertEquals(listOf(1, 1), rows.map { it["item_count"] })
		assertEquals(todayKst(), (rows.first()["day_kst"] as java.sql.Date).toLocalDate())
	}

	@Test
	fun `넘기기복사를보고했을때_기록하면_건수와지난일수만남기는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		jdbc.sql("UPDATE items SET created_at = now() - interval '5 days' WHERE user_id = :userId AND number = 2")
			.param("userId", userIdOf(token)).update()
		moveToTrash(token, 3)

		// when
		val result = postEvent(token, """{"name":"handoff_copied","numbers":[2,1,2,3,99],"method":"pipe"}""")

		// then
		result.andExpect { status { isNoContent() } }
		val row = events(token, "handoff_copied").single()
		assertEquals("pipe", row["method"])
		assertEquals(2, row["item_count"])
		assertEquals("0,5", row["days"])
	}

	@Test
	fun `이벤트속성에_검색어나본문이없는지`() {
		// given
		val token = newUser()
		saveLinks(token, 1)

		// when
		postEvent(token, """{"name":"handoff_copied","numbers":[1],"method":"pick","query":"비밀 검색어","text":"본문"}""")
			.andExpect { status { isNoContent() } }

		// then
		assertEquals(
			listOf("id", "user_id", "name", "method", "item_count", "days_since_saved", "day_kst", "created_at"),
			eventColumns(),
		)
		val stored = events(token, "handoff_copied").single().values.joinToString(" ")
		assertFalse(stored.contains("비밀") || stored.contains("본문"))
	}

	@Test
	fun `이름이나방식이계약밖일때_보내면_400invalid_request인지`() {
		// given
		val token = newUser()
		val bodies = listOf(
			"""{"name":"item_saved","numbers":[1],"method":"pick"}""",
			"""{"name":"handoff_copied","numbers":[1],"method":"copy"}""",
			"""{"name":"handoff_copied","numbers":[],"method":"pick"}""",
			"""{"name":"handoff_copied","numbers":[0],"method":"pick"}""",
		)

		// when
		val statuses = bodies.map { postEvent(token, it).andReturn().response.status }

		// then
		assertEquals(listOf(400, 400, 400, 400), statuses)
		assertEquals(0, events(token, "handoff_copied").size + events(token, "item_saved").size)
	}
}
