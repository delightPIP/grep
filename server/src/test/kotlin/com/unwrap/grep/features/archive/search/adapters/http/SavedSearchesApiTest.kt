package com.unwrap.grep.features.archive.search.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.archive.testing.SearchRow
import com.unwrap.grep.features.archive.testing.insertSearchRow
import org.hamcrest.Matchers.contains
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.put
import kotlin.test.Test

/** 찾아두기(ARC-012)와 찾기 응답의 isSavedSearch(규칙 9). 근거: ARC-012 규칙 2·3·5·6·7, 값(1~40자), COM-006. */
class SavedSearchesApiTest : ArchiveApiTestSupport() {

	private fun save(token: String, query: String) = mockMvc.put("/saved-searches") {
		header("Authorization", "Bearer $token")
		contentType = MediaType.APPLICATION_JSON
		content = """{"query":"$query"}"""
	}

	private fun list(token: String) = mockMvc.get("/saved-searches") { header("Authorization", "Bearer $token") }

	private fun remove(token: String, query: String) = mockMvc.delete("/saved-searches") {
		header("Authorization", "Bearer $token")
		param("query", query)
	}

	private fun search(token: String, vararg params: Pair<String, String>) = mockMvc.get("/items/search") {
		header("Authorization", "Bearer $token")
		params.forEach { (name, value) -> param(name, value) }
	}

	private fun newUserWith(vararg rows: SearchRow): String {
		val token = newUser()
		val userId = userIdOf(token)
		rows.forEach { jdbc.insertSearchRow(userId, it) }
		return token
	}

	private fun row(number: Long, searchText: String, tags: List<String> = emptyList(), inTrash: Boolean = false) =
		SearchRow(number = number, kind = "link", title = "자료 $number", searchText = searchText, tags = tags, inTrash = inTrash)

	@Test
	fun `처음찾아둘때_찾아두면_201과공백정리한검색어와지금건수를주는지`() {
		// given
		val token = newUserWith(row(1, "텀블러 캠페인"), row(2, "텀블러"), row(3, "텀블러 캠페인", inTrash = true))

		// when
		val result = save(token, "  텀블러   캠페인 ")

		// then
		result.andExpect {
			status { isCreated() }
			jsonPath("$.query") { value("텀블러 캠페인") }
			jsonPath("$.count") { value(1) }
		}
	}

	@Test
	fun `공백만다른같은검색어일때_찾아두면_200이고하나만남는지`() {
		// given
		val token = newUser()
		save(token, "겨울 굿즈").andExpect { status { isCreated() } }

		// when
		val result = save(token, " 겨울  굿즈")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.query") { value("겨울 굿즈") }
			jsonPath("$.count") { value(0) }
		}
		list(token).andExpect { jsonPath("$.searches.length()") { value(1) } }
	}

	@Test
	fun `낱말차례가다를때_찾아두면_다른검색어로새로만드는지`() {
		// given
		val token = newUser()
		save(token, "겨울 굿즈").andExpect { status { isCreated() } }

		// when
		val result = save(token, "굿즈 겨울")

		// then
		result.andExpect { status { isCreated() } }
	}

	@Test
	fun `비었거나40자를넘거나샵뒤가빌때_찾아두면_400invalid_request인지`() {
		// given
		val token = newUser()

		// when
		val results = listOf(save(token, "   "), save(token, "가".repeat(41)), save(token, "텀블러 #"))

		// then
		results.forEach { result ->
			result.andExpect {
				status { isBadRequest() }
				jsonPath("$.code") { value("invalid_request") }
			}
		}
		list(token).andExpect { jsonPath("$.searches.length()") { value(0) } }
	}

	@Test
	fun `찾아둔뒤자료가늘었을때_목록을부르면_최신순으로0건까지지금다시센건수를주는지`() {
		// given
		val token = newUserWith(row(1, "텀블러", tags = listOf("결제")))
		save(token, "텀블러").andExpect { status { isCreated() } }
		save(token, "#결제 텀블러").andExpect { status { isCreated() } }
		save(token, "없는말").andExpect { status { isCreated() } }
		jdbc.insertSearchRow(userIdOf(token), row(2, "텀블러"))

		// when
		val result = list(token)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.searches[*].query") { value(contains("없는말", "#결제 텀블러", "텀블러")) }
			jsonPath("$.searches[*].count") { value(contains(0, 1, 2)) }
		}
	}

	@Test
	fun `찾아둔것을지울때_지우면_204이고다시지우면404인지`() {
		// given
		val token = newUserWith(row(1, "텀블러"))
		save(token, "텀블러").andExpect { status { isCreated() } }

		// when
		val result = remove(token, " 텀블러 ")

		// then
		result.andExpect { status { isNoContent() } }
		list(token).andExpect { jsonPath("$.searches.length()") { value(0) } }
		remove(token, "텀블러").andExpect {
			status { isNotFound() }
			jsonPath("$.code") { value("not_found") }
		}
		search(token, "q" to "텀블러").andExpect { jsonPath("$.total") { value(1) } }
	}

	@Test
	fun `같은검색어를찾아뒀을때_찾으면_isSavedSearch가true이고다른검색어나남의것은false인지`() {
		// given
		val token = newUserWith(row(1, "텀블러 캠페인", tags = listOf("결제")))
		save(token, "#결제 텀블러  캠페인").andExpect { status { isCreated() } }

		// when
		val same = search(token, "q" to "텀블러 캠페인", "tag" to "결제")
		val otherOrder = search(token, "q" to "캠페인 텀블러", "tag" to "결제")
		val othersUser = search(newUserWith(row(1, "텀블러 캠페인")), "q" to "텀블러 캠페인", "tag" to "결제")

		// then
		same.andExpect { jsonPath("$.isSavedSearch") { value(true) } }
		otherOrder.andExpect { jsonPath("$.isSavedSearch") { value(false) } }
		othersUser.andExpect { jsonPath("$.isSavedSearch") { value(false) } }
	}
}
