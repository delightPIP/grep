package com.unwrap.grep.features.processing.domain

/** 가져온 HTML에서 제목과 읽을 글만 꺼낸다. */
data class HtmlPage(val title: String?, val text: String)

/**
 * shortcut: HTML 파서 없이 정규식으로 태그를 걷어낸다. 본문 영역(article 등)을 고르지 않아 메뉴 글자도 섞인다.
 * 요약 품질이 데모에서 모자라면 jsoup으로 바꾼다.
 */
object HtmlText {
	private val DROP_BLOCKS = Regex("(?is)<(script|style|noscript|svg|template|head)\\b.*?</\\1\\s*>")
	private val COMMENTS = Regex("(?s)<!--.*?-->")
	private val BREAKS = Regex("(?i)<(br|/p|/div|/li|/h[1-6]|/tr|/section|/article)\\b[^>]*>")
	private val TAGS = Regex("(?s)<[^>]+>")
	private val OG_TITLE = Regex("(?is)<meta\\s[^>]*property\\s*=\\s*[\"']og:title[\"'][^>]*>")
	private val CONTENT_ATTR = Regex("(?is)content\\s*=\\s*(\"([^\"]*)\"|'([^']*)')")
	private val TITLE = Regex("(?is)<title[^>]*>(.*?)</title\\s*>")
	private val NUMERIC_ENTITY = Regex("&#(x?)([0-9a-fA-F]+);")
	private val SPACES = Regex("[ \\t\\u00A0]+")
	private val BLANK_LINES = Regex("\\n\\s*\\n+")
	/** `&amp;`는 마지막에 풀어야 `&amp;lt;`가 `<`로 두 번 풀리지 않는다. */
	private val NAMED = linkedMapOf("&lt;" to "<", "&gt;" to ">", "&quot;" to "\"", "&apos;" to "'", "&nbsp;" to " ", "&amp;" to "&")

	fun parse(html: String): HtmlPage {
		val text = html
			.replace(COMMENTS, " ")
			.replace(DROP_BLOCKS, " ")
			.replace(BREAKS, "\n")
			.replace(TAGS, " ")
			.let(::decode)
			.lines().joinToString("\n") { it.replace(SPACES, " ").trim() }
			.replace(BLANK_LINES, "\n")
			.trim()
		return HtmlPage(title(html), text)
	}

	private fun title(html: String): String? {
		val og = OG_TITLE.find(html)?.value?.let { CONTENT_ATTR.find(it) }?.let { it.groupValues[2].ifEmpty { it.groupValues[3] } }
		val raw = og?.takeIf { it.isNotBlank() } ?: TITLE.find(html)?.groupValues?.get(1)
		return raw?.let(::decode)?.replace(Regex("\\s+"), " ")?.trim()?.takeIf { it.isNotEmpty() }
	}

	private fun decode(value: String): String {
		val numeric = NUMERIC_ENTITY.replace(value) { match ->
			val code = match.groupValues[2].toIntOrNull(if (match.groupValues[1].isEmpty()) 10 else 16)
			if (code != null && Character.isValidCodePoint(code)) String(Character.toChars(code)) else match.value
		}
		return NAMED.entries.fold(numeric) { acc, (entity, char) -> acc.replace(entity, char) }
	}
}
