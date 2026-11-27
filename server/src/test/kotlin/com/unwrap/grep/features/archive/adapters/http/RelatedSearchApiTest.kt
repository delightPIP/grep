package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.api.EmbeddingQueue
import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.archive.testing.FakeEmbedder
import com.unwrap.grep.features.archive.testing.SearchRow
import com.unwrap.grep.features.archive.testing.insertSearchRow
import com.unwrap.grep.features.processing.domain.EmbeddingWorker
import org.hamcrest.Matchers.contains
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.test.web.servlet.get
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/** 뜻이 가까운 찾기(F15). 근거: ADR-BCK-016 결정 1~4, openapi SearchPage.related, ARC-008, COM-006. */
class RelatedSearchApiTest : ArchiveApiTestSupport() {

	@Autowired
	lateinit var embedder: FakeEmbedder

	@Autowired
	lateinit var worker: EmbeddingWorker

	@Autowired
	lateinit var queue: EmbeddingQueue

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

	private fun row(number: Long, text: String, inTrash: Boolean = false) =
		SearchRow(number = number, kind = "link", title = text, searchText = text, inTrash = inTrash)

	/** 집을 자료가 없을 때까지 임베딩한다. 다른 테스트 자료는 가짜 벡터가 없어 한 시간 미뤄진다. */
	private fun embedAll() {
		while (worker.runOnce()) Unit
	}

	private fun embeddingOf(token: String, number: Long): String? =
		jdbc.sql("SELECT CAST(embedding AS text) FROM items WHERE user_id = :userId AND number = :number")
			.param("userId", userIdOf(token)).param("number", number).query(String::class.java).optional().orElse(null)

	@Test
	fun `글자로는0건이고뜻이가까운자료가있을때_찾으면_휴지통과먼자료를빼고related로주는지`() {
		// given
		embedder.vectors["텀블러 반값 행사"] = FakeEmbedder.axis(0)
		embedder.vectors["결제 위젯 비교"] = FakeEmbedder.axis(1)
		embedder.vectors["버린 텀블러 할인"] = FakeEmbedder.axis(0)
		embedder.vectors["컵할인"] = FakeEmbedder.axis(0)
		val token = newUserWith(row(1, "텀블러 반값 행사"), row(2, "결제 위젯 비교"), row(3, "버린 텀블러 할인"))
		embedAll()
		moveToTrash(token, 3)

		// when
		val result = search(token, "q" to "컵할인")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.total") { value(0) }
			jsonPath("$.related[*].number") { value(contains(1)) }
		}
	}

	@Test
	fun `기간을준찾기일때_0건이면_그기간안의자료만related로주는지`() {
		// given
		embedder.vectors["작년 텀블러 기획"] = FakeEmbedder.axis(5)
		embedder.vectors["기간텀블러"] = FakeEmbedder.axis(5)
		val token = newUserWith(row(1, "작년 텀블러 기획"))
		embedAll()
		val tomorrow = Instant.now().plus(1, ChronoUnit.DAYS).toString()

		// when
		val inRange = search(token, "q" to "기간텀블러")
		val outOfRange = search(token, "q" to "기간텀블러", "from" to tomorrow)

		// then
		inRange.andExpect { jsonPath("$.related[*].number") { value(contains(1)) } }
		outOfRange.andExpect { jsonPath("$.related.length()") { value(0) } }
	}

	@Test
	fun `글자로찾은결과가있을때_찾으면_related가비었고검색어임베딩을부르지않는지`() {
		// given
		embedder.vectors["회의록 정리"] = FakeEmbedder.axis(2)
		val token = newUserWith(row(1, "회의록 정리"))
		embedAll()
		embedder.calls.clear()

		// when
		val result = search(token, "q" to "회의록")

		// then
		result.andExpect {
			jsonPath("$.total") { value(1) }
			jsonPath("$.related.length()") { value(0) }
		}
		assertEquals(emptyList(), embedder.calls)
	}

	@Test
	fun `검색어임베딩을못받을때_찾으면_오류없이related가비었는지`() {
		// given
		val token = newUser()

		// when
		val result = search(token, "q" to "벡터없는검색어")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.related.length()") { value(0) }
		}
	}

	@Test
	fun `임베딩을못받은자료일때_워커가부르면_한시간안에는다시집지않는지`() {
		// given
		val token = newUserWith(row(1, "가짜 벡터 없는 자료"))

		// when
		embedAll()
		embedder.vectors["가짜 벡터 없는 자료"] = FakeEmbedder.axis(3)
		embedAll()

		// then
		assertNull(embeddingOf(token, 1))
	}

	@Test
	fun `그날임베딩한도에닿은사용자일때_집으면_그사용자자료는집지않는지`() {
		// given
		embedder.vectors["한도 자료 하나"] = FakeEmbedder.axis(4)
		embedder.vectors["한도 자료 둘"] = FakeEmbedder.axis(4)
		val token = newUserWith(row(1, "한도 자료 하나"), row(2, "한도 자료 둘"))
		val dayStart = Instant.now().minus(1, ChronoUnit.HOURS)
		embedAll()
		jdbc.sql("UPDATE items SET embedding = NULL, embedding_attempted_at = NULL WHERE user_id = :userId AND number = 2")
			.param("userId", userIdOf(token)).update()

		// when
		val claimed = generateSequence { queue.claimNext(dayStart, 1) }.take(1000).toList()

		// then
		assertNotNull(embeddingOf(token, 1))
		assertEquals(emptyList(), claimed.filter { it.userId == userIdOf(token) })
	}
}
