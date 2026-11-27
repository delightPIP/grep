package com.unwrap.grep.features.processing.adapters.extract

import com.unwrap.grep.features.processing.domain.ExtractResult
import org.apache.pdfbox.pdmodel.PDDocument
import org.apache.pdfbox.pdmodel.PDPage
import org.apache.pdfbox.pdmodel.PDPageContentStream
import org.apache.pdfbox.pdmodel.encryption.AccessPermission
import org.apache.pdfbox.pdmodel.encryption.StandardProtectionPolicy
import org.apache.pdfbox.pdmodel.font.PDType1Font
import org.apache.pdfbox.pdmodel.font.Standard14Fonts
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** PDF·docx 글자 꺼내기. 근거: COM-004 규칙 6·형식 표, ARC-004 규칙 8. */
class FileDocumentTextTest {
	private val extractor = FileDocumentText()

	private fun pdf(pages: Int, text: String?, password: String? = null): ByteArray = PDDocument().use { doc ->
		repeat(pages) { index ->
			val page = PDPage().also(doc::addPage)
			if (text != null) {
				PDPageContentStream(doc, page).use { stream ->
					stream.beginText()
					stream.setFont(PDType1Font(Standard14Fonts.FontName.HELVETICA), 12f)
					stream.newLineAtOffset(50f, 700f)
					stream.showText("$text ${index + 1}")
					stream.endText()
				}
			}
		}
		if (password != null) doc.protect(StandardProtectionPolicy(password, password, AccessPermission()))
		ByteArrayOutputStream().also(doc::save).toByteArray()
	}

	private fun docx(documentXml: String): ByteArray = ByteArrayOutputStream().also { out ->
		ZipOutputStream(out).use { zip ->
			zip.putNextEntry(ZipEntry("word/document.xml"))
			zip.write(documentXml.toByteArray())
			zip.closeEntry()
		}
	}.toByteArray()

	@Test
	fun `글자가있는PDF일때_꺼내면_글자를주는지`() {
		// given
		val bytes = pdf(2, "Winter drinks")

		// when
		val result = extractor.pdf(bytes)

		// then
		result as ExtractResult.Text
		assertTrue("Winter drinks 1" in result.text && "Winter drinks 2" in result.text)
		assertEquals(null, result.partialNote)
	}

	@Test
	fun `30쪽넘는PDF일때_꺼내면_앞30쪽만읽고일부표시를주는지`() {
		// given
		val bytes = pdf(31, "Page")

		// when
		val result = extractor.pdf(bytes)

		// then
		result as ExtractResult.Text
		assertTrue("Page 30" in result.text)
		assertTrue("Page 31" !in result.text)
		assertEquals("앞 30쪽만 읽음", result.partialNote)
	}

	@Test
	fun `암호걸린PDF와글자없는PDF일때_꺼내면_암호와글자없음으로나누는지`() {
		// given
		val encrypted = pdf(1, "secret", password = "pw")
		val empty = pdf(1, null)

		// when
		val results = listOf(extractor.pdf(encrypted), extractor.pdf(empty), extractor.pdf("not a pdf".toByteArray()))

		// then
		assertEquals(listOf(ExtractResult.Encrypted, ExtractResult.Unreadable, ExtractResult.Unreadable), results)
	}

	@Test
	fun `문단과탭이있는docx일때_꺼내면_문단마다줄을나누고엔티티를푸는지`() {
		// given
		val xml = """<w:document><w:body><w:p><w:r><w:t>결제 위젯</w:t></w:r><w:r><w:t xml:space="preserve"> 비교 &amp; 정리</w:t></w:r></w:p><w:p><w:r><w:t>둘째</w:t><w:tab/><w:t>칸</w:t></w:r></w:p></w:body></w:document>"""

		// when
		val result = extractor.docx(docx(xml))

		// then
		assertEquals(ExtractResult.Text("결제 위젯 비교 & 정리\n둘째\t칸"), result)
	}

	@Test
	fun `docx가아니거나글자가없을때_꺼내면_글자없음인지`() {
		// given
		val inputs = listOf("plain".toByteArray(), docx("<w:document><w:body><w:p/></w:body></w:document>"))

		// when
		val results = inputs.map(extractor::docx)

		// then
		assertEquals(listOf(ExtractResult.Unreadable, ExtractResult.Unreadable), results)
	}
}
