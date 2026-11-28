package com.unwrap.grep.features.archive.domain

import java.time.Clock
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters
import java.util.UUID

/** 자동 묶음 형식(ARC-007 값). image는 이미지 파일, file은 그 밖의 파일. */
enum class GroupKind(val value: String) {
	LINK("link"), TEXT("text"), IMAGE("image"), FILE("file");

	companion object {
		fun of(value: String): GroupKind? = entries.firstOrNull { it.value == value }
	}
}

/**
 * 자동 묶음 하나로 거르는 조건(GET /items의 kind·source·tag). 모두 null이면 거르지 않는다.
 * [source]는 링크 호스트이거나 링크가 아닌 자료 전부를 뜻하는 [DIRECT]. [tag]는 `#` 없는 소문자, 정확히 일치.
 */
data class ItemFilter(val kind: GroupKind? = null, val source: String? = null, val tag: String? = null) {
	companion object {
		val NONE = ItemFilter()
		const val DIRECT = "direct"
	}
}

/** openapi `GroupCount`. 0건 묶음은 만들지 않는다(ARC-007 규칙 7). */
data class GroupCount(val key: String, val count: Long)

/** openapi `AutoGroups`. */
data class AutoGroups(
	val kinds: List<GroupCount>,
	val sources: List<GroupCount>,
	val periods: List<GroupCount>,
	val tags: List<GroupCount>,
)

/** 날짜 묶음의 시작 시각. 오늘·이번 주(월요일)·이번 달은 그 시각 이상, 그 전은 이번 달 시작 미만이다. */
data class PeriodStarts(val today: Instant, val thisWeek: Instant, val thisMonth: Instant)

interface AutoGroupRepository {
	/** 휴지통 밖 내 자료의 형식별 건수. */
	fun countByKind(userId: UUID): Map<GroupKind, Long>

	/** 출처별 건수. 건수 큰 순, 같으면 이름 순. */
	fun countBySource(userId: UUID): List<GroupCount>

	/** 태그별 건수. 건수 큰 순, 같으면 이름 순. */
	fun countByTag(userId: UUID): List<GroupCount>

	/** today·thisWeek·thisMonth·earlier 순서의 건수. */
	fun countByPeriod(userId: UUID, starts: PeriodStarts): List<GroupCount>
}

/** 보관함 자동 묶음(ARC-007). 휴지통 자료는 세지 않는다(규칙 8). 한 자료는 맞는 묶음 모두에 든다(규칙 6). */
class AutoGroupService(private val groups: AutoGroupRepository, private val clock: Clock) {

	fun groups(userId: UUID, zone: ZoneId): AutoGroups {
		val byKind = groups.countByKind(userId)
		return AutoGroups(
			kinds = GroupKind.entries.mapNotNull { kind -> byKind[kind]?.takeIf { it > 0 }?.let { GroupCount(kind.value, it) } },
			sources = groups.countBySource(userId),
			periods = groups.countByPeriod(userId, periodStarts(zone)).filter { it.count > 0 },
			tags = groups.countByTag(userId),
		)
	}

	/** 사용자 기기 시간대 기준(ARC-007 값). 주는 월요일에 시작한다(openapi SavedFrom). */
	internal fun periodStarts(zone: ZoneId): PeriodStarts {
		val today = LocalDate.ofInstant(clock.instant(), zone)
		return PeriodStarts(
			today = today.atStartOfDay(zone).toInstant(),
			thisWeek = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)).atStartOfDay(zone).toInstant(),
			thisMonth = today.withDayOfMonth(1).atStartOfDay(zone).toInstant(),
		)
	}
}
