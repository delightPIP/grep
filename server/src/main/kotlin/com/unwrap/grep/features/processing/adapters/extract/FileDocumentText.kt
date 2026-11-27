package com.unwrap.grep.features.processing.adapters.extract

import com.unwrap.grep.features.processing.domain.DocumentText
import com.unwrap.grep.features.processing.domain.ExtractResult
import org.apache.pdfbox.Loader
import org.apache.pdfbox.pdmodel.encryption.InvalidPasswordException
import org.apache.pdfbox.text.PDFTextStripper
import org.springframework.stereotype.Component
import java.io.ByteArrayInputStream
import java.io.IOException
import java.util.zip.ZipException
import java.util.zip.ZipInputStream

/**
 * PDF는 PDFBox, docx는 표준 라이브러리(zip 안 word/document.xml)로 글자를 꺼낸다.
 * COM-004 표는 docx에 Tika를 적었지만, 본문 글자만 필요해 의존성을 더하지 않았다. 표·각주 글자는 빠질 수 있다.
 */
@Component
class FileDocumentText : DocumentText {

	override fun pdf(bytes: ByteArray): ExtractResult = try {
		Loader.loadPDF(bytes).use { document ->
			val pages = document.numberOfPages
			val stripper = PDFTextStripper().apply { endPage = MAX_PDF_PAGES }
			val text = stripper.getText(document).trim()
			when {
				text.isEmpty() -> ExtractResult.Unreadable
				pages > MAX_PDF_PAGES -> ExtractResult.Text(text, "앞 ${MAX_PDF_PAGES}쪽만 읽음")
				else -> ExtractResult.Text(text)
			}
		}
	} catch (e: InvalidPasswordException) {
		ExtractResult.Encrypted
	} catch (e: IOException) {
		ExtractResult.Unreadable
	}

	override fun docx(bytes: ByteArray): ExtractResult = try {
		val xml = documentXml(bytes) ?: return ExtractResult.Unreadable
		val text = xml
			.replace(PARAGRAPH_END, "\n")
			.replace(TAB, "\t")
			.let { RUN_TEXT.findAll(it).joinToString("") { match -> match.groupValues[1].ifEmpty { match.value } } }
			.let(::unescapeXml)
			.lines().joinToString("\n") { it.trim() }
			.trim()
		if (text.isEmpty()) ExtractResult.Unreadable else ExtractResult.Text(text)
	} catch (e: ZipException) {
		ExtractResult.Unreadable
	} catch (e: IOException) {
		ExtractResult.Unreadable
	}

	/** 압축 폭탄을 막으려고 document.xml은 [MAX_DOCX_XML_BYTES]까지만 읽는다. */
	private fun documentXml(bytes: ByteArray): String? {
		ZipInputStream(ByteArrayInputStream(bytes)).use { zip ->
			generateSequence { zip.nextEntry }.forEach { entry ->
				if (entry.name == "word/document.xml") return String(zip.readNBytes(MAX_DOCX_XML_BYTES), Charsets.UTF_8)
			}
		}
		return null
	}

	private fun unescapeXml(value: String): String = value
		.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'").replace("&amp;", "&")

	companion object {
		/** 앞에서부터 읽을 쪽 수(개발자 값). 넘으면 `(앞 N쪽만 읽음)`(ARC-004). */
		const val MAX_PDF_PAGES = 30
		const val MAX_DOCX_XML_BYTES = 10 * 1024 * 1024
		private val PARAGRAPH_END = Regex("</w:p>")
		private val TAB = Regex("<w:tab/>")

		/** `<w:t>글자</w:t>`의 글자, 또는 앞에서 바꿔 둔 줄바꿈·탭. */
		private val RUN_TEXT = Regex("<w:t(?:\\s[^>]*)?>([^<]*)</w:t>|\\n|\\t")
	}
}
