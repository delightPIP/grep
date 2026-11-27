package com.unwrap.grep.features.archive.domain

import java.time.Instant
import java.util.UUID

enum class ItemKind(val value: String) { LINK("link"), TEXT("text"), FILE("file") }

/** ARC-005 처리 상태. 이 다섯 가지뿐이다. */
enum class ItemStatus(val value: String) {
	RECEIVED("received"), PROCESSING("processing"), READY("ready"), BLOCKED("blocked"), FAILED("failed");

	companion object {
		fun of(value: String): ItemStatus = entries.first { it.value == value }
	}
}

/** 저장된 자료. API에는 번호로만 내보내고 내부 id는 싣지 않는다(ARC-001). */
data class StoredItem(
	val number: Long,
	val kind: ItemKind,
	val title: String,
	val source: String?,
	val status: ItemStatus,
	val blockedReason: String?,
	val listSummary: String?,
	val userSummary: String?,
	val partialNote: String?,
	val tags: List<String>,
	val savedAt: Instant,
	val inTrash: Boolean,
)

/** 새 자료 한 건. 번호는 저장 트랜잭션 안에서 붙인다(ARC-001 규칙 2). */
data class NewItem(
	val userId: UUID,
	val kind: ItemKind,
	val title: String,
	val source: String?,
	val idempotencyKey: UUID,
	val url: String? = null,
	val normalizedUrl: String? = null,
	val textBody: String? = null,
	val file: StoredFile? = null,
)

data class StoredFile(
	val objectPath: String,
	val fileName: String,
	val format: FileFormat,
	val size: Long,
	val contentHash: String,
)

sealed interface SaveItemCommand {
	data class Link(val url: String) : SaveItemCommand
	data class Text(val text: String) : SaveItemCommand
	data class File(val uploadId: UUID) : SaveItemCommand
}

sealed interface SaveOutcome {
	val item: StoredItem

	/** 새로 저장했다. */
	data class Saved(override val item: StoredItem) : SaveOutcome

	/** 같은 멱등성 키로 이미 저장한 자료. 처음 결과(saved)를 다시 준다. */
	data class Replayed(override val item: StoredItem) : SaveOutcome

	/** 같은 자료가 있다(COM-001 규칙 3). */
	data class Duplicate(override val item: StoredItem) : SaveOutcome

	/** 같은 자료가 휴지통에 있다(COM-001 규칙 7). */
	data class InTrash(override val item: StoredItem) : SaveOutcome

	companion object {
		fun existing(item: StoredItem): SaveOutcome = if (item.inTrash) InTrash(item) else Duplicate(item)
	}
}

/** POST /uploads로 만든 업로드 자리. */
data class UploadSlot(val id: UUID, val userId: UUID, val objectPath: String, val fileName: String)

interface ItemRepository {
	/** 사용자 행을 잠가 같은 사용자의 저장을 차례로 세운다(ARC-001 규칙 3). 트랜잭션 안에서만 부른다. */
	fun lockOwner(userId: UUID)

	fun findByIdempotencyKey(userId: UUID, key: UUID): StoredItem?

	/** 휴지통 자료도 찾는다(COM-001 규칙 7). */
	fun findByNormalizedUrl(userId: UUID, normalizedUrl: String): StoredItem?

	fun findByContentHash(userId: UUID, contentHash: String): StoredItem?

	/** 번호를 발급하고 자료와 처리 작업을 넣는다. [lockOwner]와 같은 트랜잭션에서 부른다. */
	fun insert(item: NewItem): StoredItem

	/** 휴지통 밖 자료 수. */
	fun countActive(userId: UUID): Long
}

interface UploadRepository {
	fun create(slot: UploadSlot, declaredSize: Long, createdAt: Instant)

	/** 그 사용자의 것이고 아직 저장에 쓰이지 않은 자리만 돌려준다(COM-006). */
	fun findUnconsumed(userId: UUID, uploadId: UUID): UploadSlot?

	/** 아직 쓰이지 않았으면 쓰였다고 표시하고 true. 다른 요청이 먼저 썼으면 false. */
	fun claim(uploadId: UUID, at: Instant): Boolean

	fun delete(uploadId: UUID)
}
