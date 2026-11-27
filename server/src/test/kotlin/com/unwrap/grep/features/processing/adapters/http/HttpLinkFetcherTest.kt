package com.unwrap.grep.features.processing.adapters.http

import com.sun.net.httpserver.HttpServer
import com.unwrap.grep.features.processing.domain.AddressGuard
import com.unwrap.grep.features.processing.domain.FetchResult
import java.net.InetAddress
import java.net.InetSocketAddress
import java.util.concurrent.atomic.AtomicInteger
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * ARC-006 링크 가져오기. 로컬 서버의 IPv4 루프백(127.0.0.1)만 공인 주소로 쳐서 HTTP 동작을 본다.
 * `internal.test`는 사설 주소로, `rebind.test`는 처음에만 루프백이고 그 뒤로는 사설 주소로 풀린다.
 */
class HttpLinkFetcherTest {
	private lateinit var server: HttpServer
	private val loopback = InetAddress.getByName("127.0.0.1")
	private val privateAddress = InetAddress.getByName("10.0.0.5")
	private val rebindLookups = AtomicInteger()
	private val fetcher = HttpLinkFetcher(
		resolve = { host ->
			when (host) {
				"localhost" -> listOf(loopback)
				"internal.test" -> listOf(privateAddress)
				"rebind.test" -> listOf(if (rebindLookups.getAndIncrement() == 0) loopback else privateAddress)
				else -> InetAddress.getAllByName(host).toList()
			}
		},
		isPublic = { it == loopback || AddressGuard.isPublic(it) },
	)

	private fun url(path: String) = "http://localhost:${server.address.port}$path"

	@BeforeTest
	fun start() {
		server = HttpServer.create(InetSocketAddress("localhost", 0), 0)
		fun route(path: String, status: Int, type: String = "text/html; charset=utf-8", body: ByteArray = ByteArray(0), location: String? = null) {
			server.createContext(path) { exchange ->
				exchange.responseHeaders.add("Content-Type", type)
				location?.let { exchange.responseHeaders.add("Location", it) }
				exchange.sendResponseHeaders(status, if (body.isEmpty()) -1 else body.size.toLong())
				exchange.responseBody.use { it.write(body) }
			}
		}
		route("/page", 200, body = "<title>안녕</title><p>본문</p>".toByteArray())
		route("/to-page", 302, location = "/page")
		route("/to-internal", 302, location = "http://internal.test/admin")
		route("/login", 401)
		route("/forbidden", 403)
		route("/gone", 404)
		route("/broken", 503)
		route("/big", 200, "text/plain", ByteArray(HttpLinkFetcher.MAX_BYTES + 10) { 'a'.code.toByte() })
		server.start()
	}

	@AfterTest
	fun stop() = server.stop(0)

	@Test
	fun `공개페이지로리디렉션될때_가져오면_따라가서HTML과charset을주는지`() {
		// given
		val target = url("/to-page")

		// when
		val result = fetcher.fetch(target)

		// then
		result as FetchResult.Fetched
		assertEquals("text/html", result.mediaType)
		assertEquals("utf-8", result.charset)
		assertEquals("<title>안녕</title><p>본문</p>", String(result.bytes, Charsets.UTF_8))
	}

	@Test
	fun `사설주소로리디렉션되거나처음부터사설주소일때_가져오면_요청없이열지않는주소인지`() {
		// given
		val targets = listOf(url("/to-internal"), "http://[::1]:${server.address.port}/page", "http://internal.test/", "https://a:b@localhost/")

		// when
		val results = targets.map(fetcher::fetch)

		// then
		assertTrue(results.all { it == FetchResult.Blocked("disallowed_url") }, results.toString())
	}

	@Test
	fun `응답상태가401403404503일때_가져오면_로그인필요접근거부와다시시도로나누는지`() {
		// given
		val paths = listOf("/login", "/forbidden", "/gone", "/broken")

		// when
		val results = paths.map { fetcher.fetch(url(it)) }

		// then
		assertEquals(
			listOf(
				FetchResult.Blocked("login_required"),
				FetchResult.Blocked("access_denied"),
				FetchResult.Blocked("access_denied"),
				FetchResult.Transient("http 503"),
			),
			results,
		)
	}

	@Test
	fun `본문이2MB를넘을때_가져오면_상한에서끊고일부라고표시하는지`() {
		// given
		val target = url("/big")

		// when
		val result = fetcher.fetch(target)

		// then
		result as FetchResult.Fetched
		assertEquals(HttpLinkFetcher.MAX_BYTES, result.bytes.size)
		assertTrue(result.truncated)
	}

	@Test
	fun `검사뒤주소가사설IP로바뀌어도_연결하지않는지`() {
		// given: 검사 때는 공인(루프백), 그 뒤 이름 풀이는 사설 주소를 준다
		val target = "http://rebind.test:${server.address.port}/page"

		// when
		val result = fetcher.fetch(target)

		// then: 검사한 주소로 연결해 가져오고, 이름은 다시 풀지 않는다
		result as FetchResult.Fetched
		assertEquals("<title>안녕</title><p>본문</p>", String(result.bytes, Charsets.UTF_8))
		assertEquals(1, rebindLookups.get())
	}
}
