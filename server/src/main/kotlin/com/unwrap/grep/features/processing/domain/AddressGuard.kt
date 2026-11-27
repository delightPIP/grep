package com.unwrap.grep.features.processing.domain

import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.URI

/**
 * ARC-006 열지 않는 주소: 사설망·로컬·클라우드 관리용 주소, 주소 안 아이디·비밀번호, http(s)가 아닌 주소.
 * 리디렉션마다 다시 부른다(규칙 4).
 */
object AddressGuard {
	private val ALLOWED_SCHEMES = setOf("http", "https")

	/** 주소 모양만 본다. 호스트 이름 풀이는 [isPublic]으로 따로 한다. */
	fun isAllowedUri(uri: URI): Boolean =
		uri.scheme?.lowercase() in ALLOWED_SCHEMES && !uri.host.isNullOrEmpty() && uri.rawUserInfo == null

	/** 공인 주소만 true. 사설·루프백·링크 로컬(169.254 클라우드 메타데이터 포함)·멀티캐스트·CGNAT·IPv6 ULA는 막는다. */
	fun isPublic(address: InetAddress): Boolean {
		if (address.isAnyLocalAddress || address.isLoopbackAddress || address.isLinkLocalAddress ||
			address.isSiteLocalAddress || address.isMulticastAddress
		) return false
		val bytes = address.address
		return when (address) {
			is Inet4Address -> isPublicV4(bytes.map { it.toInt() and 0xFF })
			is Inet6Address -> (bytes[0].toInt() and 0xFE) != 0xFC
			else -> false
		}
	}

	private fun isPublicV4(octets: List<Int>): Boolean {
		val (a, b) = octets
		return when {
			a == 0 -> false
			a == 100 && b in 64..127 -> false // CGNAT 100.64.0.0/10
			a == 192 && b == 0 && octets[2] == 0 -> false // 192.0.0.0/24
			a == 198 && b in 18..19 -> false // 198.18.0.0/15
			a >= 240 -> false // 예약·브로드캐스트
			else -> true
		}
	}
}
