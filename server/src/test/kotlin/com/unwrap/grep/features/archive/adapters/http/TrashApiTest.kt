package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.archive.testing.SearchRow
import com.unwrap.grep.features.archive.testing.insertSearchRow
import org.hamcrest.Matchers.contains
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import kotlin.test.Test
import kotlin.test.assertEquals

/** POST /items/trash(trashItems), POST /items/restore(restoreItems). 근거: ARC-008 규칙 1·2·4, ARC-001 규칙 10, COM-006. */
class TrashApiTest : ArchiveApiTestSupport() {

	private fun postNumbers(path: String, token: String, body: String) = mockMvc.post(path) {
		header("Authorization", "Bearer $token")
		contentType = MediaType.APPLICATION_JSON
		content = body
	}

	private fun trash(token: String, body: String) = postNumbers("/items/trash", token, body)

	private fun restore(token: String, body: String) = postNumbers("/items/restore", token, body)

	private fun search(token: String, q: String) = mockMvc.get("/items/search") {
		header("Authorization", "Bearer $token")
		param("q", q)
	}

	private fun deletedCount(token: String): Int =
		jdbc.sql("SELECT count(*) FROM items WHERE user_id = :userId AND deleted_at IS NOT NULL")
			.param("userId", userIdOf(token)).query(Int::class.java).single()

	/** 찾기 색인이 있는 자료 [count]건. 번호 1부터, 모두 "텀블러"로 찾힌다. */
	private fun newUserWithSearchable(count: Int): String {
		val token = newUser()
		val userId = userIdOf(token)
		(1..count.toLong()).forEach {
			jdbc.insertSearchRow(userId, SearchRow(number = it, kind = "link", title = "자료 $it", searchText = "텀블러 $it"))
		}
		return token
	}

	@Test
	fun `버렸을때_최근을부르면_그자료가빠지는지`() {
		// given
		val token = newUser()
		saveLinks(token, 5)

		// when
		val result = trash(token, """{"numbers":[5]}""")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.items[*].number") { value(contains(5)) }
			jsonPath("$.items[0].title") { exists() }
		}
		listItems(token).andExpect { jsonPath("$.items[*].number") { value(contains(4, 3, 2, 1)) } }
	}

	@Test
	fun `버렸을때_찾기번호조회넘기기를부르면_그자료가빠지는지`() {
		// given
		val token = newUserWithSearchable(3)

		// when
		trash(token, """{"numbers":[2]}""").andExpect { status { isOk() } }

		// then
		search(token, "텀블러").andExpect {
			jsonPath("$.total") { value(2) }
			jsonPath("$.items[*].number") { value(contains(3, 1)) }
		}
		getStatuses(token, "2").andExpect { jsonPath("$.missing") { value(contains(2)) } }
		postNumbers("/handoff", token, """{"numbers":[2]}""").andExpect {
			status { isNotFound() }
			jsonPath("$.numbers") { value(contains(2)) }
		}
	}

	@Test
	fun `되살렸을때_같은번호로돌아오는지`() {
		// given
		val token = newUserWithSearchable(5)
		trash(token, """{"numbers":[5,3]}""").andExpect { status { isOk() } }

		// when
		val result = restore(token, """{"numbers":[3,5]}""")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.items[*].number") { value(contains(3, 5)) }
		}
		listItems(token).andExpect { jsonPath("$.items[*].number") { value(contains(5, 4, 3, 2, 1)) } }
		search(token, "텀블러").andExpect { jsonPath("$.total") { value(5) } }
		postNumbers("/handoff", token, """{"numbers":[5]}""").andExpect { status { isOk() } }
	}

	@Test
	fun `없는번호나이미버린번호가섞였을때_버리면_아무것도옮기지않고not_found인지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		trash(token, """{"numbers":[2]}""").andExpect { status { isOk() } }

		// when
		val result = trash(token, """{"numbers":[1,2,9]}""")

		// then
		result.andExpect {
			status { isNotFound() }
			jsonPath("$.code") { value("not_found") }
			jsonPath("$.numbers") { value(contains(2, 9)) }
		}
		assertEquals(1, deletedCount(token))
	}

	@Test
	fun `휴지통에없는번호가섞였을때_되살리면_아무것도되살리지않고not_found인지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		trash(token, """{"numbers":[1]}""").andExpect { status { isOk() } }

		// when
		val result = restore(token, """{"numbers":[1,3]}""")

		// then
		result.andExpect {
			status { isNotFound() }
			jsonPath("$.numbers") { value(contains(3)) }
		}
		assertEquals(1, deletedCount(token))
	}

	@Test
	fun `남의자료번호일때_버리면_없는번호와같은본문을주고옮기지않는지`() {
		// given
		val owner = newUser()
		saveLinks(owner, 1)

		// when
		val othersNumber = trash(newUser(), """{"numbers":[1]}""").andReturn().response
		val neverIssued = trash(newUser(), """{"numbers":[1]}""").andReturn().response

		// then
		assertEquals(404, othersNumber.status)
		assertEquals(neverIssued.contentAsString, othersNumber.contentAsString)
		assertEquals(0, deletedCount(owner))
	}

	@Test
	fun `같은번호를두번쓸때_버리면_한번만옮기는지`() {
		// given
		val token = newUser()
		saveLinks(token, 2)

		// when
		val result = trash(token, """{"numbers":[1,1]}""")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.items[*].number") { value(contains(1)) }
		}
	}

	@Test
	fun `번호가비었거나0이하일때_버리면_400invalid_request인지`() {
		// given
		val token = newUser()
		val bodies = listOf("""{"numbers":[]}""", """{"numbers":[0]}""", "{}")

		// when
		val statuses = bodies.map { trash(token, it).andReturn().response }

		// then
		statuses.forEach { assertEquals(400, it.status) }
	}
}
