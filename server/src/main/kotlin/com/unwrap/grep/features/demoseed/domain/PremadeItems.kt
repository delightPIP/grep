package com.unwrap.grep.features.demoseed.domain

import com.unwrap.grep.features.archive.api.ItemBody
import com.unwrap.grep.features.archive.item.domain.FileFormat
import com.unwrap.grep.features.archive.item.domain.ItemKind
import com.unwrap.grep.features.archive.item.domain.LinkNormalizer
import com.unwrap.grep.features.archive.item.domain.ObjectStorage
import com.unwrap.grep.features.archive.item.domain.StoredFile
import java.security.MessageDigest
import java.time.Instant
import java.util.HexFormat
import java.util.UUID

/** 원본 파일 한 개. 자료 행을 넣기 전에 스토리지에 올린다. */
class PremadeUpload(val objectPath: String, val bytes: ByteArray, val contentType: String)

class PremadeItem(val row: SeedRow, val upload: PremadeUpload?)

/**
 * 미리 만든 자료(데모 시드 #69, 샘플 ARC-010)를 넣을 값으로 바꾼다. 요약·태그·본문은 seed.json 값을 그대로 쓰고 LLM은 부르지 않는다.
 * [read]는 seed.json 기준 상대 경로의 바이트를 준다(디렉터리든 jar 안 자원이든).
 */
object PremadeItems {

	fun prepare(userId: UUID, entry: SeedEntry, savedAt: Instant, read: (String) -> ByteArray): PremadeItem {
		val kind = entry.itemKind
		val link = entry.url?.let { requireNotNull(LinkNormalizer.normalize(it)) { "${entry.id}: bad url" } }
		val bytes = entry.file?.let(read)
		// 경로 앞을 사용자 ID로 둔다(UploadService와 같은 규칙, COM-006).
		val file = bytes?.let {
			StoredFile("$userId/${UUID.randomUUID()}", entry.title, entry.fileFormat, it.size.toLong(), sha256(it))
		}
		val textBody = entry.textFile?.let { String(read(it), Charsets.UTF_8).replace("\r\n", "\n").trimEnd('\n') }
		require(kind != ItemKind.LINK || link != null) { "${entry.id}: link needs url" }
		require(kind != ItemKind.FILE || file != null) { "${entry.id}: file needs file" }
		require(kind != ItemKind.TEXT || textBody != null) { "${entry.id}: text needs textFile" }
		val source = when (kind) {
			ItemKind.LINK -> link!!.host
			ItemKind.TEXT -> null
			ItemKind.FILE -> file!!.format.value
		}
		val row = SeedRow(
			seedId = entry.id,
			kind = kind,
			title = entry.title,
			source = source,
			url = entry.url,
			normalizedUrl = link?.value,
			textBody = textBody,
			file = file,
			status = entry.itemStatus.value,
			blockedReason = entry.blockedReason,
			listSummary = entry.listSummary,
			handoffSummary = entry.handoffSummary,
			tags = entry.tags,
			searchText = searchText(entry, source),
			savedAt = savedAt,
			body = if (kind == ItemKind.TEXT) null else ItemBody.of(entry.body, fromImage = kind == ItemKind.FILE && isImage(entry.fileFormat)),
		)
		return PremadeItem(row, file?.let { PremadeUpload(it.objectPath, bytes!!, mimeType(it.format)) })
	}

	/** 올리는 도중 실패하면 이미 올린 원본을 지우고 다시 던진다(없는 경로 지우기는 무시된다). */
	fun putAll(storage: ObjectStorage, uploads: List<PremadeUpload>) {
		try {
			uploads.forEach { storage.put(it.objectPath, it.bytes, it.contentType) }
		} catch (e: RuntimeException) {
			deleteAll(storage, uploads)
			throw e
		}
	}

	fun deleteAll(storage: ObjectStorage, uploads: List<PremadeUpload>) = uploads.forEach { storage.delete(it.objectPath) }

	/** 워커가 쓰는 찾기 본문과 같은 순서: 제목·출처·요약·태그·본문(JdbcProcessingQueue.writeItem). */
	private fun searchText(entry: SeedEntry, source: String?): String =
		listOfNotNull(entry.title, source, entry.listSummary, entry.handoffSummary, entry.tags.joinToString(" "), entry.body)
			.filter { it.isNotBlank() }
			.joinToString(" ")

	private fun isImage(format: FileFormat): Boolean =
		format in setOf(FileFormat.PNG, FileFormat.JPEG, FileFormat.WEBP, FileFormat.HEIC)

	/** Storage 버킷 허용 형식과 맞춘다. 브라우저 업로드는 파일의 형식을 그대로 보낸다. */
	private fun mimeType(format: FileFormat): String = when (format) {
		FileFormat.PDF -> "application/pdf"
		FileFormat.MD -> "text/markdown"
		FileFormat.TXT -> "text/plain"
		FileFormat.DOCX -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
		FileFormat.PNG -> "image/png"
		FileFormat.JPEG -> "image/jpeg"
		FileFormat.WEBP -> "image/webp"
		FileFormat.HEIC -> "image/heic"
	}

	private fun sha256(bytes: ByteArray): String =
		HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes))
}
