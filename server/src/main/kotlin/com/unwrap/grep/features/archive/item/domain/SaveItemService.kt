package com.unwrap.grep.features.archive.item.domain

import com.unwrap.grep.features.archive.api.ItemSaveListener
import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import org.springframework.transaction.support.TransactionTemplate
import java.security.MessageDigest
import java.time.Clock
import java.util.HexFormat
import java.util.UUID

/**
 * 링크·글·파일 저장(ARC-001, ARC-005, COM-001, COM-004).
 * 같은 사용자의 저장은 사용자 행 잠금으로 차례를 세운 뒤, 그 안에서 멱등성 키 → 같은 자료 → 번호 발급 순으로 본다.
 * 그래서 동시에 같은 링크를 보내도 하나만 저장된다.
 */
class SaveItemService(
	private val items: ItemRepository,
	private val uploads: UploadRepository,
	private val storage: ObjectStorage,
	private val transaction: TransactionTemplate,
	private val clock: Clock,
	private val saveListener: ItemSaveListener,
) {
	/** 새로 저장했을 때만 `item_saved`를 남긴다(D-08). 같은 자료·다시 온 요청은 남기지 않는다. */
	fun save(userId: UUID, idempotencyKey: UUID, command: SaveItemCommand): SaveOutcome {
		items.findByIdempotencyKey(userId, idempotencyKey)?.let { return SaveOutcome.Replayed(it) }
		val outcome = when (command) {
			is SaveItemCommand.Link -> saveLink(userId, idempotencyKey, command)
			is SaveItemCommand.Text -> saveText(userId, idempotencyKey, command)
			is SaveItemCommand.File -> saveFile(userId, idempotencyKey, command)
		}
		if (outcome is SaveOutcome.Saved) saveListener.itemSaved(userId, outcome.item.kind.value)
		return outcome
	}

	private fun saveLink(userId: UUID, key: UUID, command: SaveItemCommand.Link): SaveOutcome {
		val link = LinkNormalizer.normalize(command.url)
			?: throw ApiProblem.invalidRequest("link must be an http(s) URL with a host")
		val item = NewItem(
			userId = userId, kind = ItemKind.LINK, title = command.url, source = link.host, idempotencyKey = key,
			url = command.url, normalizedUrl = link.value,
		)
		return inSaveTransaction(userId, key) {
			items.findByNormalizedUrl(userId, link.value)?.let { SaveOutcome.existing(it) }
				?: SaveOutcome.Saved(items.insert(item))
		}
	}

	private fun saveText(userId: UUID, key: UUID, command: SaveItemCommand.Text): SaveOutcome {
		val item = NewItem(
			userId = userId, kind = ItemKind.TEXT, title = ItemTitles.forText(command.text), source = null,
			idempotencyKey = key, textBody = command.text,
		)
		return inSaveTransaction(userId, key) { SaveOutcome.Saved(items.insert(item)) }
	}

	private fun saveFile(userId: UUID, key: UUID, command: SaveItemCommand.File): SaveOutcome {
		val upload = uploads.findUnconsumed(userId, command.uploadId)
			?: throw ApiProblem.invalidRequest("upload not found or already used")
		val bytes = when (val stored = storage.read(upload.objectPath, MAX_FILE_BYTES)) {
			null -> throw ApiProblem.invalidRequest("file was not uploaded")
			is StoredObject.TooLarge -> {
				discard(upload)
				throw ApiProblem(ApiErrorCode.FILE_TOO_LARGE, fileName = upload.fileName, bytes = stored.size)
			}
			is StoredObject.Content -> stored.bytes
		}
		val format = when (val detection = FileFormatDetector.detect(bytes, upload.fileName)) {
			is FileDetection.Rejected -> {
				discard(upload)
				throw ApiProblem(ApiErrorCode.UNSUPPORTED_FORMAT, fileExtension = detection.fileExtension)
			}
			is FileDetection.Accepted -> detection.format
		}
		val file = StoredFile(upload.objectPath, upload.fileName, format, bytes.size.toLong(), sha256(bytes))
		val item = NewItem(
			userId = userId, kind = ItemKind.FILE, title = upload.fileName, source = format.value,
			idempotencyKey = key, file = file,
		)
		val outcome = try {
			inSaveTransaction(userId, key) {
				// 다른 요청이 이 자리를 먼저 썼으면 그 요청의 원본이므로 건드리지 않는다.
				if (!uploads.claim(upload.id, clock.instant())) {
					throw ApiProblem.invalidRequest("upload already used")
				}
				items.findByContentHash(userId, file.contentHash)
					?.let { uploads.delete(upload.id); SaveOutcome.existing(it) }
					?: SaveOutcome.Saved(items.insert(item))
			}
		} catch (e: ApiProblem) {
			throw e
		} catch (e: RuntimeException) {
			// ARC-005 규칙 1: 레코드를 못 쓰면 원본도 지운다. 트랜잭션이 되돌아가 자리는 다시 안 쓴 상태다.
			storage.delete(upload.objectPath)
			throw e
		}
		// 같은 파일이 이미 있으면 방금 올린 원본은 쓰지 않는다.
		if (outcome is SaveOutcome.Duplicate || outcome is SaveOutcome.InTrash) storage.delete(upload.objectPath)
		return outcome
	}

	/** 사용자 행을 잠그고, 그 사이 같은 키로 저장된 자료가 있으면 그것을 돌려준다. */
	private fun inSaveTransaction(userId: UUID, key: UUID, body: () -> SaveOutcome): SaveOutcome =
		transaction.execute {
			items.lockOwner(userId)
			items.findByIdempotencyKey(userId, key)?.let { SaveOutcome.Replayed(it) } ?: body()
		}!!

	private fun discard(upload: UploadSlot) {
		storage.delete(upload.objectPath)
		uploads.delete(upload.id)
	}

	private fun sha256(bytes: ByteArray): String =
		HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes))

	companion object {
		/** COM-005 값: 파일 하나 20MB(공통 열린 질문의 임시값). 20 × 1024 × 1024 바이트로 센다. */
		const val MAX_FILE_BYTES: Long = 20L * 1024 * 1024
	}
}
