package com.unwrap.grep.features.archive.api

import java.util.UUID

/**
 * archive가 저장 성공(ARC-005 규칙 1)을 알리는 포트. metrics가 구현해 `item_saved`를 남긴다.
 * archive는 metrics를 모르고, metrics만 archive를 안다. 구현은 실패해도 던지지 않는다.
 */
fun interface ItemSaveListener {
	/** 저장 성공 뒤 한 번. [method]는 자료 종류(`link`·`text`·`file`)다. */
	fun itemSaved(userId: UUID, method: String)
}
