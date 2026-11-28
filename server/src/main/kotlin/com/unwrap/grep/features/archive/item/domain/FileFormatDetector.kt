package com.unwrap.grep.features.archive.item.domain

import java.io.ByteArrayInputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.util.zip.ZipException
import java.util.zip.ZipInputStream

/** COM-004 값 표의 받는 형식. value는 DB `file_format`과 openapi `UploadLimits.formats` 값이다. */
enum class FileFormat(val value: String) {
	PDF("pdf"), MD("md"), TXT("txt"), DOCX("docx"), PNG("png"), JPEG("jpeg"), WEBP("webp"), HEIC("heic");
}

sealed interface FileDetection {
	data class Accepted(val format: FileFormat) : FileDetection

	/** 받지 않는 형식. [fileExtension]은 점 없이(`zip`). */
	data class Rejected(val fileExtension: String) : FileDetection
}

/**
 * 형식은 확장자가 아니라 내용으로 정한다(COM-004 규칙 2). md와 txt는 내용으로 구분되지 않아
 * UTF-8 글자 파일이면 파일 이름이 `.md`·`.markdown`일 때 md, 그 밖은 txt로 둔다.
 * HTML(북마크 내보내기 포함)은 받지 않는다. 이름이 `.html`·`.htm`이거나, 앞부분(BOM·공백 뒤)이 `<!doctype`·`<html`이면
 * `html`로 거절한다(#172 실측: 버킷 형식 제한을 비운 뒤 HTML이 txt로 저장됨).
 */
object FileFormatDetector {
	private val PNG = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
	private val JPEG = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte())
	private val PDF = "%PDF-".toByteArray(Charsets.US_ASCII)
	private val ZIP = byteArrayOf(0x50, 0x4B, 0x03, 0x04)
	private val HEIC_BRANDS = setOf("heic", "heix", "heim", "heis", "hevc", "hevx", "hevm", "hevs")
	private val AVIF_BRANDS = setOf("avif", "avis")
	private val MARKDOWN_EXTENSIONS = setOf("md", "markdown")
	private const val UNKNOWN_EXTENSION = "bin"
	private const val HTML_EXTENSION = "html"
	private val HTML_EXTENSIONS = setOf("html", "htm")
	private val HTML_STARTS = listOf("<!doctype", "<html")

	/** 앞부분만 본다. BOM·공백 뒤 첫 글자들만 필요하다. */
	private const val HTML_SNIFF_BYTES = 1024
	private const val BOM = '\uFEFF'

	fun detect(bytes: ByteArray, fileName: String): FileDetection = when {
		bytes.startsWith(PDF) -> FileDetection.Accepted(FileFormat.PDF)
		bytes.startsWith(PNG) -> FileDetection.Accepted(FileFormat.PNG)
		bytes.startsWith(JPEG) -> FileDetection.Accepted(FileFormat.JPEG)
		bytes.ascii(0, 4) == "RIFF" && bytes.ascii(8, 4) == "WEBP" -> FileDetection.Accepted(FileFormat.WEBP)
		bytes.ascii(0, 4).let { it == "GIF8" } -> FileDetection.Rejected("gif")
		bytes.ascii(4, 4) == "ftyp" -> detectIsoMedia(bytes)
		bytes.startsWith(ZIP) -> detectZip(bytes)
		isUtf8Text(bytes) && isHtml(bytes, fileName) -> FileDetection.Rejected(HTML_EXTENSION)
		isUtf8Text(bytes) -> FileDetection.Accepted(
			if (extensionOf(fileName) in MARKDOWN_EXTENSIONS) FileFormat.MD else FileFormat.TXT,
		)
		else -> FileDetection.Rejected(extensionOf(fileName) ?: UNKNOWN_EXTENSION)
	}

	/** ISO BMFF `ftyp` 상자의 주 브랜드와 호환 브랜드로 HEIC를 가린다. */
	private fun detectIsoMedia(bytes: ByteArray): FileDetection {
		val boxSize = ByteBuffer.wrap(bytes, 0, 4).int.coerceIn(16, bytes.size)
		val brands = buildList {
			add(bytes.ascii(8, 4))
			var offset = 16
			while (offset + 4 <= boxSize) {
				add(bytes.ascii(offset, 4))
				offset += 4
			}
		}
		return when {
			brands.any { it in HEIC_BRANDS } -> FileDetection.Accepted(FileFormat.HEIC)
			brands.any { it in AVIF_BRANDS } -> FileDetection.Rejected("avif")
			brands.first() == "qt  " -> FileDetection.Rejected("mov")
			else -> FileDetection.Rejected("mp4")
		}
	}

	/** docx는 ZIP 안에 word/document.xml이 있다. xlsx·pptx와 그냥 zip은 받지 않는다. */
	private fun detectZip(bytes: ByteArray): FileDetection {
		val names = try {
			ZipInputStream(ByteArrayInputStream(bytes)).use { zip ->
				generateSequence { zip.nextEntry }.map { it.name }.toList()
			}
		} catch (_: ZipException) {
			emptyList()
		} catch (_: IOException) {
			emptyList()
		}
		return when {
			"word/document.xml" in names -> FileDetection.Accepted(FileFormat.DOCX)
			names.any { it.startsWith("xl/") } -> FileDetection.Rejected("xlsx")
			names.any { it.startsWith("ppt/") } -> FileDetection.Rejected("pptx")
			else -> FileDetection.Rejected("zip")
		}
	}

	private fun isHtml(bytes: ByteArray, fileName: String): Boolean {
		if (extensionOf(fileName) in HTML_EXTENSIONS) return true
		val head = String(bytes, 0, minOf(bytes.size, HTML_SNIFF_BYTES), Charsets.UTF_8)
			.trimStart { it == BOM || it.isWhitespace() }
			.lowercase()
		return HTML_STARTS.any { head.startsWith(it) }
	}

	/** 올바른 UTF-8이고 탭·줄바꿈·폼피드 밖의 제어 문자가 없으면 글자 파일이다. */
	private fun isUtf8Text(bytes: ByteArray): Boolean {
		val text = try {
			Charsets.UTF_8.newDecoder()
				.onMalformedInput(CodingErrorAction.REPORT)
				.onUnmappableCharacter(CodingErrorAction.REPORT)
				.decode(ByteBuffer.wrap(bytes))
		} catch (_: CharacterCodingException) {
			return false
		}
		return text.none { it.code < 0x20 && it !in "\t\n\r\u000C" || it.code == 0x7F }
	}

	private fun extensionOf(fileName: String): String? =
		fileName.substringAfterLast('.', "").lowercase().takeIf { it.isNotEmpty() && it.length <= 10 }

	private fun ByteArray.startsWith(prefix: ByteArray): Boolean =
		size >= prefix.size && prefix.indices.all { this[it] == prefix[it] }

	private fun ByteArray.ascii(offset: Int, length: Int): String =
		if (offset + length > size) "" else String(this, offset, length, Charsets.ISO_8859_1)
}
