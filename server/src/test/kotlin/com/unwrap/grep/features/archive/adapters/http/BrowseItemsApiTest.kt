package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import org.hamcrest.Matchers.contains
import kotlin.test.Test
import kotlin.test.assertEquals

/** GET /items(listRecentItems), GET /items/status(getItemStatuses). 근거: ARC-001, ARC-005 규칙 10, ARC-008, COM-006. */
class BrowseItemsApiTest : ArchiveApiTestSupport() {

	@Test
	fun `자료가12건일때_목록을부르면_최신10건을번호내림차순으로주고nextCursor를주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 12)

		// when
		val result = listItems(token)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.items.length()") { value(10) }
			jsonPath("$.items[0].number") { value(12) }
			jsonPath("$.items[9].number") { value(3) }
			jsonPath("$.items[0].matchedIn") { hasJsonPath(); isEmpty() }
			jsonPath("$.nextCursor") { isString() }
		}
	}

	@Test
	fun `앞쪽nextCursor가있을때_그커서로부르면_남은자료를주고nextCursor가null인지`() {
		// given
		val token = newUser()
		saveLinks(token, 12)
		val cursor = Regex("\"nextCursor\":\"([^\"]+)\"")
			.find(listItems(token).andReturn().response.contentAsString)!!.groupValues[1]

		// when
		val result = listItems(token, "cursor" to cursor)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.items[*].number") { value(contains(2, 1)) }
			jsonPath("$.nextCursor") { hasJsonPath(); isEmpty() }
		}
	}

	@Test
	fun `자료가limit와같은수일때_목록을부르면_nextCursor가null인지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)

		// when
		val result = listItems(token, "limit" to "3")

		// then
		result.andExpect {
			jsonPath("$.items.length()") { value(3) }
			jsonPath("$.nextCursor") { hasJsonPath(); isEmpty() }
		}
	}

	@Test
	fun `휴지통자료와다른사용자자료가있을때_목록을부르면_내휴지통밖자료만주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		moveToTrash(token, 2)
		saveLinks(newUser(), 5)

		// when
		val result = listItems(token)

		// then
		result.andExpect {
			jsonPath("$.items[*].number") { value(contains(3, 1)) }
		}
	}

	@Test
	fun `limit나cursor가계약밖일때_목록을부르면_400invalid_request인지`() {
		// given
		val token = newUser()
		val invalid = listOf("limit" to "0", "limit" to "51", "limit" to "abc", "cursor" to "abc", "cursor" to "0")

		// when
		val statuses = invalid.map { listItems(token, it).andReturn().response }

		// then
		statuses.forEach { response ->
			assertEquals(400, response.status)
			assertEquals(true, response.contentAsString.contains("invalid_request"))
		}
	}

	@Test
	fun `없는번호와휴지통번호가섞였을때_번호로찾으면_요청순서대로있는자료와missing을주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		moveToTrash(token, 2)

		// when
		val result = getStatuses(token, "3,9,1,2")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.items[*].number") { value(contains(3, 1)) }
			jsonPath("$.items[0].status") { value("received") }
			jsonPath("$.missing") { value(contains(9, 2)) }
		}
	}

	@Test
	fun `같은번호를두번쓸때_번호로찾으면_한번만주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 1)

		// when
		val result = getStatuses(token, "1,5,1,5")

		// then
		result.andExpect {
			jsonPath("$.items[*].number") { value(contains(1)) }
			jsonPath("$.missing") { value(contains(5)) }
		}
	}

	@Test
	fun `다른사용자의번호일때_번호로찾으면_missing으로주는지`() {
		// given
		val owner = newUser()
		saveLinks(owner, 1)
		val other = newUser()

		// when
		val result = getStatuses(other, "1")

		// then
		result.andExpect {
			jsonPath("$.items") { isEmpty() }
			jsonPath("$.missing") { value(contains(1)) }
		}
	}

	@Test
	fun `numbers가없거나양의정수가아닐때_번호로찾으면_400invalid_request인지`() {
		// given
		val token = newUser()
		val invalid = listOf(null, "", "0", "-1", "1,a", "1,,2")

		// when
		val responses = invalid.map { getStatuses(token, it).andReturn().response }

		// then
		responses.forEach { response ->
			assertEquals(400, response.status)
			assertEquals(true, response.contentAsString.contains("invalid_request"))
		}
	}
}
