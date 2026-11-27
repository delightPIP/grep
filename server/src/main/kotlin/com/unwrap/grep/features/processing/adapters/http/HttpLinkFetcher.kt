package com.unwrap.grep.features.processing.adapters.http

import com.unwrap.grep.features.processing.domain.AddressGuard
import com.unwrap.grep.features.processing.domain.FetchResult
import com.unwrap.grep.features.processing.domain.LinkFetcher
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Component
import java.io.IOException
import java.net.InetAddress
import java.net.URI
import java.net.URISyntaxException
import java.net.UnknownHostException
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.net.http.HttpTimeoutException
import java.time.Duration

/**
 * ARC-006 공개 페이지 가져오기. 쿠키·인증 정보를 싣지 않고(규칙 2), 리디렉션은 직접 따라가며 주소마다 다시 검사한다(규칙 4).
 * shortcut: 검사한 IP와 HttpClient가 다시 푼 IP가 다를 수 있다(DNS 재바인딩). 공개 배포 전에 검사한 IP로 직접 연결하게 바꾼다.
 */
@Component
class HttpLinkFetcher internal constructor(private val resolve: (String) -> List<InetAddress>) : LinkFetcher {

	/** 테스트는 이름 풀이를 바꿔 로컬 서버를 공인 주소처럼 다룬다. */
	@Autowired
	constructor() : this({ host -> InetAddress.getAllByName(host).toList() })

	private val client = HttpClient.newBuilder()
		.followRedirects(HttpClient.Redirect.NEVER)
		.connectTimeout(CONNECT_TIMEOUT)
		.build()

	override fun fetch(url: String): FetchResult {
		var current = parse(url) ?: return FetchResult.Blocked(DISALLOWED)
		repeat(MAX_REDIRECTS + 1) {
			checkAddress(current)?.let { return it }
			val response = try {
				client.send(request(current), HttpResponse.BodyHandlers.ofInputStream())
			} catch (e: HttpTimeoutException) {
				return FetchResult.Transient("timeout")
			} catch (e: IOException) {
				return FetchResult.Transient("io: ${e.javaClass.simpleName}")
			}
			val status = response.statusCode()
			if (status in 300..399) {
				response.body().close()
				val location = response.headers().firstValue("location").orElse(null)
					?: return FetchResult.Failed("redirect without location")
				current = resolveRedirect(current, location) ?: return FetchResult.Blocked(DISALLOWED)
				return@repeat
			}
			return response.body().use { body ->
				when {
					status == 401 -> FetchResult.Blocked("login_required")
					status == 408 || status == 429 || status >= 500 -> FetchResult.Transient("http $status")
					status >= 400 -> FetchResult.Blocked("access_denied")
					else -> {
						val bytes = body.readNBytes(MAX_BYTES + 1)
						val contentType = response.headers().firstValue("content-type").orElse("")
						FetchResult.Fetched(
							bytes = if (bytes.size > MAX_BYTES) bytes.copyOf(MAX_BYTES) else bytes,
							mediaType = contentType.substringBefore(';').trim().lowercase(),
							charset = CHARSET.find(contentType)?.groupValues?.get(1)?.trim('"', '\''),
							truncated = bytes.size > MAX_BYTES,
						)
					}
				}
			}
		}
		return FetchResult.Failed("too many redirects")
	}

	/** 열지 않는 주소면 Blocked, 이름을 못 풀면 Failed, 괜찮으면 null. */
	private fun checkAddress(uri: URI): FetchResult? {
		if (!AddressGuard.isAllowedUri(uri)) return FetchResult.Blocked(DISALLOWED)
		val addresses = try {
			resolve(uri.host)
		} catch (e: UnknownHostException) {
			return FetchResult.Failed("unknown host")
		}
		return if (addresses.isEmpty() || !addresses.all(AddressGuard::isPublic)) FetchResult.Blocked(DISALLOWED) else null
	}

	private fun request(uri: URI): HttpRequest = HttpRequest.newBuilder(uri)
		.timeout(REQUEST_TIMEOUT)
		.header("User-Agent", USER_AGENT)
		.header("Accept", "text/html,application/xhtml+xml,text/plain;q=0.9,application/pdf;q=0.8,*/*;q=0.1")
		.GET()
		.build()

	private fun parse(url: String): URI? = try {
		URI(url.trim())
	} catch (e: URISyntaxException) {
		null
	}

	private fun resolveRedirect(base: URI, location: String): URI? = try {
		base.resolve(URI(location.trim()))
	} catch (e: URISyntaxException) {
		null
	} catch (e: IllegalArgumentException) {
		null
	}

	companion object {
		/** ARC-006 값(개발자 값): 연결 5초, 응답 10초, 본문 2MB, 리디렉션 5번. */
		val CONNECT_TIMEOUT: Duration = Duration.ofSeconds(5)
		val REQUEST_TIMEOUT: Duration = Duration.ofSeconds(10)
		const val MAX_BYTES = 2 * 1024 * 1024
		const val MAX_REDIRECTS = 5
		const val DISALLOWED = "disallowed_url"
		private const val USER_AGENT = "grep-fetcher/0.1"
		private val CHARSET = Regex("(?i)charset\\s*=\\s*([^;\\s]+)")
	}
}
