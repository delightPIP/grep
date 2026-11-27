package com.unwrap.grep.features.processing.domain

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.processing.testing.FakeLinkFetcher
import com.unwrap.grep.features.processing.testing.FakeProcessingConfiguration
import com.unwrap.grep.features.processing.testing.FakeSummarizer
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.patch
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * 처리 워커 한 바퀴. 가짜 가져오기·요약과 실제 DB로 본다.
 * 근거: ARC-005 규칙 4·5·7, ARC-006, ARC-002, ARC-004 규칙 8, COM-004 규칙 6, COM-005 규칙 3·4, H-06.
 */
@Import(FakeProcessingConfiguration::class)
class ProcessingWorkerTest : ArchiveApiTestSupport() {

	@Autowired
	lateinit var worker: ProcessingWorker

	@Autowired
	lateinit var fetcher: FakeLinkFetcher

	@Autowired
	lateinit var summarizer: FakeSummarizer

	private val summary = SummaryResult.Summary("한 줄 요약", "넘길 요약입니다.", listOf("#결제", "위젯"), null)

	/** 다른 테스트가 남긴 작업을 집지 않게 기다리는 작업을 모두 끝낸다. */
	@BeforeTest
	fun clearQueue() {
		jdbc.sql("UPDATE item_jobs SET status = 'done' WHERE status IN ('queued', 'running')").update()
		summarizer.calls.clear()
		summarizer.respond = { summary }
		fetcher.respond = { FetchResult.Fetched("<title>결제 위젯 비교</title><p>토스와 포트원 본문</p>".toByteArray(), "text/html", "utf-8", false) }
	}

	private fun row(token: String, number: Long = 1): Map<String, Any?> =
		jdbc.sql(
			"""
			SELECT i.status, i.blocked_reason, i.title, i.list_summary, i.handoff_summary, i.partial_note,
			       array_to_string(i.tags, ',') AS tags, i.summary_model, i.summary_prompt_version, i.search_text,
			       j.status AS job_status, j.attempts, j.run_at > now() AS deferred
			FROM items i JOIN item_jobs j ON j.item_id = i.id
			WHERE i.user_id = :userId AND i.number = :number
			""".trimIndent(),
		).param("userId", userIdOf(token)).param("number", number).query().singleRow()

	@Test
	fun `링크를저장했을때_처리하면_가져온제목과요약태그모델을쓰고찾기본문을채우는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/pay").andExpect { status { isCreated() } }

		// when
		val worked = worker.runOnce()

		// then
		val item = row(token)
		assertTrue(worked)
		assertEquals("ready", item["status"])
		assertEquals("결제 위젯 비교", item["title"])
		assertEquals("한 줄 요약", item["list_summary"])
		assertEquals("넘길 요약입니다.", item["handoff_summary"])
		assertEquals("결제,위젯", item["tags"])
		assertEquals("fake-model", item["summary_model"])
		assertEquals("test", item["summary_prompt_version"])
		assertTrue((item["search_text"] as String).contains("포트원 본문"))
		assertEquals("done", item["job_status"])
		assertFalse(worker.runOnce())
	}

	@Test
	fun `로그인이필요한링크일때_처리하면_요약을부르지않고blocked인지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/members").andExpect { status { isCreated() } }
		fetcher.respond = { FetchResult.Blocked("login_required") }

		// when
		worker.runOnce()

		// then
		val item = row(token)
		assertEquals("blocked", item["status"])
		assertEquals("login_required", item["blocked_reason"])
		assertTrue(summarizer.calls.isEmpty())
	}

	@Test
	fun `모델이거절하거나빈요약을줄때_처리하면_failed이고찾기본문은남기는지`() {
		// given
		val token = newUser()
		saveItem(token, """{"kind":"text","text":"첫째 붙여 넣은 글"}""").andExpect { status { isCreated() } }
		saveItem(token, """{"kind":"text","text":"둘째 붙여 넣은 글"}""").andExpect { status { isCreated() } }
		val responses = ArrayDeque(listOf(SummaryResult.Refused("SAFETY"), SummaryResult.Summary(" ", "", emptyList(), null)))
		summarizer.respond = { responses.removeFirst() }

		// when
		worker.runOnce()
		worker.runOnce()

		// then
		listOf(1L, 2L).forEach { number ->
			val item = row(token, number)
			assertEquals("failed", item["status"])
			assertNull(item["handoff_summary"])
			assertTrue((item["search_text"] as String).contains("붙여 넣은 글"))
		}
	}

	@Test
	fun `일시적오류일때_처리하면_미뤄다시넣고시도를다쓰면failed인지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/slow").andExpect { status { isCreated() } }
		fetcher.respond = { FetchResult.Transient("timeout") }

		// when
		worker.runOnce()
		val afterFirst = row(token)
		jdbc.sql("UPDATE item_jobs SET run_at = now(), attempts = :max - 1 WHERE status = 'queued'")
			.param("max", ProcessingWorker.MAX_ATTEMPTS).update()
		worker.runOnce()

		// then
		assertEquals("processing", afterFirst["status"])
		assertEquals("queued", afterFirst["job_status"])
		assertEquals(true, afterFirst["deferred"])
		val afterLast = row(token)
		assertEquals("failed", afterLast["status"])
		assertEquals("failed", afterLast["job_status"])
	}

	@Test
	fun `처리중에자료를버렸을때_처리하면_결과를버리고다시시도하지않는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/trash").andExpect { status { isCreated() } }
		summarizer.respond = {
			moveToTrash(token, 1)
			summary
		}

		// when
		worker.runOnce()

		// then
		val item = row(token)
		assertNull(item["handoff_summary"])
		assertEquals("processing", item["status"])
		assertEquals("done", item["job_status"])
		assertFalse(worker.runOnce())
	}

	@Test
	fun `휴지통자료의작업일때_집으면_처리하지않고끝내는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/trashed").andExpect { status { isCreated() } }
		moveToTrash(token, 1)

		// when
		worker.runOnce()

		// then
		val item = row(token)
		assertEquals("received", item["status"])
		assertEquals("done", item["job_status"])
		assertTrue(summarizer.calls.isEmpty())
	}

	@Test
	fun `오늘이미50건을처리했을때_처리하면_AI를부르지않고failed이며본문은찾기에남는지`() {
		// given
		val token = newUser()
		repeat(ProcessingWorker.DAILY_LIMIT) {
			saveItem(token, """{"kind":"text","text":"이미 처리한 글 $it"}""").andExpect { status { isCreated() } }
		}
		jdbc.sql(
			"UPDATE item_jobs j SET status = 'done', locked_at = now() FROM items i WHERE i.id = j.item_id AND i.user_id = :userId",
		).param("userId", userIdOf(token)).update()
		saveItem(token, """{"kind":"text","text":"한도 넘은 글"}""").andExpect { status { isCreated() } }

		// when
		worker.runOnce()

		// then
		val item = row(token, ProcessingWorker.DAILY_LIMIT + 1L)
		assertEquals("failed", item["status"])
		assertTrue((item["search_text"] as String).contains("한도 넘은 글"))
		assertTrue(summarizer.calls.isEmpty())
	}

	@Test
	fun `글자없는이미지일때_처리하면_blocked_no_text이고글자있는이미지는읽은글자로찾는지`() {
		// given
		val token = newUser()
		val png = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3)
		listOf("blank.png", "words.png").forEachIndexed { index, name ->
			val uploadId = upload(token, name, png + byteArrayOf(index.toByte()))
			saveItem(token, """{"kind":"file","uploadId":"$uploadId"}""").andExpect { status { isCreated() } }
		}
		val responses = ArrayDeque(listOf(summary.copy(imageText = ""), summary.copy(imageText = "겨울엔 내 컵")))
		summarizer.respond = { responses.removeFirst() }

		// when
		worker.runOnce()
		worker.runOnce()

		// then
		assertEquals("image/png", summarizer.calls.first().image?.mimeType)
		val blank = row(token, 1)
		assertEquals("blocked", blank["status"])
		assertEquals("no_text", blank["blocked_reason"])
		val words = row(token, 2)
		assertEquals("ready", words["status"])
		assertTrue((words["search_text"] as String).contains("겨울엔 내 컵"))
	}

	@Test
	fun `본문이LLM상한보다길때_처리하면_앞부분만보내고본문일부만가져옴을붙이는지`() {
		// given
		val token = newUser()
		saveItem(token, """{"kind":"text","text":"${"가".repeat(ProcessingWorker.MAX_LLM_CHARS + 5)}"}""")
			.andExpect { status { isCreated() } }

		// when
		worker.runOnce()

		// then
		assertEquals(ProcessingWorker.MAX_LLM_CHARS, summarizer.calls.single().text?.length)
		assertEquals("본문 일부만 가져옴", row(token)["partial_note"])
	}

	private fun revise(token: String, body: String) = mockMvc.patch("/items/1") {
		header("Authorization", "Bearer $token")
		contentType = MediaType.APPLICATION_JSON
		content = body
	}.andExpect { status { isOk() } }

	private fun userColumns(token: String): Map<String, Any?> =
		jdbc.sql("SELECT user_title, user_summary FROM items WHERE user_id = :userId AND number = 1")
			.param("userId", userIdOf(token)).query().singleRow()

	@Test
	fun `직접고친요약이있을때_워커가다시처리하면_덮어쓰지않는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/revised").andExpect { status { isCreated() } }
		revise(token, """{"title":"내 제목","summary":"내가 쓴 요약"}""")

		// when
		worker.runOnce()

		// then
		val item = row(token)
		assertEquals("ready", item["status"])
		assertEquals("내 제목", item["title"])
		assertEquals("한 줄 요약", item["list_summary"])
		assertEquals(mapOf("user_title" to "내 제목", "user_summary" to "내가 쓴 요약"), userColumns(token))
		assertTrue((item["search_text"] as String).contains("내가 쓴 요약"))
		listItems(token).andExpect {
			jsonPath("$.items[0].listSummary") { value("내가 쓴 요약") }
			jsonPath("$.items[0].summarySource") { value("user") }
		}
	}

	@Test
	fun `태그를지웠을때_다시처리해도_다시붙지않는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/tags").andExpect { status { isCreated() } }
		revise(token, """{"removeTags":["결제"]}""")

		// when
		worker.runOnce()

		// then
		assertEquals("위젯", row(token)["tags"])
	}
}
