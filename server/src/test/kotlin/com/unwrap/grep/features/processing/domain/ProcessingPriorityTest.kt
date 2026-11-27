package com.unwrap.grep.features.processing.domain

import com.unwrap.grep.features.archive.api.ItemOriginals
import com.unwrap.grep.features.archive.api.ProcessingQueue
import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.processing.testing.FakeLinkFetcher
import com.unwrap.grep.features.processing.testing.FakeProcessingConfiguration
import com.unwrap.grep.features.processing.testing.FakeSummarizer
import com.jayway.jsonpath.JsonPath
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import tools.jackson.module.kotlin.jacksonObjectMapper
import java.time.Clock
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.fail

/**
 * 가져온 자료의 낮은 우선순위 처리(ADR-BCK-017, #127 후속). 직접 저장한 자료를 먼저 처리하고,
 * 가져온 자료는 하루 한도에서 직접 저장 몫을 남기고 멈춘다. 근거: COM-005 하루 한도, user-flow 10절.
 */
@Import(FakeProcessingConfiguration::class)
class ProcessingPriorityTest : ArchiveApiTestSupport() {

	@Autowired lateinit var queue: ProcessingQueue
	@Autowired lateinit var originals: ItemOriginals
	@Autowired lateinit var fetcher: FakeLinkFetcher
	@Autowired lateinit var documents: DocumentText
	@Autowired lateinit var summarizer: FakeSummarizer
	@Autowired lateinit var clock: Clock

	private val summary = SummaryResult.Summary("한 줄 요약", "넘길 요약입니다.", listOf("결제"), null)

	@BeforeTest
	fun clearQueue() {
		jdbc.sql("UPDATE item_jobs SET status = 'done' WHERE status IN ('queued', 'running')").update()
		summarizer.respond = { summary }
		fetcher.respond = { FetchResult.Fetched("<title>제목</title><p>본문</p>".toByteArray(), "text/html", "utf-8", false) }
	}

	private fun worker(dailyLimit: Int, reserve: Int) =
		ProcessingWorker(queue, originals, fetcher, documents, summarizer, clock, ProcessingLimits(dailyLimit, reserve))

	private fun importLinks(token: String, count: Int) {
		val html = (1..count).joinToString("\n") { """<DT><A HREF="https://example.com/import/$it">가져온 $it</A>""" }
		val started = mockMvc.post("/imports") {
			header("Authorization", "Bearer $token")
			contentType = MediaType.APPLICATION_JSON
			content = jacksonObjectMapper().writeValueAsString(mapOf("html" to html))
		}.andReturn().response.contentAsString
		val id = JsonPath.read<String>(started, "$.id")
		repeat(100) {
			val body = mockMvc.get("/imports/{id}", id) { header("Authorization", "Bearer $token") }.andReturn().response.contentAsString
			if (JsonPath.read<String>(body, "$.state") == "finished") return
			Thread.sleep(50)
		}
		fail("import did not finish")
	}

	private fun statuses(token: String): Map<Long, String> =
		jdbc.sql("SELECT number, status FROM items WHERE user_id = :userId ORDER BY number")
			.param("userId", userIdOf(token))
			.query { rs, _ -> rs.getLong("number") to rs.getString("status") }
			.list().toMap()

	private fun priorities(token: String): Map<Long, Int> =
		jdbc.sql("SELECT i.number, j.priority FROM item_jobs j JOIN items i ON i.id = j.item_id WHERE i.user_id = :userId")
			.param("userId", userIdOf(token))
			.query { rs, _ -> rs.getLong("number") to rs.getInt("priority") }
			.list().toMap()

	@Test
	fun `가져온자료와직접저장한자료가함께있을때_워커가집으면_직접저장한자료를먼저처리하는지`() {
		// given
		val token = newUser()
		importLinks(token, 2)
		saveItem(token, """{"kind":"text","text":"직접 저장한 글"}""").andExpect { status { isCreated() } }

		// when
		worker(dailyLimit = 50, reserve = 10).runOnce()

		// then
		assertEquals(mapOf(1L to "received", 2L to "received", 3L to "ready"), statuses(token))
	}

	@Test
	fun `한도가남았을때_가져온자료는몫을남기고멈추는지`() {
		// given
		val token = newUser()
		importLinks(token, 5)
		val worker = worker(dailyLimit = 5, reserve = 2)

		// when
		while (worker.runOnce()) Unit
		saveItem(token, """{"kind":"text","text":"몫으로 처리할 글"}""").andExpect { status { isCreated() } }
		worker.runOnce()

		// then
		val after = statuses(token)
		assertEquals(3, (1L..5L).count { after[it] == "ready" })
		assertEquals(2, (1L..5L).count { after[it] == "received" })
		assertEquals("ready", after[6L])
	}

	@Test
	fun `한도가0일때_가져온자료도제한없이처리하는지`() {
		// given
		val token = newUser()
		importLinks(token, 4)
		val worker = worker(dailyLimit = 0, reserve = 10)

		// when
		while (worker.runOnce()) Unit

		// then
		assertEquals(List(4) { "ready" }, statuses(token).values.toList())
	}

	@Test
	fun `가져온자료를열면_작업이보통우선순위로올라가는지`() {
		// given
		val token = newUser()
		importLinks(token, 3)

		// when
		mockMvc.get("/items/{number}", 1) { header("Authorization", "Bearer $token") }.andExpect { status { isOk() } }
		mockMvc.post("/handoff") {
			header("Authorization", "Bearer $token")
			contentType = MediaType.APPLICATION_JSON
			content = """{"numbers":[2]}"""
		}.andExpect { status { isOk() } }

		// then
		assertEquals(mapOf(1L to 0, 2L to 0, 3L to 1), priorities(token))
	}
}
