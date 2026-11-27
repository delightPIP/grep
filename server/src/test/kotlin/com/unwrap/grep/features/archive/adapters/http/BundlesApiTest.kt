package com.unwrap.grep.features.archive.adapters.http

import com.jayway.jsonpath.JsonPath
import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import org.hamcrest.Matchers.contains
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CyclicBarrier
import kotlin.test.Test
import kotlin.test.assertEquals

/** 묶음 API와 `넘기기 <이름>`. 근거: ARC-003, handoff-format 2·5절, ARC-001 규칙 10, COM-006. */
class BundlesApiTest : ArchiveApiTestSupport() {

	private fun post(path: String, token: String, body: String, vararg vars: Any) = mockMvc.post(path, *vars) {
		header("Authorization", "Bearer $token")
		contentType = MediaType.APPLICATION_JSON
		content = body
	}

	private fun add(token: String, name: String, vararg numbers: Long) =
		post("/bundles/{name}/items", token, """{"numbers":${numbers.toList()}}""", name)

	private fun remove(token: String, name: String, vararg numbers: Long) =
		post("/bundles/{name}/items/remove", token, """{"numbers":${numbers.toList()}}""", name)

	private fun view(token: String, name: String, vararg params: Pair<String, String>) = mockMvc.get("/bundles/{name}", name) {
		header("Authorization", "Bearer $token")
		params.forEach { (key, value) -> param(key, value) }
	}

	private fun list(token: String) = mockMvc.get("/bundles") { header("Authorization", "Bearer $token") }

	private fun deleteBundle(token: String, name: String) =
		mockMvc.delete("/bundles/{name}", name) { header("Authorization", "Bearer $token") }

	private fun restore(token: String, number: Long) = post("/items/restore", token, """{"numbers":[$number]}""")

	@Test
	fun `없는이름일때_넣으면_묶음을만들고건수를주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 2)

		// when
		val result = add(token, "결제조사", 1, 2)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.name") { value("결제조사") }
			jsonPath("$.count") { value(2) }
			jsonPath("$.alreadyCount") { value(0) }
		}
	}

	@Test
	fun `대소문자만다른이름으로이미든자료를다시넣을때_넣으면_한번만두고처음표기와이미있음건수를주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		add(token, "Pay", 1, 2).andExpect { status { isOk() } }

		// when
		val result = add(token, "PAY", 2, 3, 3)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.name") { value("Pay") }
			jsonPath("$.count") { value(3) }
			jsonPath("$.alreadyCount") { value(1) }
		}
		list(token).andExpect { jsonPath("$.bundles.length()") { value(1) } }
	}

	@Test
	fun `두기기에서동시에같은자료를새묶음에넣을때_넣으면_묶음하나에한번만있는지`() {
		// given
		val token = newUser()
		saveLinks(token, 1)
		val barrier = CyclicBarrier(2)

		// when
		val statuses = List(2) {
			CompletableFuture.supplyAsync {
				barrier.await()
				add(token, "동시", 1).andReturn().response.status
			}
		}.map { it.join() }

		// then
		assertEquals(listOf(200, 200), statuses)
		view(token, "동시").andExpect { jsonPath("$.total") { value(1) } }
		list(token).andExpect { jsonPath("$.bundles.length()") { value(1) } }
	}

	@Test
	fun `이름규칙에어긋나거나금지이름일때_넣으면_400과reason을주고만들지않는지`() {
		// given
		val token = newUser()
		saveLinks(token, 1)

		// when
		val format = add(token, "가".repeat(21), 1)
		val reserved = add(token, "123", 1)

		// then
		format.andExpect {
			status { isBadRequest() }
			jsonPath("$.code") { value("invalid_bundle_name") }
			jsonPath("$.reason") { value("format") }
		}
		reserved.andExpect {
			status { isBadRequest() }
			jsonPath("$.reason") { value("reserved") }
		}
		list(token).andExpect { jsonPath("$.bundles.length()") { value(0) } }
	}

	@Test
	fun `없는번호나휴지통번호가섞였을때_넣으면_아무것도넣지않고not_found인지`() {
		// given
		val token = newUser()
		saveLinks(token, 2)
		moveToTrash(token, 2)

		// when
		val result = add(token, "조사", 1, 2, 9)

		// then
		result.andExpect {
			status { isNotFound() }
			jsonPath("$.code") { value("not_found") }
			jsonPath("$.numbers") { value(contains(2, 9)) }
		}
		view(token, "조사").andExpect { status { isNotFound() } }
	}

	@Test
	fun `묶음이여럿일때_목록을부르면_최근에바뀐순으로0건묶음도휴지통밖건수로주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		add(token, "첫째", 1, 2).andExpect { status { isOk() } }
		add(token, "둘째", 3).andExpect { status { isOk() } }
		remove(token, "둘째", 3).andExpect { status { isOk() } }
		add(token, "첫째", 3).andExpect { status { isOk() } }
		moveToTrash(token, 1)

		// when
		val result = list(token)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.bundles[*].name") { value(contains("첫째", "둘째")) }
			jsonPath("$.bundles[*].count") { value(contains(2, 0)) }
		}
	}

	@Test
	fun `휴지통에보낸자료가있을때_묶음을보면_빠지고되살리면번호큰순으로돌아오는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		add(token, "모음", 1, 3, 2).andExpect { status { isOk() } }
		moveToTrash(token, 2)

		// when
		val hidden = view(token, "모음")
		restore(token, 2).andExpect { status { isOk() } }
		val back = view(token, "모음")

		// then
		hidden.andExpect {
			status { isOk() }
			jsonPath("$.total") { value(2) }
			jsonPath("$.items[*].number") { value(contains(3, 1)) }
		}
		back.andExpect { jsonPath("$.items[*].number") { value(contains(3, 2, 1)) } }
	}

	@Test
	fun `묶음이한쪽보다클때_커서로이어보면_겹치지않고다음자료를주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		add(token, "쪽", 1, 2, 3).andExpect { status { isOk() } }

		// when
		val first = view(token, "쪽", "limit" to "2").andReturn().response.contentAsString
		val cursor = JsonPath.read<String>(first, "$.nextCursor")
		val second = view(token, "쪽", "limit" to "2", "cursor" to cursor)

		// then
		assertEquals(listOf(3, 2), JsonPath.read<List<Int>>(first, "$.items[*].number"))
		second.andExpect {
			jsonPath("$.items[*].number") { value(contains(1)) }
			jsonPath("$.nextCursor") { value(null as Any?) }
		}
	}

	@Test
	fun `없는묶음이거나남의묶음일때_보면_404not_found인지`() {
		// given
		val owner = newUser()
		saveLinks(owner, 1)
		add(owner, "내것", 1).andExpect { status { isOk() } }

		// when
		val result = view(newUser(), "내것")

		// then
		result.andExpect {
			status { isNotFound() }
			jsonPath("$.code") { value("not_found") }
		}
	}

	@Test
	fun `묶음에없는번호가섞였을때_빼면_아무것도빼지않고not_in_bundle과그번호를주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		add(token, "뺄것", 1, 2).andExpect { status { isOk() } }

		// when
		val result = remove(token, "뺄것", 1, 3)

		// then
		result.andExpect {
			status { isNotFound() }
			jsonPath("$.code") { value("not_in_bundle") }
			jsonPath("$.numbers") { value(contains(3)) }
		}
		view(token, "뺄것").andExpect { jsonPath("$.total") { value(2) } }
	}

	@Test
	fun `모두뺐을때_빼면_자료는남고묶음은0건으로남는지`() {
		// given
		val token = newUser()
		saveLinks(token, 2)
		add(token, "비울것", 1, 2).andExpect { status { isOk() } }

		// when
		val result = remove(token, "비울것", 1, 2)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.count") { value(0) }
		}
		view(token, "비울것").andExpect { jsonPath("$.total") { value(0) } }
		assertEquals(2, countItems(token))
	}

	@Test
	fun `묶음을지웠을때_지우면_204이고자료는남는지`() {
		// given
		val token = newUser()
		saveLinks(token, 2)
		add(token, "지울것", 1, 2).andExpect { status { isOk() } }

		// when
		val result = deleteBundle(token, "지울것")

		// then
		result.andExpect { status { isNoContent() } }
		view(token, "지울것").andExpect { status { isNotFound() } }
		deleteBundle(token, "지울것").andExpect { status { isNotFound() } }
		assertEquals(2, countItems(token))
	}

	@Test
	fun `휴지통자료가든묶음일때_묶음으로넘기면_번호큰순으로남은자료만넘기고빠진건수와여는줄묶음을주는지`() {
		// given
		val token = newUser()
		saveLinks(token, 3)
		add(token, "넘길것", 1, 2, 3).andExpect { status { isOk() } }
		moveToTrash(token, 2)

		// when
		val result = post("/handoff", token, """{"bundle":"넘길것"}""")

		// then
		val body = result.andExpect {
			status { isOk() }
			jsonPath("$.items[*].number") { value(contains(3, 1)) }
			jsonPath("$.bundle") { value("넘길것") }
			jsonPath("$.removedCount") { value(1) }
		}.andReturn().response.contentAsString
		val opening = JsonPath.read<String>(body, "$.text").lines().first()
		assertEquals(true, opening.endsWith(""" 묶음="넘길것">"""), opening)
	}

	@Test
	fun `번호로넘길때_넘기면_bundle은null이고removedCount는0인지`() {
		// given
		val token = newUser()
		saveLinks(token, 1)

		// when
		val result = post("/handoff", token, """{"numbers":[1]}""")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.bundle") { value(null as Any?) }
			jsonPath("$.removedCount") { value(0) }
		}
	}

	@Test
	fun `번호와묶음을같이주거나없는묶음일때_넘기면_400이나404인지`() {
		// given
		val token = newUser()
		saveLinks(token, 1)
		add(token, "있음", 1).andExpect { status { isOk() } }

		// when
		val both = post("/handoff", token, """{"numbers":[1],"bundle":"있음"}""")
		val unknown = post("/handoff", token, """{"bundle":"없음"}""")

		// then
		both.andExpect { jsonPath("$.code") { value("invalid_request") } }
		unknown.andExpect {
			status { isNotFound() }
			jsonPath("$.code") { value("not_found") }
		}
	}
}
