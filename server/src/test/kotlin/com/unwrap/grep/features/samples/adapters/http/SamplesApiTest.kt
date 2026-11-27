package com.unwrap.grep.features.samples.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import org.hamcrest.Matchers.contains
import org.springframework.test.web.servlet.post
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * POST /samples(saveSamples). 실제 샘플 db/seed/samples/samples.json(데모 시드 S04·S11·S26·S23·S25·S28·S30 + 사용법 G1)을 쓴다.
 * 근거: ARC-010 규칙 2·3·5·7, ARC-001 규칙 6, COM-005.
 */
class SamplesApiTest : ArchiveApiTestSupport() {

	private fun saveSamples(token: String) = mockMvc.post("/samples") { header("Authorization", "Bearer $token") }

	private fun sampleRange(token: String): Map<String, Any?> =
		jdbc.sql("SELECT sample_first_number, sample_last_number FROM users WHERE id = :userId")
			.param("userId", userIdOf(token)).query().singleRow()

	private fun jobCount(token: String): Int =
		jdbc.sql("SELECT count(*) FROM item_jobs j JOIN items i ON i.id = j.item_id WHERE i.user_id = :userId")
			.param("userId", userIdOf(token)).query(Int::class.java).single()

	private fun objectPaths(token: String): List<String> =
		jdbc.sql("SELECT object_path FROM items WHERE user_id = :userId AND object_path IS NOT NULL")
			.param("userId", userIdOf(token)).query(String::class.java).list().filterNotNull()

	@Test
	fun `새계정일때_샘플을받으면_1부터8까지저장하고처리작업을만들지않는지`() {
		// given
		val token = newUser()

		// when
		val result = saveSamples(token)

		// then
		result.andExpect {
			status { isCreated() }
			jsonPath("$.firstNumber") { value(1) }
			jsonPath("$.lastNumber") { value(8) }
		}
		listItems(token).andExpect {
			jsonPath("$.items[*].number") { value(contains(8, 7, 6, 5, 4, 3, 2, 1)) }
			jsonPath("$.items[7].title") { value("솔밭커피 브랜드 말투 가이드.docx") }
			jsonPath("$.items[0].title") { value("그렙 사용법") }
			jsonPath("$.items[0].status") { value("ready") }
		}
		assertEquals(0, jobCount(token))
		val paths = objectPaths(token)
		assertEquals(5, paths.size)
		assertTrue(paths.all(storage::exists))
	}

	@Test
	fun `두번눌렀을때_한번만저장하는지`() {
		// given
		val token = newUser()
		saveSamples(token).andExpect { status { isCreated() } }

		// when
		val result = saveSamples(token)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.firstNumber") { value(1) }
			jsonPath("$.lastNumber") { value(8) }
		}
		assertEquals(8, countItems(token))
	}

	@Test
	fun `자료를모두버린계정일때_샘플을받으면_지운번호뒤부터저장하는지`() {
		// given
		val token = newUser()
		saveLinks(token, 2)
		moveToTrash(token, 1)
		moveToTrash(token, 2)

		// when
		val result = saveSamples(token)

		// then
		result.andExpect {
			jsonPath("$.firstNumber") { value(3) }
			jsonPath("$.lastNumber") { value(10) }
		}
	}

	@Test
	fun `하나라도실패하면_아무것도저장하지않는지`() {
		// given: 일곱째 샘플(S30)과 같은 링크가 휴지통에 있으면 같은 자료 판정 색인에 걸려 그 행을 넣지 못한다
		val token = newUser()
		saveLink(token, "https://carti1108.github.io/grep-seed-demo/s30.html").andExpect { status { isCreated() } }
		moveToTrash(token, 1)
		val pathsBefore = storage.paths()

		// when
		val status = runCatching { saveSamples(token).andReturn().response.status }

		// then
		assertTrue(status.isFailure || status.getOrNull() == 500)
		assertEquals(1, countItems(token))
		assertEquals(mapOf("sample_first_number" to null, "sample_last_number" to null), sampleRange(token))
		assertEquals(pathsBefore, storage.paths())
	}
}
