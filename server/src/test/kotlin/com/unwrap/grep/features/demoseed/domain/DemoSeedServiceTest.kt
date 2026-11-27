package com.unwrap.grep.features.demoseed.domain

import com.unwrap.grep.features.account.domain.AuthProvider
import com.unwrap.grep.features.archive.domain.ItemSearch
import com.unwrap.grep.features.archive.domain.SearchQuery
import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.processing.domain.ProcessingWorker
import com.unwrap.grep.features.processing.testing.FakeProcessingConfiguration
import com.unwrap.grep.features.processing.testing.FakeSummarizer
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.context.annotation.Import
import java.nio.file.Path
import java.sql.Timestamp
import java.time.Duration
import java.time.Instant
import java.util.UUID
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * 데모 시드 도구(#69). 실제 db/seed/demo 묶음을 실제 DB에 넣어 본다.
 * 근거: demo-seed 2절 1·2·5·7·8번, 5절 장면표(`찾기 텀블러` 8건, `찾기 텀블러 캠페인` 4건), ARC-001, COM-005.
 */
@Import(FakeProcessingConfiguration::class)
class DemoSeedServiceTest : ArchiveApiTestSupport() {

	@Autowired
	lateinit var seeder: DemoSeedService

	@Autowired
	lateinit var search: ItemSearch

	@Autowired
	lateinit var worker: ProcessingWorker

	@Autowired
	lateinit var summarizer: FakeSummarizer

	private val seedDir = Path.of("../db/seed/demo")

	/** Supabase auth.users를 흉내 낸다. 로그인한 적 있는 계정만 우리 users 행이 있다. */
	@BeforeTest
	fun authSchema() {
		jdbc.sql("CREATE SCHEMA IF NOT EXISTS auth").update()
		jdbc.sql("CREATE TABLE IF NOT EXISTS auth.users (id uuid PRIMARY KEY, email text)").update()
		jdbc.sql("UPDATE item_jobs SET status = 'done' WHERE status IN ('queued', 'running')").update()
		summarizer.calls.clear()
	}

	private fun account(provider: AuthProvider = AuthProvider.GOOGLE, signedIn: Boolean = true): Pair<String, UUID> {
		val authId = UUID.randomUUID()
		val email = "demo-$authId@example.test"
		jdbc.sql("INSERT INTO auth.users (id, email) VALUES (:id, :email)").param("id", authId).param("email", email).update()
		val userId = UUID.randomUUID()
		if (signedIn) {
			jdbc.sql("INSERT INTO users (id, auth_provider, external_id) VALUES (:id, :provider, :externalId)")
				.param("id", userId).param("provider", provider.claimValue).param("externalId", authId.toString()).update()
		}
		return email to userId
	}

	private fun words(vararg words: String) = SearchQuery(words.toList(), emptyList())

	@Test
	fun `빈계정에넣었을때_시드를실행하면_34건이S번호대로들어가는지`() {
		// given
		val (email, userId) = account()
		val before = Instant.now()

		// when
		val result = seeder.seed(AuthProvider.GOOGLE, email.uppercase(), seedDir)

		// then
		val seeded = assertIs<SeedResult.Seeded>(result)
		assertEquals((1..34).associate { "S%02d".format(it) to it.toLong() }, seeded.numbers)
		val rows = jdbc.sql(
			"""
			SELECT number, status, blocked_reason, created_at, object_path, list_summary
			FROM items WHERE user_id = :userId ORDER BY number
			""".trimIndent(),
		).param("userId", userId).query().listOfRows()
		val s01 = rows.first()
		val s01SavedAt = (s01["created_at"] as Timestamp).toInstant()
		assertTrue(Duration.between(s01SavedAt, before.minus(Duration.ofDays(45))).abs() < Duration.ofMinutes(1))
		assertEquals(listOf(7L to "no_text", 33L to "login_required"),
			rows.filter { it["status"] == "blocked" }.map { it["number"] as Long to it["blocked_reason"] })
		assertEquals(32, rows.count { it["list_summary"] != null })
		val objectPaths = rows.mapNotNull { it["object_path"] as String? }
		assertEquals(20, objectPaths.size)
		assertTrue(objectPaths.all { it.startsWith("$userId/") && storage.exists(it) })
		assertEquals(34L, jdbc.sql("SELECT last_item_number FROM users WHERE id = :id").param("id", userId).query(Long::class.java).single())
		assertEquals(8, search.count(userId, words("텀블러")))
		assertEquals(4, search.count(userId, words("텀블러", "캠페인")))
	}

	@Test
	fun `자료가있는계정에_시드를실행하면_거부하는지`() {
		// given
		val (email, userId) = account()
		jdbc.sql("UPDATE users SET last_item_number = 3 WHERE id = :id").param("id", userId).update()

		// when
		val result = seeder.seed(AuthProvider.GOOGLE, email, seedDir)

		// then
		assertEquals(SeedResult.AlreadyHasItems(3), result)
		assertEquals(0, jdbc.sql("SELECT count(*) FROM items WHERE user_id = :id").param("id", userId).query(Int::class.java).single())
	}

	@Test
	fun `첫로그인전계정에_시드를실행하면_사용자없음을알리는지`() {
		// given
		val (email, _) = account(signedIn = false)

		// when
		val result = seeder.seed(AuthProvider.GOOGLE, email, seedDir)

		// then
		assertEquals(SeedResult.UserNotFound, result)
	}

	@Test
	fun `다른로그인방식계정만있을때_시드를실행하면_사용자없음을알리는지`() {
		// given
		val (email, _) = account(provider = AuthProvider.GITHUB)

		// when
		val result = seeder.seed(AuthProvider.GOOGLE, email, seedDir)

		// then
		assertEquals(SeedResult.UserNotFound, result)
	}

	@Test
	fun `시드뒤_워커가돌면_시드자료를다시처리하지않는지`() {
		// given
		val (email, userId) = account()
		seeder.seed(AuthProvider.GOOGLE, email, seedDir)

		// when
		val picked = worker.runOnce()

		// then
		assertFalse(picked)
		assertTrue(summarizer.calls.isEmpty())
		assertEquals(0, jdbc.sql("SELECT count(*) FROM item_jobs j JOIN items i ON i.id = j.item_id WHERE i.user_id = :id")
			.param("id", userId).query(Int::class.java).single())
	}
}
