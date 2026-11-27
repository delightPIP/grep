package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** POST /items(saveItem), GET /me itemCount. 근거: ARC-001, ARC-005, COM-001, COM-004, COM-006. */
class SaveItemApiTest : ArchiveApiTestSupport() {

	private val pdf = "%PDF-1.7\n본문".toByteArray()

	@Test
	fun `새링크일때_저장하면_201과번호1의ItemSummary필드를모두주는지`() {
		// given
		val token = newUser()

		// when
		val result = saveLink(token, "https://WWW.Example.com/post/?utm_source=x")

		// then
		result.andExpect {
			status { isCreated() }
			jsonPath("$.result") { value("saved") }
			jsonPath("$.item.number") { value(1) }
			jsonPath("$.item.kind") { value("link") }
			jsonPath("$.item.title") { value("https://WWW.Example.com/post/?utm_source=x") }
			jsonPath("$.item.source") { value("example.com") }
			jsonPath("$.item.status") { value("received") }
			jsonPath("$.item.tags") { isEmpty() }
			jsonPath("$.item.savedAt") { isString() }
			listOf("blockedReason", "listSummary", "summarySource", "partialNote", "matchedIn").forEach {
				jsonPath("$.item.$it") { hasJsonPath(); isEmpty() }
			}
		}
	}

	@Test
	fun `새자료일때_저장하면_처리작업을한건넣는지`() {
		// given
		val token = newUser()

		// when
		saveLink(token, "https://example.com/job").andExpect { status { isCreated() } }

		// then
		val jobs = jdbc.sql(
			"SELECT count(*) FROM item_jobs j JOIN items i ON i.id = j.item_id WHERE i.user_id = :u AND j.status = 'queued'",
		).param("u", userIdOf(token)).query(Int::class.java).single()
		assertEquals(1, jobs)
	}

	@Test
	fun `자료를여러번저장할때_번호를1씩올리고사용자마다따로세는지`() {
		// given
		val alice = newUser()
		val bob = newUser()

		// when
		val aliceNumbers = (1..3).map { number(saveLink(alice, "https://example.com/$it")) }
		val bobFirst = number(saveLink(bob, "https://example.com/1"))

		// then
		assertEquals(listOf(1L, 2L, 3L), aliceNumbers)
		assertEquals(1L, bobFirst)
	}

	@Test
	fun `정규화주소가같은링크가있을때_저장하면_200duplicate로기존자료를주고번호를발급하지않는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/a").andExpect { status { isCreated() } }

		// when
		val result = saveLink(token, "http://www.example.com/a/#top")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.result") { value("duplicate") }
			jsonPath("$.item.number") { value(1) }
		}
		assertEquals(2L, number(saveLink(token, "https://example.com/b")))
	}

	@Test
	fun `같은링크가휴지통에있을때_저장하면_200inTrash를주는지`() {
		// given
		val token = newUser()
		saveLink(token, "https://example.com/trash").andExpect { status { isCreated() } }
		moveToTrash(token, 1)

		// when
		val result = saveLink(token, "https://example.com/trash")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.result") { value("inTrash") }
			jsonPath("$.item.number") { value(1) }
		}
		assertEquals(1, countItems(token))
	}

	@Test
	fun `다른사용자가같은링크를저장했을때_저장하면_새로저장하는지`() {
		// given
		val alice = newUser()
		val bob = newUser()
		saveLink(alice, "https://example.com/shared").andExpect { status { isCreated() } }

		// when
		val result = saveLink(bob, "https://example.com/shared")

		// then
		result.andExpect {
			status { isCreated() }
			jsonPath("$.result") { value("saved") }
		}
	}

	@Test
	fun `같은멱등성키로다시보냈을때_저장하면_200으로처음결과를주고새로만들지않는지`() {
		// given
		val token = newUser()
		val key = UUID.randomUUID().toString()
		saveLink(token, "https://example.com/once", key).andExpect { status { isCreated() } }

		// when
		val retry = saveItem(token, """{"kind":"text","text":"다른 본문"}""", key)

		// then
		retry.andExpect {
			status { isOk() }
			jsonPath("$.result") { value("saved") }
			jsonPath("$.item.number") { value(1) }
			jsonPath("$.item.kind") { value("link") }
		}
		assertEquals(1, countItems(token))
	}

	@Test
	fun `멱등성키가없거나uuid가아닐때_저장하면_400invalid_request로막는지`() {
		// given
		val token = newUser()
		val body = """{"kind":"text","text":"메모"}"""

		// when
		val results = listOf(saveItem(token, body, key = null), saveItem(token, body, key = "not-a-uuid"))

		// then
		results.forEach {
			it.andExpect {
				status { isBadRequest() }
				jsonPath("$.code") { value("invalid_request") }
			}
		}
		assertEquals(0, countItems(token))
	}

	@Test
	fun `본문이계약과다를때_저장하면_400invalid_request로막는지`() {
		// given
		val token = newUser()
		val bodies = listOf(
			"""{"kind":"link","url":"ftp://example.com/a"}""",
			"""{"kind":"link"}""",
			"""{"kind":"text","text":""}""",
			"""{"kind":"file","uploadId":"nope"}""",
			"""{"kind":"video","url":"https://example.com"}""",
			"""{not json""",
		)

		// when
		val results = bodies.map { saveItem(token, it) }

		// then
		results.forEach {
			it.andExpect {
				status { isBadRequest() }
				jsonPath("$.code") { value("invalid_request") }
			}
		}
	}

	@Test
	fun `토큰이없을때_저장하면_401로막는지`() {
		// given: 토큰 없음

		// when
		val result = mockMvc.perform(
			org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/items")
				.header("Idempotency-Key", UUID.randomUUID().toString())
				.contentType("application/json")
				.content("""{"kind":"text","text":"x"}"""),
		)

		// then
		assertEquals(401, result.andReturn().response.status)
	}

	@Test
	fun `붙여넣은글일때_저장하면_첫줄24자까지를제목으로하고출처는비우는지`() {
		// given
		val token = newUser()

		// when
		val result = saveItem(token, """{"kind":"text","text":"가나다라마바사아자차카타파하가나다라마바사아자차카타\n둘째 줄"}""")

		// then
		result.andExpect {
			status { isCreated() }
			jsonPath("$.item.kind") { value("text") }
			jsonPath("$.item.title") { value("가나다라마바사아자차카타파하가나다라마바사아자차") }
			jsonPath("$.item.source") { hasJsonPath(); isEmpty() }
		}
	}

	@Test
	fun `받는형식의파일일때_저장하면_파일이름을제목으로형식을출처로저장하는지`() {
		// given
		val token = newUser()
		val uploadId = upload(token, "보고서.pdf", pdf)

		// when
		val result = saveItem(token, """{"kind":"file","uploadId":"$uploadId"}""")

		// then
		result.andExpect {
			status { isCreated() }
			jsonPath("$.result") { value("saved") }
			jsonPath("$.item.kind") { value("file") }
			jsonPath("$.item.title") { value("보고서.pdf") }
			jsonPath("$.item.source") { value("pdf") }
		}
		assertTrue(storage.exists(objectPathOf(uploadId)))
		val consumed = jdbc.sql("SELECT consumed_at IS NOT NULL FROM uploads WHERE id = :id")
			.param("id", UUID.fromString(uploadId)).query(Boolean::class.java).single()
		assertTrue(consumed)
	}

	@Test
	fun `확장자와내용이다른파일일때_저장하면_내용으로판정한형식을쓰는지`() {
		// given
		val token = newUser()
		val uploadId = upload(token, "사진.txt", byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A))

		// when
		val result = saveItem(token, """{"kind":"file","uploadId":"$uploadId"}""")

		// then
		result.andExpect {
			status { isCreated() }
			jsonPath("$.item.source") { value("png") }
		}
	}

	@Test
	fun `같은내용의파일이있을때_저장하면_200duplicate를주고새객체를지우는지`() {
		// given
		val token = newUser()
		val first = upload(token, "a.pdf", pdf)
		saveItem(token, """{"kind":"file","uploadId":"$first"}""").andExpect { status { isCreated() } }
		val second = upload(token, "이름만다름.pdf", pdf)
		val secondPath = objectPathOf(second)

		// when
		val result = saveItem(token, """{"kind":"file","uploadId":"$second"}""")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.result") { value("duplicate") }
			jsonPath("$.item.number") { value(1) }
		}
		assertFalse(storage.exists(secondPath))
		assertTrue(storage.exists(objectPathOf(first)))
		assertEquals(1, countItems(token))
	}

	@Test
	fun `받지않는형식의파일일때_저장하면_415와판별한확장자를주고객체를지우는지`() {
		// given
		val token = newUser()
		val uploadId = upload(token, "움짤.png", "GIF89a....".toByteArray())
		val path = objectPathOf(uploadId)

		// when
		val result = saveItem(token, """{"kind":"file","uploadId":"$uploadId"}""")

		// then
		result.andExpect {
			status { isUnsupportedMediaType() }
			jsonPath("$.code") { value("unsupported_format") }
			jsonPath("$.fileExtension") { value("gif") }
		}
		assertFalse(storage.exists(path))
		assertEquals(0, countItems(token))
	}

	@Test
	fun `올린파일이20MB를넘을때_저장하면_413과파일이름과크기를주는지`() {
		// given
		val token = newUser()
		val uploadId = upload(token, "small.pdf", pdf)
		val path = objectPathOf(uploadId)
		val tooLarge = ByteArray(20 * 1024 * 1024 + 1)
		storage.put(path, tooLarge)

		// when
		val result = saveItem(token, """{"kind":"file","uploadId":"$uploadId"}""")

		// then
		result.andExpect {
			status { isPayloadTooLarge() }
			jsonPath("$.code") { value("file_too_large") }
			jsonPath("$.fileName") { value("small.pdf") }
			jsonPath("$.bytes") { value(tooLarge.size) }
		}
		assertFalse(storage.exists(path))
	}

	@Test
	fun `남의업로드이거나이미쓴업로드이거나올리지않은업로드일때_저장하면_400invalid_request로막는지`() {
		// given
		val owner = newUser()
		val stranger = newUser()
		val othersUpload = upload(owner, "a.pdf", pdf)
		val usedUpload = upload(stranger, "b.pdf", "%PDF-b".toByteArray())
		saveItem(stranger, """{"kind":"file","uploadId":"$usedUpload"}""").andExpect { status { isCreated() } }
		val notPut = createUpload(stranger, "c.pdf", 10).andReturn().response.contentAsString
			.let { Regex("\"uploadId\":\"([^\"]+)\"").find(it)!!.groupValues[1] }

		// when
		val results = listOf(othersUpload, usedUpload, notPut, UUID.randomUUID().toString())
			.map { saveItem(stranger, """{"kind":"file","uploadId":"$it"}""") }

		// then
		results.forEach {
			it.andExpect {
				status { isBadRequest() }
				jsonPath("$.code") { value("invalid_request") }
			}
		}
		assertTrue(storage.exists(objectPathOf(othersUpload)))
		assertEquals(1, countItems(stranger))
	}

	@Test
	fun `같은링크를동시에두번저장할때_저장하면_자료를하나만만드는지`() {
		// given
		val token = newUser()
		userIdOf(token)
		val pool = Executors.newFixedThreadPool(4)
		val start = CountDownLatch(1)

		// when
		val statuses = try {
			(1..4).map {
				pool.submit(Callable {
					start.await()
					saveLink(token, "https://example.com/race").andReturn().response.status
				})
			}.also { start.countDown() }.map { it.get() }
		} finally {
			pool.shutdown()
		}

		// then
		assertEquals(listOf(200, 200, 200, 201), statuses.sorted())
		assertEquals(1, countItems(token))
	}

	@Test
	fun `휴지통자료가있을때_me를부르면_휴지통밖자료만세는지`() {
		// given
		val token = newUser()
		(1..3).forEach { saveLink(token, "https://example.com/count/$it").andExpect { status { isCreated() } } }
		moveToTrash(token, 2)

		// when
		val result = getMe(token)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.itemCount") { value(2) }
		}
	}

	private fun number(result: org.springframework.test.web.servlet.ResultActionsDsl): Long =
		Regex("\"number\":(\\d+)").find(result.andReturn().response.contentAsString)!!.groupValues[1].toLong()
}
