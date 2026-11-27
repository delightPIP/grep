package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import org.springframework.stereotype.Service
import java.util.UUID

/** `고치기`의 바꿀 값. null인 칸은 그대로 둔다. [removeTags]는 `#` 없이 소문자로 맞춘 값이다. */
data class ItemRevision(val title: String?, val summary: String?, val removeTags: List<String>)

interface ItemRevisionRepository {
	/** 휴지통 밖 내 자료를 고치고 고친 결과를 준다. 그런 자료가 없으면 null. */
	fun revise(userId: UUID, number: Long, revision: ItemRevision): StoredItem?
}

/**
 * `고치기 <번호>`(commands 3절). 고친 제목·요약은 처리 워커가 덮어쓰지 않고(ARC-004), 지운 태그는 다시 붙지 않는다(ARC-002 규칙 2).
 * 고쳐도 처리 작업을 다시 넣지 않으므로 태그를 다시 만들지 않는다(ARC-002 규칙 3).
 */
@Service
class ReviseItemService(private val revisions: ItemRevisionRepository) {

	fun revise(userId: UUID, number: Long, revision: ItemRevision): StoredItem =
		revisions.revise(userId, number, revision) ?: throw ApiProblem(ApiErrorCode.NOT_FOUND, numbers = listOf(number))
}
