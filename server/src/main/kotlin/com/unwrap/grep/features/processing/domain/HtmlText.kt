package com.unwrap.grep.features.processing.domain

import org.jsoup.Jsoup
import org.jsoup.nodes.Element
import org.jsoup.nodes.Node
import org.jsoup.nodes.TextNode
import org.jsoup.select.NodeTraversor
import org.jsoup.select.NodeVisitor

/** 가져온 HTML에서 제목과 읽을 글만 꺼낸다. */
data class HtmlPage(val title: String?, val text: String)

/**
 * jsoup으로 읽는다(#117). 스크립트·메뉴·머리글·바닥글을 걷어내고, 본문 영역(`article`·`main`)이 있으면 그 안만 읽는다.
 * 블록 요소와 `br`마다 줄을 바꾼다.
 */
object HtmlText {
	private const val DROP = "script, style, noscript, svg, template, iframe, nav, header, footer, aside, form, [role=navigation]"
	private val MAIN_AREAS = listOf("article", "main", "[role=main]")
	private val SPACES = Regex("[ \\t\\u00A0]+")
	private val BLANK_LINES = Regex("\\n\\s*\\n+")

	fun parse(html: String): HtmlPage {
		val doc = Jsoup.parse(html)
		val title = doc.selectFirst("meta[property=og:title]")?.attr("content")?.let(::oneLine)
			?: oneLine(doc.title())
		doc.select(DROP).remove()
		val body = doc.body()
		val root = MAIN_AREAS.firstNotNullOfOrNull { area -> body.select(area).maxByOrNull { it.text().length } }
			?.takeIf { it.text().isNotBlank() }
			?: body
		return HtmlPage(title, blockText(root))
	}

	private fun blockText(root: Element): String {
		val out = StringBuilder()
		NodeTraversor.traverse(
			object : NodeVisitor {
				override fun head(node: Node, depth: Int) {
					when {
						node is TextNode -> out.append(node.text())
						node is Element && (node.isBlock || node.nameIs("br")) -> out.append('\n')
					}
				}

				override fun tail(node: Node, depth: Int) {
					if (node is Element && node.isBlock) out.append('\n')
				}
			},
			root,
		)
		return out.lines().joinToString("\n") { it.replace(SPACES, " ").trim() }
			.replace(BLANK_LINES, "\n")
			.trim()
	}

	private fun oneLine(value: String): String? = value.replace(Regex("\\s+"), " ").trim().takeIf { it.isNotEmpty() }
}
