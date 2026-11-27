package com.unwrap.grep.features.archive.adapters.http

import com.jayway.jsonpath.JsonPath
import com.unwrap.grep.features.archive.domain.TrashService
import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.archive.testing.SearchRow
import com.unwrap.grep.features.archive.testing.insertSearchRow
import org.hamcrest.Matchers.contains
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * 휴지통 API와 30일 삭제 작업. 근거: ARC-008 규칙 1·2·4~10, ARC-001 규칙 6·10, COM-001 규칙 7, COM-006.
 */
class TrashApiTest : ArchiveApiTestSupport() {

	@Autowired
	lateinit var trashService: TrashService

	private val pdf = "%PDF-1.7\n본문".toByteArray()

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

	private fun listTrash(token: String, vararg params: Pair<String, String>) = mockMvc.get("/items/trash") {
		header("Authorization", "Bearer $token")
		params.forEach { (name, value) -> param(name, value) }
	}

	private fun emptyTrash(token: String) = mockMvc.delete("/items/trash") { header("Authorization", "Bearer $token") }

	/** 휴지통에 [daysAgo]일 전에 넣은 것으로 만든다. */
	private fun trashedDaysAgo(token: String, number: Long, daysAgo: Int) {
		jdbc.sql("UPDATE items SET deleted_at = now() - make_interval(days => :days) WHERE user_id = :userId AND number = :number")
			.param("days", daysAgo).param("userId", userIdOf(token)).param("number", number).update()
	}

	/** PDF 한 건을 저장하고 원본 경로를 준다. */
	private fun savePdf(token: String, bytes: ByteArray = pdf): String {
		val uploadId = upload(token, "a.pdf", bytes)
		saveItem(token, """{"kind":"file","uploadId":"$uploadId"}""").andExpect { status { isCreated() } }
		return objectPathOf(uploadId)
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

	@Test
	fun `휴지통자료가여럿일때_휴지통을부르면_지운날최신순으로남은날과전체건수를주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		trashedDaysAgo(token, 1, daysAgo = 3)
		trashedDaysAgo(token, 3, daysAgo = 10)
		trash(token, """{"numbers":[2]}""").andExpect { status { isOk() } }

		// when
		val result = listTrash(token)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.total") { value(3) }
			jsonPath("$.items[*].item.number") { value(contains(2, 1, 3)) }
			jsonPath("$.items[*].daysLeft") { value(contains(30, 27, 20)) }
			jsonPath("$.items[0].trashedAt") { exists() }
			jsonPath("$.nextCursor") { hasJsonPath(); isEmpty() }
		}
	}

	@Test
	fun `휴지통이한쪽보다많을때_커서로이어부르면_겹치지않고다음자료를주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		trash(token, """{"numbers":[1,2,3]}""").andExpect { status { isOk() } }

		// when
		val first = listTrash(token, "limit" to "2").andReturn().response.contentAsString
		val cursor = JsonPath.read<String>(first, "$.nextCursor")
		val second = listTrash(token, "limit" to "2", "cursor" to cursor)

		// then
		assertEquals(listOf(3, 2), JsonPath.read<List<Int>>(first, "$.items[*].item.number"))
		second.andExpect {
			jsonPath("$.items[*].item.number") { value(contains(1)) }
			jsonPath("$.nextCursor") { hasJsonPath(); isEmpty() }
		}
	}

	@Test
	fun `커서가틀렸을때_휴지통을부르면_400invalid_request인지`() {
		// given
		val token = newUser()

		// when
		val statuses = listOf("abc", "1_0", "1", "x_2").map { listTrash(token, "cursor" to it).andReturn().response.status }

		// then
		assertEquals(listOf(400, 400, 400, 400), statuses)
	}

	@Test
	fun `휴지통을비웠을때_건수를주고원본까지지우고번호를다시쓰지않는지`() {
		// given
		val token = newUser()
		saveLinks(token, 1)
		val objectPath = savePdf(token)
		trash(token, """{"numbers":[1,2]}""").andExpect { status { isOk() } }

		// when
		val result = emptyTrash(token)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.count") { value(2) }
		}
		assertEquals(0, countItems(token))
		assertFalse(storage.exists(objectPath))
		saveLink(token, "https://example.com/after-empty").andExpect { jsonPath("$.item.number") { value(3) } }
	}

	@Test
	fun `다른사용자휴지통이있을때_비우면_내휴지통만지우는지`() {
		// given
		val other = newUser()
		saveLinks(other, 1)
		trash(other, """{"numbers":[1]}""").andExpect { status { isOk() } }
		val token = newUser()

		// when
		val result = emptyTrash(token)

		// then
		result.andExpect { jsonPath("$.count") { value(0) } }
		assertEquals(1, countItems(other))
	}

	@Test
	fun `서른하루지났을때_삭제작업이돌면_원본까지지우는지`() {
		// given
		val token = newUser()
		val expiredPath = savePdf(token, "%PDF-1.7\n31일".toByteArray())
		val keptPath = savePdf(token, "%PDF-1.7\n30일".toByteArray())
		saveLinks(token, 1)
		trashedDaysAgo(token, 1, daysAgo = 31)
		trashedDaysAgo(token, 2, daysAgo = 29)

		// when
		trashService.purgeExpired()

		// then
		assertFalse(storage.exists(expiredPath))
		assertTrue(storage.exists(keptPath))
		listTrash(token).andExpect { jsonPath("$.items[*].item.number") { value(contains(2)) } }
		listItems(token).andExpect { jsonPath("$.items[*].number") { value(contains(3)) } }
	}

	@Test
	fun `휴지통자료와같은링크를저장하면_휴지통에있다고알리는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/again").andExpect { status { isCreated() } }
		trash(token, """{"numbers":[1]}""").andExpect { status { isOk() } }

		// when
		val result = saveLink(token, "https://example.com/again")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.result") { value("inTrash") }
			jsonPath("$.item.number") { value(1) }
		}
		assertEquals(1, countItems(token))
	}

	@Test
	fun `휴지통자료와같은파일을저장하면_휴지통에있다고알리고새원본을지우는지`() {
		// given
		val token = newUser()
		savePdf(token)
		trash(token, """{"numbers":[1]}""").andExpect { status { isOk() } }
		val uploadId = upload(token, "b.pdf", pdf)
		val newPath = objectPathOf(uploadId)

		// when
		val result = saveItem(token, """{"kind":"file","uploadId":"$uploadId"}""")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.result") { value("inTrash") }
			jsonPath("$.item.number") { value(1) }
		}
		assertFalse(storage.exists(newPath))
	}
}
