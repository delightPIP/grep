package com.unwrap.grep.features.archive.item.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import org.hamcrest.Matchers.contains
import org.hamcrest.Matchers.containsString
import org.hamcrest.Matchers.startsWith
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import kotlin.test.Test

/** GET /items/{number}(getItemDetail). 근거: ARC-011 규칙 3·6·7, ARC-004 규칙 1, ARC-003, openapi ItemDetail. */
class ItemDetailApiTest : ArchiveApiTestSupport() {

	private fun detail(token: String, number: Long) =
		mockMvc.get("/items/{number}", number) { header("Authorization", "Bearer $token") }

	private fun addToBundle(token: String, name: String, number: Long) = mockMvc.post("/bundles/{name}/items", name) {
		header("Authorization", "Bearer $token")
		contentType = MediaType.APPLICATION_JSON
		content = """{"numbers":[$number]}"""
	}.andExpect { status { isOk() } }

	private fun setColumns(token: String, number: Long, assignments: String, vararg params: Pair<String, Any>) {
		val spec = jdbc.sql("UPDATE items SET $assignments WHERE user_id = :userId AND number = :number")
			.param("userId", userIdOf(token)).param("number", number)
		params.fold(spec) { acc, (name, value) -> acc.param(name, value) }.update()
	}

	@Test
	fun `처리된링크일때_열면_요약태그전부와든묶음과본문앞2만자와전체글자수를주는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/pay?utm_source=x&id=7").andExpect { status { isCreated() } }
		val longBody = "가".repeat(20_005)
		setColumns(
			token, 1,
			"status = 'ready', handoff_summary = :summary, tags = :tags, body_text = :body, body_length = 20005",
			"summary" to "넘기기용 요약", "tags" to arrayOf("a", "b", "c", "d"), "body" to longBody.take(20_000),
		)
		addToBundle(token, "모음", 1)
		addToBundle(token, "조사", 1)

		// when
		val result = detail(token, 1)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.item.number") { value(1) }
			jsonPath("$.url") { value("https://example.com/pay?id=7") }
			jsonPath("$.handoffSummary") { value("넘기기용 요약") }
			jsonPath("$.allTags") { value(contains("a", "b", "c", "d")) }
			jsonPath("$.bundles") { value(contains("모음", "조사")) }
			jsonPath("$.body") { value(longBody.take(20_000)) }
			jsonPath("$.bodyLength") { value(20_005) }
			jsonPath("$.bodyFromImage") { value(false) }
			jsonPath("$.originalUrl") { value(null as Any?) }
			jsonPath("$.previewUrl") { value(null as Any?) }
		}
	}

	@Test
	fun `직접고친요약이있을때_열면_handoffSummary가고친요약인지`() {
		// given
		val token = newUser()
		saveLinks(token, 1)
		setColumns(token, 1, "handoff_summary = 'AI', user_summary = '직접 고침'")

		// when
		val result = detail(token, 1)

		// then
		result.andExpect {
			jsonPath("$.handoffSummary") { value("직접 고침") }
			jsonPath("$.item.summarySource") { value("user") }
		}
	}

	@Test
	fun `붙여넣은글일때_열면_글이곧본문이고묶음이없으면빈배열인지`() {
		// given
		val token = newUser()
		saveItem(token, """{"kind":"text","text":"첫 줄\n둘째 줄"}""").andExpect { status { isCreated() } }

		// when
		val result = detail(token, 1)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.body") { value("첫 줄\n둘째 줄") }
			jsonPath("$.bodyLength") { value(8) }
			jsonPath("$.bundles.length()") { value(0) }
		}
	}

	@Test
	fun `본문을아직읽지않은링크일때_열면_body와bodyLength가null인지`() {
		// given
		val token = newUser()
		saveLinks(token, 1)

		// when
		val result = detail(token, 1)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.body") { value(null as Any?) }
			jsonPath("$.bodyLength") { value(null as Any?) }
		}
	}

	@Test
	fun `이미지파일일때_열면_이미지에서읽은본문과10분짜리원본미리보기서명URL을주는지`() {
		// given
		val token = newUser()
		val uploadId = upload(token, "poster.png", PNG)
		saveItem(token, """{"kind":"file","uploadId":"$uploadId"}""").andExpect { status { isCreated() } }
		setColumns(token, 1, "body_text = '반값', body_length = 2, body_from_image = true")

		// when
		val result = detail(token, 1)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.bodyFromImage") { value(true) }
			jsonPath("$.originalUrl") { value(startsWith("https://storage.test/items/")) }
			jsonPath("$.originalUrl") { value(containsString("expires=600")) }
			jsonPath("$.previewUrl") { value(containsString("expires=600")) }
		}
	}

	@Test
	fun `휴지통이거나없거나남의번호일때_열면_404not_found와그번호인지`() {
		// given
		val token = newUser()
		saveLinks(token, 1)
		moveToTrash(token, 1)
		val other = newUser()
		saveLinks(other, 2)

		// when
		val trashed = detail(token, 1)
		val missing = detail(token, 9)
		val others = detail(newUser(), 2)

		// then
		listOf(trashed to 1, missing to 9, others to 2).forEach { (result, number) ->
			result.andExpect {
				status { isNotFound() }
				jsonPath("$.code") { value("not_found") }
				jsonPath("$.numbers") { value(contains(number)) }
			}
		}
	}

	private companion object {
		val PNG = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A) + ByteArray(32)
	}
}
