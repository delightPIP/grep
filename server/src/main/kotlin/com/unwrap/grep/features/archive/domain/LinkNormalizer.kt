package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.shared.kernel.IdnUrls
import java.net.URI
import java.net.URISyntaxException

/** [value]는 같은 링크 판정에만 쓰는 정규화 주소, [host]는 출처로 보여 줄 호스트다. */
data class NormalizedLink(val value: String, val host: String)

/**
 * COM-001 값 표대로 링크 주소를 정규화한다. http·https가 아니거나 호스트가 없으면 null(클라이언트가 글로 보낸다).
 * 값 표에 없는 부분(포트, 경로 대소문자, 퍼센트 인코딩)은 건드리지 않는다. 사용자 정보(`user@`)는 버린다.
 * 한글 도메인은 정규화 주소에서 퍼니코드(`xn--`)로 맞춰, 한글로 붙이든 퍼니코드로 붙이든 같은 링크로 본다. 출처 호스트는 한글로 보인다.
 */
object LinkNormalizer {
	private val TRACKING_PARAMS = setOf("fbclid", "gclid", "igsh", "si", "ref_src")
	private const val TRACKING_PREFIX = "utm_"
	private const val SHORT_YOUTUBE_HOST = "youtu.be"

	fun normalize(raw: String): NormalizedLink? {
		val uri = try {
			URI(IdnUrls.toAsciiHost(raw.trim()))
		} catch (_: URISyntaxException) {
			return null
		}
		if (uri.scheme?.lowercase() !in setOf("http", "https")) return null
		val rawHost = uri.host?.lowercase()?.takeIf { it.isNotEmpty() } ?: return null

		var host = rawHost.removePrefix("www.")
		var path = uri.rawPath.orEmpty()
		val params = uri.rawQuery.orEmpty().split('&').filter { it.isNotEmpty() }.toMutableList()

		if (host == SHORT_YOUTUBE_HOST) {
			val videoId = path.trim('/')
			if (videoId.isNotEmpty() && '/' !in videoId) {
				host = "youtube.com"
				path = "/watch"
				params += "v=$videoId"
			}
		}

		path = path.removeSuffix("/")
		val query = params
			.filterNot { isTracking(it.substringBefore('=')) }
			.sortedBy { it.substringBefore('=') }
			.joinToString("&")
		val port = if (uri.port == -1) "" else ":${uri.port}"
		val fragment = uri.rawFragment?.takeIf { it.startsWith("/") }

		val value = buildString {
			append("https://").append(host).append(port).append(path)
			if (query.isNotEmpty()) append('?').append(query)
			if (fragment != null) append('#').append(fragment)
		}
		return NormalizedLink(value, IdnUrls.toUnicodeHost(host))
	}

	/**
	 * 사람이 열 주소(handoff-format 2절 출처). [normalize]와 달리 추적용 꼬리표만 빼고 나머지는 그대로 둔다.
	 * 남은 매개변수가 없으면 `?`도 뺀다.
	 */
	fun withoutTracking(raw: String): String {
		val trimmed = raw.trim()
		val hashAt = trimmed.indexOf('#')
		val beforeFragment = if (hashAt < 0) trimmed else trimmed.substring(0, hashAt)
		val fragment = if (hashAt < 0) "" else trimmed.substring(hashAt)
		val queryAt = beforeFragment.indexOf('?')
		if (queryAt < 0) return trimmed
		val kept = beforeFragment.substring(queryAt + 1).split('&')
			.filter { it.isNotEmpty() && !isTracking(it.substringBefore('=')) }
		val query = if (kept.isEmpty()) "" else "?" + kept.joinToString("&")
		return beforeFragment.substring(0, queryAt) + query + fragment
	}

	private fun isTracking(name: String): Boolean {
		val lower = name.lowercase()
		return lower.startsWith(TRACKING_PREFIX) || lower in TRACKING_PARAMS
	}
}
