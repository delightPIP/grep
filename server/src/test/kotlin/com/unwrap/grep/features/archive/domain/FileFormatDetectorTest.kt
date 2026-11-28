package com.unwrap.grep.features.archive.domain

import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlin.test.Test
import kotlin.test.assertEquals

/** COM-004 값 표. 형식은 확장자가 아니라 내용으로 정한다(규칙 2). */
class FileFormatDetectorTest {

	private fun bytes(vararg values: Int) = ByteArray(values.size) { values[it].toByte() }

	private fun zip(vararg entries: String): ByteArray {
		val out = ByteArrayOutputStream()
		ZipOutputStream(out).use { zip ->
			entries.forEach {
				zip.putNextEntry(ZipEntry(it))
				zip.write("<x/>".toByteArray())
				zip.closeEntry()
			}
		}
		return out.toByteArray()
	}

	private fun ftyp(major: String, vararg compatible: String): ByteArray {
		val brands = (listOf(major, "\u0000\u0000\u0000\u0000") + compatible).joinToString("")
		val size = 8 + brands.length
		return bytes(0, 0, 0, size) + "ftyp".toByteArray() + brands.toByteArray(Charsets.ISO_8859_1) + ByteArray(16)
	}

	@Test
	fun `받는형식의시그니처일때_판별하면_그형식으로받는지`() {
		// given
		val samples = mapOf(
			FileFormat.PDF to "%PDF-1.7\n".toByteArray(),
			FileFormat.PNG to bytes(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0),
			FileFormat.JPEG to bytes(0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10),
			FileFormat.WEBP to "RIFF\u0000\u0000\u0000\u0000WEBPVP8 ".toByteArray(Charsets.ISO_8859_1),
			FileFormat.HEIC to ftyp("heic", "mif1", "heic"),
			FileFormat.DOCX to zip("[Content_Types].xml", "word/document.xml"),
		)

		// when
		val results = samples.mapValues { (_, content) -> FileFormatDetector.detect(content, "file.bin") }

		// then
		samples.keys.forEach { assertEquals(FileDetection.Accepted(it), results[it]) }
	}

	@Test
	fun `확장자와내용이다를때_판별하면_내용을따르는지`() {
		// given
		val pngNamedPdf = bytes(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)

		// when
		val result = FileFormatDetector.detect(pngNamedPdf, "report.pdf")

		// then
		assertEquals(FileDetection.Accepted(FileFormat.PNG), result)
	}

	@Test
	fun `UTF8글자파일일때_판별하면_md확장자는md로그밖은txt로받는지`() {
		// given
		val text = "# 제목\n본문입니다.\r\n\t들여쓰기".toByteArray()

		// when
		val asMd = FileFormatDetector.detect(text, "note.MD")
		val asTxt = FileFormatDetector.detect(text, "note.txt")
		val noExtension = FileFormatDetector.detect(text, "README")

		// then
		assertEquals(FileDetection.Accepted(FileFormat.MD), asMd)
		assertEquals(FileDetection.Accepted(FileFormat.TXT), asTxt)
		assertEquals(FileDetection.Accepted(FileFormat.TXT), noExtension)
	}

	@Test
	fun `UTF8이아닌바이트일때_판별하면_글자파일로받지않는지`() {
		// given
		val eucKr = "한글".toByteArray(charset("EUC-KR"))
		val binary = bytes(0x00, 0x01, 0x02, 0x03)

		// when
		val results = listOf(FileFormatDetector.detect(eucKr, "a.txt"), FileFormatDetector.detect(binary, "a.txt"))

		// then
		assertEquals(listOf(FileDetection.Rejected("txt"), FileDetection.Rejected("txt")), results)
	}

	@Test
	fun `받지않는형식일때_판별하면_내용에서찾은확장자로거절하는지`() {
		// given
		val samples = mapOf(
			"gif" to "GIF89a\u0001\u0000".toByteArray(Charsets.ISO_8859_1),
			"zip" to zip("a.txt"),
			"xlsx" to zip("[Content_Types].xml", "xl/workbook.xml"),
			"pptx" to zip("[Content_Types].xml", "ppt/presentation.xml"),
			"avif" to ftyp("avif", "mif1", "avif"),
			"mp4" to ftyp("isom", "mp41"),
		)

		// when
		val results = samples.mapValues { (_, content) -> FileFormatDetector.detect(content, "renamed.docx") }

		// then
		samples.keys.forEach { assertEquals(FileDetection.Rejected(it), results[it]) }
	}

	@Test
	fun `시그니처를모르는바이너리일때_판별하면_파일이름확장자로거절하는지`() {
		// given
		val unknown = bytes(0xD0, 0xCF, 0x11, 0xE0, 0x00, 0x00)

		// when
		val named = FileFormatDetector.detect(unknown, "보고서.HWP")
		val unnamed = FileFormatDetector.detect(unknown, "noext")

		// then
		assertEquals(FileDetection.Rejected("hwp"), named)
		assertEquals(FileDetection.Rejected("bin"), unnamed)
	}

	@Test
	fun `HTML파일을올리면_받지않는형식html로거절하는지`() {
		// given
		val html = "<html><head><title>글</title></head><body>본문</body></html>".toByteArray()

		// when
		val byName = FileFormatDetector.detect("그냥 글".toByteArray(), "page.HTM")
		val byContent = FileFormatDetector.detect(html, "page.html")

		// then
		assertEquals(FileDetection.Rejected("html"), byName)
		assertEquals(FileDetection.Rejected("html"), byContent)
	}

	@Test
	fun `이름이txt여도HTML내용이면_거절하는지`() {
		// given
		val withBomAndSpace = byteArrayOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte()) + "\n  <!doctype html>\n<html>".toByteArray()
		val upperHtml = "\r\n<HTML lang=\"ko\">".toByteArray()

		// when
		val first = FileFormatDetector.detect(withBomAndSpace, "메모.txt")
		val second = FileFormatDetector.detect(upperHtml, "메모.md")

		// then
		assertEquals(FileDetection.Rejected("html"), first)
		assertEquals(FileDetection.Rejected("html"), second)
	}

	@Test
	fun `북마크HTML이면_거절하는지`() {
		// given
		val bookmarks = "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n<DL><p>".toByteArray()

		// when
		val result = FileFormatDetector.detect(bookmarks, "grep-bookmarks-test")

		// then
		assertEquals(FileDetection.Rejected("html"), result)
	}

	@Test
	fun `HTML태그가본문중간에만있는글이면_txt와md판정을그대로두는지`() {
		// given
		val text = "메모 첫 줄\n예시: <html> 태그를 쓴다".toByteArray()

		// when
		val txt = FileFormatDetector.detect(text, "메모.txt")
		val md = FileFormatDetector.detect(text, "메모.md")

		// then
		assertEquals(FileDetection.Accepted(FileFormat.TXT), txt)
		assertEquals(FileDetection.Accepted(FileFormat.MD), md)
	}
}
