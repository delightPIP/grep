package com.unwrap.grep.features.processing.adapters.gemini

import com.sun.net.httpserver.HttpServer
import com.unwrap.grep.features.processing.domain.SummaryImage
import com.unwrap.grep.features.processing.domain.SummaryInput
import com.unwrap.grep.features.processing.domain.SummaryResult
import java.net.InetSocketAddress
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Gemini 어댑터의 요청 모양과 응답 해석. 근거: ADR-BCK-014, COM-002, H-06. 실제 호출은 수동 1회로 본다. */
class GeminiSummarizerTest {
	private lateinit var server: HttpServer
	private var status = 200
	private var responseBody = ""
	private var requestPath = ""
	private var requestKey: String? = null
	private var requestBody = ""

	@BeforeTest
	fun start() {
		server = HttpServer.create(InetSocketAddress("localhost", 0), 0)
		server.createContext("/") { exchange ->
			requestPath = exchange.requestURI.path
			requestKey = exchange.requestHeaders.getFirst("x-goog-api-key")
			requestBody = exchange.requestBody.readAllBytes().decodeToString()
			val bytes = responseBody.toByteArray()
			exchange.sendResponseHeaders(status, if (bytes.isEmpty()) -1 else bytes.size.toLong())
			exchange.responseBody.use { it.write(bytes) }
		}
		server.start()
	}

	@AfterTest
	fun stop() = server.stop(0)

	private fun summarizer(key: String = "test-key") =
		GeminiSummarizer(key, "gemini-test", "http://localhost:${server.address.port}")

	private fun candidate(text: String) =
		"""{"candidates":[{"content":{"parts":[{"text":${quote(text)}}]},"finishReason":"STOP"}]}"""

	private fun quote(value: String) = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

	@Test
	fun `정상응답일때_요약하면_키를헤더로보내고JSON칸을읽는지`() {
		// given
		responseBody = candidate("""{"listSummary":"한 줄","handoffSummary":"넘길 요약","tags":["결제","ui"],"imageText":"컵"}""")
		val input = SummaryInput("파란컵.png", "png", null, SummaryImage(byteArrayOf(1, 2, 3), "image/png"))

		// when
		val result = summarizer().summarize(input)

		// then
		assertEquals(SummaryResult.Summary("한 줄", "넘길 요약", listOf("결제", "ui"), "컵"), result)
		assertEquals("/v1beta/models/gemini-test:generateContent", requestPath)
		assertEquals("test-key", requestKey)
		assertTrue("\"inlineData\":{\"mimeType\":\"image/png\",\"data\":\"AQID\"}" in requestBody)
		assertTrue("\"responseMimeType\":\"application/json\"" in requestBody)
	}

	@Test
	fun `거절빈응답깨진응답일때_요약하면_Refused인지`() {
		// given
		val bodies = listOf(
			"""{"promptFeedback":{"blockReason":"SAFETY"}}""",
			"""{"candidates":[{"content":{"parts":[]},"finishReason":"SAFETY"}]}""",
			candidate("not json"),
		)

		// when
		val results = bodies.map { body ->
			responseBody = body
			summarizer().summarize(SummaryInput("t", null, "본문", null))
		}

		// then
		assertTrue(results.all { it is SummaryResult.Refused }, results.toString())
	}

	@Test
	fun `429와503일때_요약하면_다시시도하고400은Refused인지`() {
		// given
		val statuses = listOf(429, 503, 400)

		// when
		val results = statuses.map { code ->
			status = code
			responseBody = "{}"
			summarizer().summarize(SummaryInput("t", null, "본문", null))
		}

		// then
		assertEquals(
			listOf(SummaryResult.Transient("gemini http 429"), SummaryResult.Transient("gemini http 503"), SummaryResult.Refused("gemini http 400")),
			results,
		)
	}

	@Test
	fun `키가비어있을때_요약하면_부르지않고Refused인지`() {
		// given
		requestPath = ""

		// when
		val result = summarizer(key = "").summarize(SummaryInput("t", null, "본문", null))

		// then
		assertTrue(result is SummaryResult.Refused)
		assertEquals("", requestPath)
	}
}
