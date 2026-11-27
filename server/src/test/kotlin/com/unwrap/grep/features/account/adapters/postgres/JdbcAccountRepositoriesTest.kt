package com.unwrap.grep.features.account.adapters.postgres

import com.unwrap.grep.TestcontainersConfiguration
import com.unwrap.grep.features.account.domain.AuthProvider
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.annotation.Import
import java.time.Duration
import java.time.Instant
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import kotlin.test.Test
import kotlin.test.assertEquals

@Import(TestcontainersConfiguration::class)
@SpringBootTest
class JdbcAccountRepositoriesTest {

	@Autowired
	lateinit var users: JdbcUserRepository

	@Autowired
	lateinit var sessions: JdbcSessionRepository

	@Test
	fun `처음로그인한계정일때_요청여럿이동시에계정을찾으면_계정하나를함께돌려주는지`() {
		// given
		val externalId = "external-${UUID.randomUUID()}"
		val requests = 8
		val ready = CountDownLatch(requests)
		val pool = Executors.newFixedThreadPool(requests)

		// when
		val accounts = try {
			(1..requests).map {
				pool.submit(Callable {
					ready.countDown()
					ready.await()
					users.findOrCreate(AuthProvider.GOOGLE, externalId)
				})
			}.map { it.get() }
		} finally {
			pool.shutdown()
		}

		// then
		assertEquals(1, accounts.map { it.userId }.toSet().size)
	}

	@Test
	fun `세션을늦은시각으로본뒤일때_이른시각으로다시보면_마지막사용시각을되돌리지않는지`() {
		// given
		val account = users.findOrCreate(AuthProvider.GITHUB, "external-${UUID.randomUUID()}")
		val sessionId = UUID.randomUUID()
		val start = Instant.parse("2026-11-26T00:00:00Z")
		sessions.findOrStart(sessionId, account.userId, start)
		val later = start.plus(Duration.ofMinutes(10))
		sessions.touch(sessionId, later)

		// when
		sessions.touch(sessionId, start.plus(Duration.ofMinutes(5)))

		// then
		assertEquals(later, sessions.findOrStart(sessionId, account.userId, later).lastSeenAt)
	}
}
