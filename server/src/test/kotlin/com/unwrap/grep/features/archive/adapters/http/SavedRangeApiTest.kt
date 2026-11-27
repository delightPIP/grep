package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.archive.testing.SearchRow
import com.unwrap.grep.features.archive.testing.insertSearchRow
import org.hamcrest.Matchers.contains
import org.springframework.test.web.servlet.get
import kotlin.test.Test
import kotlin.test.assertEquals

/** GET /items·/items/search의 `from`·`to`(F22 시점, openapi SavedFrom·SavedTo). 반열린 구간 [from, to). */
class SavedRangeApiTest : ArchiveApiTestSupport() {

	/** 자료 1~4를 한국 시간 2026-11-02(월) 00:00, 11-08(일) 23:59:59, 11-09(월) 00:00, 11-10에 저장한 것으로 둔다. */
	private fun newUserWithWeek(): String {
		val token = newUser()
		val userId = userIdOf(token)
		val savedAt = listOf("2026-11-02T00:00:00+09:00", "2026-11-08T23:59:59+09:00", "2026-11-09T00:00:00+09:00", "2026-11-10T12:00:00+09:00")
		savedAt.forEachIndexed { index, at ->
			val number = index + 1L
			jdbc.insertSearchRow(userId, SearchRow(number = number, kind = "link", title = "자료 $number", searchText = "텀블러"))
			jdbc.sql("UPDATE items SET created_at = CAST(:at AS timestamptz) WHERE user_id = :userId AND number = :number")
				.param("at", at).param("userId", userId).param("number", number).update()
		}
		return token
	}

	private val week = arrayOf("from" to "2026-11-02T00:00:00+09:00", "to" to "2026-11-09T00:00:00+09:00")

	@Test
	fun `한주기간을줬을때_최근을부르면_시작은넣고끝은빼는지`() {
		// given
		val token = newUserWithWeek()

		// when
		val result = listItems(token, *week)

		// then
		result.andExpect { jsonPath("$.items[*].number") { value(contains(2, 1)) } }
	}

	@Test
	fun `기간과검색어를함께줬을때_찾으면_기간안에서만찾고전체건수도기간안인지`() {
		// given
		val token = newUserWithWeek()

		// when
		val result = mockMvc.get("/items/search") {
			header("Authorization", "Bearer $token")
			param("q", "텀블러")
			param("from", "2026-11-08T15:00:00Z")
		}

		// then
		result.andExpect {
			jsonPath("$.total") { value(2) }
			jsonPath("$.items[*].number") { value(contains(4, 3)) }
		}
	}

	@Test
	fun `시각형식이틀렸을때_부르면_400invalid_request인지`() {
		// given
		val token = newUser()

		// when
		val statuses = listOf("from" to "2026-11-02", "to" to "어제", "from" to "2026-11-02T00:00:00")
			.map { listItems(token, it).andReturn().response.status }

		// then
		assertEquals(listOf(400, 400, 400), statuses)
	}
}
