package com.unwrap.grep.shared.kernel

import java.net.IDN

/**
 * 한글 도메인(IDN) 주소를 java.net.URI가 읽을 수 있게 호스트만 퍼니코드(`xn--`)로 바꾼다(#117).
 * java.net.URI는 ASCII가 아닌 호스트를 읽지 못해 host를 null로 준다. 경로·쿼리의 한글은 URI가 그대로 읽으므로 두고,
 * 사용자 정보·포트도 그대로 둔다. 호스트가 ASCII면 원문 그대로, 바꿀 수 없는 호스트면 원문 그대로 준다(뒤 검사가 거른다).
 */
object IdnUrls {
	private val SCHEME_AND_REST = Regex("^([a-zA-Z][a-zA-Z0-9+.-]*://)([^/?#]*)(.*)$", RegexOption.DOT_MATCHES_ALL)

	fun toAsciiHost(url: String): String {
		val match = SCHEME_AND_REST.find(url) ?: return url
		val (scheme, authority, rest) = match.destructured
		val userInfo = authority.substringBeforeLast('@', "").let { if (it.isEmpty()) "" else "$it@" }
		val hostPort = authority.substringAfterLast('@')
		if (hostPort.startsWith("[")) return url
		val host = hostPort.substringBefore(':')
		if (host.all { it.code < 0x80 }) return url
		val port = hostPort.substring(host.length)
		val ascii = try {
			IDN.toASCII(host)
		} catch (_: IllegalArgumentException) {
			return url
		}
		return scheme + userInfo + ascii + port + rest
	}

	/** 사람에게 보일 호스트. 퍼니코드면 한글로 되돌린다. */
	fun toUnicodeHost(host: String): String = IDN.toUnicode(host)
}
