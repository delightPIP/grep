package com.unwrap.grep.features.archive.api

import java.util.UUID

/**
 * archive가 다른 모듈에 공개하는 포트(ADR-BCK-004 결정 2의 `interface`. Kotlin 예약어라 패키지 이름을 `api`로 둔다).
 * account의 GET /me가 상태줄 `자료 N`을 셀 때 쓴다.
 */
interface ItemCounter {
	/** 휴지통 밖 자료 수. */
	fun countActiveItems(userId: UUID): Long
}
