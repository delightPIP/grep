package com.unwrap.grep.features.archive.search.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.archive.testing.SearchRow
import com.unwrap.grep.features.archive.testing.demoSeedRows
import com.unwrap.grep.features.archive.testing.insertSearchRow
import org.hamcrest.Matchers.contains
import org.springframework.test.web.servlet.get
import kotlin.test.Test
import kotlin.test.assertEquals

/** GET /items/search(searchItems). 근거: commands 3절, ARC-002 규칙 5~8, ARC-008, COM-006, demo-seed 2절 5번. */
class SearchItemsApiTest : ArchiveApiTestSupport() {

	private fun search(token: String, vararg params: Pair<String, String>) = mockMvc.get("/items/search") {
		header("Authorization", "Bearer $token")
		params.forEach { (name, value) -> param(name, value) }
	}

	private fun newUserWith(rows: List<SearchRow>): String {
		val token = newUser()
		val userId = userIdOf(token)
		rows.forEach { jdbc.insertSearchRow(userId, it) }
		return token
	}

	private fun row(number: Long, searchText: String, tags: List<String> = emptyList()) =
		SearchRow(number = number, kind = "link", title = "자료 $number", searchText = searchText, tags = tags)

	@Test
	fun `데모시드가있을때_텀블러로찾으면_8건을최근저장순으로주는지`() {
		// given
		val token = newUserWith(demoSeedRows())

		// when
		val result = search(token, "q" to "텀블러")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.total") { value(8) }
			jsonPath("$.items[*].number") { value(contains(32, 30, 28, 25, 23, 21, 16, 7)) }
			jsonPath("$.nextCursor") { hasJsonPath(); isEmpty() }
		}
	}

	@Test
	fun `데모시드가있을때_텀블러캠페인으로찾으면_두낱말이모두있는4건만주는지`() {
		// given
		val token = newUserWith(demoSeedRows())

		// when
		val result = search(token, "q" to "텀블러 캠페인")

		// then
		result.andExpect {
			jsonPath("$.total") { value(4) }
			jsonPath("$.items[*].number") { value(contains(30, 28, 25, 23)) }
		}
	}

	@Test
	fun `맞는자료가12건일때_찾고다음쪽을부르면_10건과전체건수뒤에남은2건을주는지`() {
		// given
		val token = newUserWith((1L..12L).map { row(it, "결제 화면") })
		val first = search(token, "q" to "결제").andReturn().response.contentAsString
		val cursor = Regex("\"nextCursor\":\"([^\"]+)\"").find(first)!!.groupValues[1]

		// when
		val result = search(token, "q" to "결제", "cursor" to cursor)

		// then
		assertEquals(true, first.contains("\"total\":12"))
		assertEquals(10, Regex("\"number\":").findAll(first).count())
		result.andExpect {
			jsonPath("$.total") { value(12) }
			jsonPath("$.items[*].number") { value(contains(2, 1)) }
			jsonPath("$.nextCursor") { hasJsonPath(); isEmpty() }
		}
	}

	@Test
	fun `태그가섞여있을때_태그두개로찾으면_대소문자없이둘다정확히맞는자료만주는지`() {
		// given
		val token = newUserWith(
			listOf(
				row(1, "가", listOf("결제", "ios")),
				row(2, "나", listOf("결제")),
				row(3, "다", listOf("ios")),
				row(4, "라", listOf("결제수단", "ios")),
				row(5, "마"),
			),
		)

		// when
		val result = search(token, "tag" to "결제", "tag" to "IOS")

		// then
		result.andExpect {
			jsonPath("$.total") { value(1) }
			jsonPath("$.items[*].number") { value(contains(1)) }
			jsonPath("$.items[0].matchedIn") { value("tag") }
		}
	}

	@Test
	fun `검색어와태그를함께쓸때_찾으면_둘다맞는자료만주는지`() {
		// given
		val token = newUserWith(
			listOf(
				row(1, "위젯 설계", listOf("결제")),
				row(2, "위젯 설계"),
				row(3, "결제 흐름", listOf("결제")),
			),
		)

		// when
		val result = search(token, "q" to "위젯", "tag" to "결제")

		// then
		result.andExpect {
			jsonPath("$.items[*].number") { value(contains(1)) }
		}
	}

	@Test
	fun `휴지통자료와다른사용자자료가있을때_찾으면_내휴지통밖자료만주는지`() {
		// given
		val token = newUserWith(listOf(row(1, "텀블러"), row(2, "텀블러").copy(inTrash = true), row(3, "머그")))
		newUserWith(listOf(row(1, "텀블러")))

		// when
		val result = search(token, "q" to "텀블러")

		// then
		result.andExpect {
			jsonPath("$.total") { value(1) }
			jsonPath("$.items[*].number") { value(contains(1)) }
		}
	}

	@Test
	fun `일치한곳이다를때_찾으면_matchedIn에제목출처요약태그본문이미지속글자를주는지`() {
		// given
		val token = newUserWith(
			listOf(
				row(1, "온보딩 체크리스트").copy(title = "온보딩 체크리스트"),
				row(2, "notion.so 온보딩").copy(source = "notion.so 온보딩"),
				row(3, "가입 온보딩 요약").copy(listSummary = "가입 온보딩 요약"),
				row(4, "온보딩", listOf("온보딩")),
				SearchRow(5, "text", "회의 메모", "회의 메모 온보딩 순서", textBody = "회의 메모 온보딩 순서"),
				SearchRow(6, "file", "화면.png", "화면.png 온보딩 버튼", fileFormat = "png"),
				SearchRow(7, "file", "안내.pdf", "안내.pdf 온보딩 절차", fileFormat = "pdf"),
			),
		)

		// when
		val result = search(token, "q" to "온보딩")

		// then
		result.andExpect {
			jsonPath("$.items[*].matchedIn") {
				value(contains("body", "imageText", "body", "tag", "summary", "source", "title"))
			}
		}
	}

	@Test
	fun `검색어와태그가없거나계약밖일때_찾으면_400invalid_request인지`() {
		// given
		val token = newUser()
		val invalid = listOf(
			arrayOf<Pair<String, String>>(),
			arrayOf("q" to "   "),
			arrayOf("tag" to ""),
			arrayOf("q" to "결제", "limit" to "51"),
			arrayOf("q" to "결제", "cursor" to "abc"),
		)

		// when
		val responses = invalid.map { search(token, *it).andReturn().response }

		// then
		responses.forEach { response ->
			assertEquals(400, response.status)
			assertEquals(true, response.contentAsString.contains("invalid_request"))
		}
	}
}
