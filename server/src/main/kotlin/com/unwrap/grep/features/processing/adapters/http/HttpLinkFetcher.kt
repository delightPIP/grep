package com.unwrap.grep.features.processing.adapters.http

import com.unwrap.grep.features.processing.domain.AddressGuard
import com.unwrap.grep.features.processing.domain.FetchResult
import com.unwrap.grep.features.processing.domain.LinkFetcher
import com.unwrap.grep.shared.kernel.IdnUrls
import org.apache.hc.client5.http.DnsResolver
import org.apache.hc.client5.http.classic.methods.HttpGet
import org.apache.hc.client5.http.config.ConnectionConfig
import org.apache.hc.client5.http.config.RequestConfig
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient
import org.apache.hc.client5.http.impl.classic.HttpClients
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManagerBuilder
import org.apache.hc.client5.http.routing.RoutingSupport
import org.apache.hc.core5.http.ClassicHttpResponse
import org.apache.hc.core5.util.Timeout
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Component
import java.io.IOException
import java.io.InterruptedIOException
import java.net.IDN
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URI
import java.net.URISyntaxException
import java.net.UnknownHostException
import java.time.Duration

/**
 * ARC-006 공개 페이지 가져오기. 쿠키·인증 정보를 싣지 않고(규칙 2), 리디렉션은 직접 따라가며 주소마다 다시 검사한다(규칙 4).
 * 이름은 주소마다 한 번만 풀고, 검사를 통과한 그 IP로만 연결한다(DNS 재바인딩 막기, #117).
 * [isPublic]은 테스트가 로컬 서버를 공인 주소처럼 다룰 때만 바꾼다.
 */
@Component
class HttpLinkFetcher internal constructor(
	private val resolve: (String) -> List<InetAddress>,
	private val isPublic: (InetAddress) -> Boolean = AddressGuard::isPublic,
) : LinkFetcher {

	@Autowired
	constructor() : this({ host -> InetAddress.getAllByName(host).toList() })

	override fun fetch(url: String): FetchResult {
		var current = parse(url) ?: return FetchResult.Blocked(DISALLOWED)
		val pinned = PinnedDns()
		client(pinned).use { client ->
			repeat(MAX_REDIRECTS + 1) {
				when (val checked = checkAddress(current)) {
					is Checked.Refused -> return checked.result
					is Checked.Allowed -> pinned.pin(current.host, checked.addresses)
				}
				val get = request(current)
				val step = try {
					// 읽고 나면 연결을 끊는다. 남은 본문(상한 넘는 본문, 리디렉션 본문)을 끝까지 받지 않는다.
					client.executeOpen(RoutingSupport.determineHost(get), get, null).use { response ->
						try {
							read(current, response)
						} finally {
							get.cancel()
						}
					}
				} catch (e: InterruptedIOException) {
					return FetchResult.Transient("timeout")
				} catch (e: IOException) {
					return FetchResult.Transient("io: ${e.javaClass.simpleName}")
				}
				when (step) {
					is Step.Done -> return step.result
					is Step.Redirect -> current = step.next ?: return FetchResult.Blocked(DISALLOWED)
				}
			}
		}
		return FetchResult.Failed("too many redirects")
	}

	private sealed interface Step {
		data class Done(val result: FetchResult) : Step
		data class Redirect(val next: URI?) : Step
	}

	private fun read(current: URI, response: ClassicHttpResponse): Step {
		val status = response.code
		if (status in 300..399) {
			val location = response.getFirstHeader("location")?.value
				?: return Step.Done(FetchResult.Failed("redirect without location"))
			return Step.Redirect(resolveRedirect(current, location))
		}
		return Step.Done(
			when {
				status == 401 -> FetchResult.Blocked("login_required")
				status == 408 || status == 429 || status >= 500 -> FetchResult.Transient("http $status")
				status >= 400 -> FetchResult.Blocked("access_denied")
				else -> {
					val bytes = response.entity?.content?.use { it.readNBytes(MAX_BYTES + 1) } ?: ByteArray(0)
					val contentType = response.getFirstHeader("content-type")?.value.orEmpty()
					FetchResult.Fetched(
						bytes = if (bytes.size > MAX_BYTES) bytes.copyOf(MAX_BYTES) else bytes,
						mediaType = contentType.substringBefore(';').trim().lowercase(),
						charset = CHARSET.find(contentType)?.groupValues?.get(1)?.trim('"', '\''),
						truncated = bytes.size > MAX_BYTES,
					)
				}
			},
		)
	}

	private sealed interface Checked {
		data class Allowed(val addresses: List<InetAddress>) : Checked
		data class Refused(val result: FetchResult) : Checked
	}

	/** 열지 않는 주소면 Blocked, 이름을 못 풀면 Failed. 풀린 주소가 하나라도 공인이 아니면 막는다. */
	private fun checkAddress(uri: URI): Checked {
		if (!AddressGuard.isAllowedUri(uri)) return Checked.Refused(FetchResult.Blocked(DISALLOWED))
		val addresses = try {
			resolve(uri.host)
		} catch (e: UnknownHostException) {
			return Checked.Refused(FetchResult.Failed("unknown host"))
		}
		if (addresses.isEmpty() || !addresses.all(isPublic)) return Checked.Refused(FetchResult.Blocked(DISALLOWED))
		return Checked.Allowed(addresses)
	}

	/**
	 * 검사한 주소만 돌려준다. 검사하지 않은 이름은 풀지 않는다.
	 * HttpClient가 퍼니코드 호스트를 한글로 되돌려 물을 수 있어 열쇠는 퍼니코드 소문자로 맞춘다.
	 */
	private class PinnedDns : DnsResolver {
		private val addresses = mutableMapOf<String, Array<InetAddress>>()

		fun pin(host: String, checked: List<InetAddress>) {
			addresses[key(host)] = checked.toTypedArray()
		}

		override fun resolve(host: String): Array<InetAddress> =
			addresses[key(host)]?.clone() ?: throw UnknownHostException("not checked: $host")

		private fun key(host: String): String = IDN.toASCII(host).lowercase()

		override fun resolve(host: String, port: Int): List<InetSocketAddress> =
			resolve(host).map { InetSocketAddress(it, port) }

		override fun resolveCanonicalHostname(host: String): String = host
	}

	/** 가져오기 한 번에 하나. 연결 풀을 다른 가져오기와 나누지 않아 고정한 주소가 섞이지 않는다. */
	private fun client(dns: DnsResolver): CloseableHttpClient {
		val connections = PoolingHttpClientConnectionManagerBuilder.create()
			.setDnsResolver(dns)
			.setDefaultConnectionConfig(
				ConnectionConfig.custom()
					.setConnectTimeout(Timeout.of(CONNECT_TIMEOUT))
					.setSocketTimeout(Timeout.of(REQUEST_TIMEOUT))
					.build(),
			)
			.build()
		return HttpClients.custom()
			.setConnectionManager(connections)
			.disableRedirectHandling()
			.disableCookieManagement()
			.disableAuthCaching()
			.disableAutomaticRetries()
			.setDefaultRequestConfig(RequestConfig.custom().setResponseTimeout(Timeout.of(REQUEST_TIMEOUT)).build())
			.build()
	}

	private fun request(uri: URI): HttpGet = HttpGet(uri).apply {
		setHeader("User-Agent", USER_AGENT)
		setHeader("Accept", "text/html,application/xhtml+xml,text/plain;q=0.9,application/pdf;q=0.8,*/*;q=0.1")
	}

	/** 한글 도메인은 퍼니코드 호스트로 바꿔 읽는다. 리디렉션 Location도 같다. */
	private fun parse(url: String): URI? = try {
		URI(IdnUrls.toAsciiHost(url.trim()))
	} catch (e: URISyntaxException) {
		null
	}

	private fun resolveRedirect(base: URI, location: String): URI? = try {
		base.resolve(URI(IdnUrls.toAsciiHost(location.trim())))
	} catch (e: URISyntaxException) {
		null
	} catch (e: IllegalArgumentException) {
		null
	}

	companion object {
		/**
		 * ARC-006 값(개발자 값): 연결 5초, 응답 10초, 본문 2MB, 리디렉션 5번.
		 * 응답 10초는 바이트 사이 대기 상한이다(Apache HttpClient에는 요청 전체 상한이 없다).
		 */
		val CONNECT_TIMEOUT: Duration = Duration.ofSeconds(5)
		val REQUEST_TIMEOUT: Duration = Duration.ofSeconds(10)
		const val MAX_BYTES = 2 * 1024 * 1024
		const val MAX_REDIRECTS = 5
		const val DISALLOWED = "disallowed_url"
		private const val USER_AGENT = "grep-fetcher/0.1"
		private val CHARSET = Regex("(?i)charset\\s*=\\s*([^;\\s]+)")
	}
}
