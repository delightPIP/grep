package com.unwrap.grep.features.demoseed.domain

import com.unwrap.grep.features.account.domain.AuthProvider
import com.unwrap.grep.features.archive.domain.FileFormat
import com.unwrap.grep.features.archive.domain.ItemKind
import com.unwrap.grep.features.archive.domain.LinkNormalizer
import com.unwrap.grep.features.archive.domain.ObjectStorage
import com.unwrap.grep.features.archive.domain.StoredFile
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionTemplate
import java.nio.file.Files
import java.nio.file.Path
import java.security.MessageDigest
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.HexFormat
import java.util.UUID

/** 자료 한 건의 넣을 값. 번호는 저장소가 트랜잭션 안에서 붙인다(ARC-001). */
data class SeedRow(
	val seedId: String,
	val kind: ItemKind,
	val title: String,
	val source: String?,
	val url: String? = null,
	val normalizedUrl: String? = null,
	val textBody: String? = null,
	val file: StoredFile? = null,
	val status: String,
	val blockedReason: String?,
	val listSummary: String?,
	val handoffSummary: String?,
	val tags: List<String>,
	val searchText: String,
	val savedAt: Instant,
)

interface DemoSeedRepository {
	/** Supabase auth.users의 이메일과 로그인 방식으로 우리 users 행을 찾는다. 첫 로그인 전이면 null. */
	fun findUserId(provider: AuthProvider, email: String): UUID?

	/** 사용자 행을 잠그고 마지막 발급 번호를 돌려준다. 트랜잭션 안에서만 부른다. */
	fun lockLastItemNumber(userId: UUID): Long

	/** 번호를 발급하고 자료를 넣는다. 처리 작업(item_jobs)은 만들지 않는다. 발급한 번호를 돌려준다. */
	fun insert(userId: UUID, row: SeedRow): Long
}

sealed interface SeedResult {
	data class Seeded(val numbers: Map<String, Long>) : SeedResult

	/** 그 이메일·로그인 방식으로 로그인한 적이 없다. */
	data object UserNotFound : SeedResult

	/** 자료 번호를 이미 발급한 계정. 다시 넣으면 S번호와 번호가 어긋난다(demo-seed 2절 7·8번). */
	data class AlreadyHasItems(val lastItemNumber: Long) : SeedResult
}

/**
 * 데모 시드(#69, demo-seed 2절). seed.json의 요약·태그·본문을 그대로 넣고 LLM은 부르지 않는다.
 * 처리 작업을 만들지 않으므로 워커가 다시 집지 않고 하루 AI 처리 한도도 쓰지 않는다(COM-005).
 */
@Service
class DemoSeedService(
	private val repository: DemoSeedRepository,
	private val storage: ObjectStorage,
	private val transaction: TransactionTemplate,
	private val clock: Clock,
) {
	fun seed(provider: AuthProvider, email: String, seedDir: Path): SeedResult {
		val userId = repository.findUserId(provider, email) ?: return SeedResult.UserNotFound
		val already = transaction.execute { repository.lockLastItemNumber(userId) }!!
		if (already > 0) return SeedResult.AlreadyHasItems(already)

		val today = clock.instant()
		val prepared = DemoSeedFile.load(seedDir).items.map { prepare(userId, it, seedDir, today) }
		val uploads = prepared.mapNotNull { it.upload }
		// 올리는 도중 실패해도 이미 올린 원본을 지운다(없는 경로 지우기는 무시된다).
		val result = try {
			uploads.forEach { storage.put(it.objectPath, it.bytes, it.contentType) }
			transaction.execute { insertAll(userId, prepared.map { it.row }) }!!
		} catch (e: RuntimeException) {
			uploads.forEach { storage.delete(it.objectPath) }
			throw e
		}
		if (result !is SeedResult.Seeded) uploads.forEach { storage.delete(it.objectPath) }
		return result
	}

	/** 앞의 확인과 이 트랜잭션 사이에 저장이 끼어들 수 있어 잠근 뒤 다시 본다. */
	private fun insertAll(userId: UUID, rows: List<SeedRow>): SeedResult {
		val last = repository.lockLastItemNumber(userId)
		if (last > 0) return SeedResult.AlreadyHasItems(last)
		return SeedResult.Seeded(rows.associate { it.seedId to repository.insert(userId, it) })
	}

	private class Upload(val objectPath: String, val bytes: ByteArray, val contentType: String)

	private class Prepared(val row: SeedRow, val upload: Upload?)

	private fun prepare(userId: UUID, entry: SeedEntry, seedDir: Path, today: Instant): Prepared {
		val kind = entry.itemKind
		val link = entry.url?.let { requireNotNull(LinkNormalizer.normalize(it)) { "${entry.id}: bad url" } }
		val bytes = entry.file?.let { Files.readAllBytes(seedDir.resolve(it)) }
		// 경로 앞을 사용자 ID로 둔다(UploadService와 같은 규칙, COM-006).
		val file = bytes?.let {
			StoredFile("$userId/${UUID.randomUUID()}", entry.title, entry.fileFormat, it.size.toLong(), sha256(it))
		}
		val textBody = entry.textFile?.let { normalizeNewlines(Files.readString(seedDir.resolve(it))).trimEnd('\n') }
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
			savedAt = today.minus(Duration.ofDays(entry.savedDaysAgo)),
		)
		return Prepared(row, file?.let { Upload(it.objectPath, bytes!!, mimeType(it.format)) })
	}

	/** 워커가 쓰는 찾기 본문과 같은 순서: 제목·출처·요약·태그·본문(JdbcProcessingQueue.writeItem). */
	private fun searchText(entry: SeedEntry, source: String?): String =
		listOfNotNull(entry.title, source, entry.listSummary, entry.handoffSummary, entry.tags.joinToString(" "), entry.body)
			.filter { it.isNotBlank() }
			.joinToString(" ")

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

	private fun normalizeNewlines(text: String): String = text.replace("\r\n", "\n")

	private fun sha256(bytes: ByteArray): String =
		HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes))
}
