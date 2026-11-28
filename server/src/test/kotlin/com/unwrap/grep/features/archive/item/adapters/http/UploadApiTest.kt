package com.unwrap.grep.features.archive.item.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** POST /uploads(createUpload), GET /uploads/limits(getUploadLimits). 근거: COM-004, ADR-BCK-002 결정 2. */
class UploadApiTest : ArchiveApiTestSupport() {

	private val maxBytes = 20L * 1024 * 1024

	@Test
	fun `20MB이하파일일때_업로드자리를만들면_201과서명URL과만료시각을주는지`() {
		// given
		val token = newUser()

		// when
		val result = createUpload(token, "보고서.pdf", maxBytes)

		// then
		result.andExpect {
			status { isCreated() }
			jsonPath("$.uploadId") { isString() }
			jsonPath("$.uploadUrl") { isString() }
			jsonPath("$.expiresAt") { isString() }
		}
		val body = result.andReturn().response.contentAsString
		val uploadId = Regex("\"uploadId\":\"([^\"]+)\"").find(body)!!.groupValues[1]
		val path = objectPathOf(uploadId)
		assertTrue(path.startsWith("${userIdOf(token)}/"))
		assertTrue(body.contains(path))
	}

	@Test
	fun `확장자가받지않는형식일때_업로드자리를만들면_거르지않는지`() {
		// given
		val token = newUser()

		// when
		val result = createUpload(token, "압축.zip", 100)

		// then
		result.andExpect { status { isCreated() } }
	}

	@Test
	fun `20MB를넘는파일일때_업로드자리를만들면_413과파일이름과크기를주고자리를만들지않는지`() {
		// given
		val token = newUser()

		// when
		val result = createUpload(token, "큰파일.pdf", maxBytes + 1)

		// then
		result.andExpect {
			status { isPayloadTooLarge() }
			jsonPath("$.code") { value("file_too_large") }
			jsonPath("$.fileName") { value("큰파일.pdf") }
			jsonPath("$.bytes") { value(maxBytes + 1) }
		}
		val count = jdbc.sql("SELECT count(*) FROM uploads WHERE user_id = :u").param("u", userIdOf(token))
			.query(Int::class.java).single()
		assertEquals(0, count)
	}

	@Test
	fun `파일이름이비었거나크기가음수일때_업로드자리를만들면_400invalid_request로막는지`() {
		// given
		val token = newUser()
		val bodies = listOf("""{"fileName":"","size":1}""", """{"fileName":"a.pdf","size":-1}""", """{"fileName":"a.pdf"}""")

		// when
		val results = bodies.map {
			mockMvc.post("/uploads") {
				header("Authorization", "Bearer $token")
				contentType = MediaType.APPLICATION_JSON
				content = it
			}
		}

		// then
		results.forEach {
			it.andExpect {
				status { isBadRequest() }
				jsonPath("$.code") { value("invalid_request") }
			}
		}
	}

	@Test
	fun `로그인했을때_업로드한도를물으면_받는형식8개와20MB를주는지`() {
		// given
		val token = newUser()

		// when
		val result = mockMvc.get("/uploads/limits") { header("Authorization", "Bearer $token") }

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.formats.length()") { value(8) }
			listOf("pdf", "md", "txt", "docx", "png", "jpeg", "webp", "heic").forEachIndexed { index, format ->
				jsonPath("$.formats[$index]") { value(format) }
			}
			jsonPath("$.maxBytes") { value(maxBytes) }
		}
	}
}
