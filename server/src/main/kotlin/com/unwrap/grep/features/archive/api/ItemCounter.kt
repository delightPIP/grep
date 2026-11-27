package com.unwrap.grep.features.archive.api

import java.time.Instant
import java.util.UUID

/**
 * archive가 다른 모듈에 공개하는 포트(ADR-BCK-004 결정 2의 `interface`. Kotlin 예약어라 패키지 이름을 `api`로 둔다).
 * account의 GET /me가 상태줄 `자료 N`을 셀 때 쓴다.
 */
interface ItemCounter {
	/** 휴지통 밖 자료 수. */
	fun countActiveItems(userId: UUID): Long
}

/** metrics의 `handoff_copied`가 저장 뒤 지난 일수를 셀 때 쓴다(D-08). 번호 자체는 metrics에 남기지 않는다. */
interface ItemSavedTimes {
	/** [numbers] 중 휴지통 밖 내 자료의 저장 시각. 같은 번호는 한 번만, 순서는 정하지 않는다. */
	fun savedTimes(userId: UUID, numbers: Collection<Long>): List<Instant>
}
