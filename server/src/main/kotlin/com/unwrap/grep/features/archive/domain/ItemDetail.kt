package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.features.archive.api.ItemBody
import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import org.springframework.stereotype.Service
import java.net.URI
import java.time.Duration
import java.util.UUID

/** 자세히 보기에 필요한 값. [body]는 글 자료면 text_body 전체, 아니면 처리 때 읽은 본문(V5). */
data class ItemDetailSource(
	val item: StoredItem,
	val url: String?,
	val handoffSummary: String?,
	val body: ItemBody?,
	val objectPath: String?,
	val fileFormat: FileFormat?,
	val bundles: List<String>,
)

/**
 * openapi `ItemDetail`. [bodyLength]는 [body]가 없으면 null이다(본문을 아직 읽지 않았거나 읽지 못함).
 * [url]은 링크의 원래 주소에서 추적 꼬리표만 뺀 사람용 주소(넘길 글 출처 칸과 같은 값). 링크가 아니면 null.
 */
data class ItemDetail(
	val item: StoredItem,
	val url: String?,
	val handoffSummary: String?,
	val allTags: List<String>,
	val bundles: List<String>,
	val bodyLength: Int?,
	val body: String?,
	val bodyFromImage: Boolean,
	val originalUrl: URI?,
	val previewUrl: URI?,
)

interface ItemDetailRepository {
	/** 휴지통 밖 내 자료 하나. 묶음 이름은 이름 순. */
	fun findActiveDetail(userId: UUID, number: Long): ItemDetailSource?
}

/**
 * `열기 <번호>`(ARC-011). 자료 내용은 고치지 않는다(규칙 11). 휴지통·없는·남의 번호는 `not_found`(규칙 3, COM-006).
 * 가져온 자료를 열면 기다리는 처리 작업을 보통 우선순위로 올린다(ADR-BCK-017).
 */
@Service
class ItemDetailService(
	private val details: ItemDetailRepository,
	private val items: ItemRepository,
	private val storage: ObjectStorage,
) {

	fun detail(userId: UUID, number: Long): ItemDetail {
		val source = details.findActiveDetail(userId, number)
			?: throw ApiProblem(ApiErrorCode.NOT_FOUND, numbers = listOf(number))
		items.raiseProcessingPriority(userId, listOf(number))
		val original = source.objectPath?.let { storage.presignGet(it, SIGNED_URL_LIFETIME) }
		return ItemDetail(
			item = source.item,
			url = source.url?.let { LinkNormalizer.withoutTracking(it) },
			handoffSummary = source.item.userSummary ?: source.handoffSummary,
			allTags = source.item.tags,
			bundles = source.bundles,
			bodyLength = source.body?.length,
			body = source.body?.text,
			bodyFromImage = source.body?.fromImage ?: false,
			originalUrl = original,
			previewUrl = original?.takeIf { source.fileFormat in IMAGE_FORMATS },
		)
	}

	private companion object {
		/** ARC-011 비고: 원본 서명 URL은 10분. */
		val SIGNED_URL_LIFETIME: Duration = Duration.ofMinutes(10)
		val IMAGE_FORMATS = setOf(FileFormat.PNG, FileFormat.JPEG, FileFormat.WEBP, FileFormat.HEIC)
	}
}
