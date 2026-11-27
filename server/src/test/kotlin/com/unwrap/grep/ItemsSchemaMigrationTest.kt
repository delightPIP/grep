package com.unwrap.grep

import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.annotation.Import
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.jdbc.core.simple.JdbcClient
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

// V2 items·처리 작업 계약(#56). ARC-001(번호), ARC-005(상태), COM-001(같은 자료), COM-006(사용자별).
@Import(TestcontainersConfiguration::class)
@SpringBootTest
class ItemsSchemaMigrationTest {

	@Autowired
	lateinit var jdbc: JdbcClient

	private fun newUser(): UUID {
		val id = UUID.randomUUID()
		jdbc.sql("INSERT INTO users (id, auth_provider, external_id) VALUES (?, 'google', ?)")
			.params(id, "external-$id")
			.update()
		return id
	}

	private fun insertLink(user: UUID, number: Long, normalizedUrl: String, status: String = "received") =
		jdbc.sql(
			"""
			INSERT INTO items (user_id, number, kind, url, normalized_url, title, source, status)
			VALUES (?, ?, 'link', ?, ?, '제목', 'example.com', ?)
			""".trimIndent(),
		).params(user, number, "https://$normalizedUrl", normalizedUrl, status).update()

	private fun nextNumber(user: UUID): Long =
		jdbc.sql("UPDATE users SET last_item_number = last_item_number + 1 WHERE id = ? RETURNING last_item_number")
			.param(user)
			.query(Long::class.java)
			.single()

	@Test
	fun `새사용자일때_번호를두번발급하면_1과2를주는지`() {
		// given
		val user = newUser()

		// when
		val numbers = listOf(nextNumber(user), nextNumber(user))

		// then
		assertEquals(listOf(1L, 2L), numbers)
	}

	@Test
	fun `사용자에게1번자료가있을때_같은번호로또넣으면_거부하는지`() {
		// given
		val user = newUser()
		insertLink(user, 1, "example.com/a")

		// when, then
		assertFailsWith<DataIntegrityViolationException> { insertLink(user, 1, "example.com/b") }
	}

	@Test
	fun `사용자에게링크가있을때_같은정규화주소로넣으면_같은사용자는거부하고다른사용자는받는지`() {
		// given
		val owner = newUser()
		val other = newUser()
		insertLink(owner, 1, "example.com/same")

		// when
		insertLink(other, 1, "example.com/same")

		// then
		assertFailsWith<DataIntegrityViolationException> { insertLink(owner, 2, "example.com/same") }
	}

	@Test
	fun `상태다섯가지가정해져있을때_다른상태로넣으면_거부하는지`() {
		// given
		val user = newUser()

		// when, then
		assertFailsWith<DataIntegrityViolationException> { insertLink(user, 1, "example.com/x", status = "done") }
	}

	@Test
	fun `검색글에낱말이있을때_PGroonga로찾으면_그자료만나오는지`() {
		// given
		val user = newUser()
		insertLink(user, 1, "example.com/tumbler")
		insertLink(user, 2, "example.com/coffee")
		jdbc.sql("UPDATE items SET search_text = '카페 텀블러 할인 캠페인' WHERE user_id = ? AND number = 1").param(user).update()
		jdbc.sql("UPDATE items SET search_text = '겨울 음료 트렌드' WHERE user_id = ? AND number = 2").param(user).update()

		// when
		val found = jdbc.sql("SELECT number FROM items WHERE user_id = ? AND search_text &@~ '텀블러'")
			.param(user)
			.query(Long::class.java)
			.list()

		// then
		assertEquals(listOf(1L), found)
	}

	@Test
	fun `본문못가져옴이유는blocked일때만있을때_blocked가아닌자료에이유를넣으면_거부하는지`() {
		// given
		val user = newUser()
		insertLink(user, 1, "example.com/ready", status = "ready")

		// when, then
		assertFailsWith<DataIntegrityViolationException> {
			jdbc.sql("UPDATE items SET blocked_reason = 'login_required' WHERE user_id = ?").param(user).update()
		}
	}

	@Test
	fun `자료에기다리는처리작업이있을때_작업을하나더넣으면_거부하는지`() {
		// given
		val user = newUser()
		insertLink(user, 1, "example.com/twice")
		val itemId = jdbc.sql("SELECT id FROM items WHERE user_id = ? AND number = 1").param(user)
			.query(UUID::class.java).single()
		jdbc.sql("INSERT INTO item_jobs (item_id) VALUES (?)").param(itemId).update()

		// when, then
		assertFailsWith<DataIntegrityViolationException> {
			jdbc.sql("INSERT INTO item_jobs (item_id) VALUES (?)").param(itemId).update()
		}
	}

	@Test
	fun `자료가있을때_처리작업을넣으면_받음상태로기다리는지`() {
		// given
		val user = newUser()
		insertLink(user, 1, "example.com/job")
		val itemId = jdbc.sql("SELECT id FROM items WHERE user_id = ? AND number = 1").param(user)
			.query(UUID::class.java).single()

		// when
		jdbc.sql("INSERT INTO item_jobs (item_id) VALUES (?)").param(itemId).update()

		// then
		val status = jdbc.sql("SELECT status FROM item_jobs WHERE item_id = ?").param(itemId)
			.query(String::class.java).single()
		assertEquals("queued", status)
	}
}
