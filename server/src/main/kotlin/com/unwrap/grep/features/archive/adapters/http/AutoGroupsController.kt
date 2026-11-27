package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.domain.AutoGroupService
import com.unwrap.grep.features.archive.domain.AutoGroups
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.DateTimeException
import java.time.ZoneId
import java.util.UUID

/** GET /groups(listAutoGroups, ARC-007). 날짜 묶음은 기기 시간대 `tz`로 나눈다. 없으면 Asia/Seoul. */
@RestController
class AutoGroupsController(private val groups: AutoGroupService) {

	@GetMapping("/groups")
	fun list(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @RequestParam(required = false) tz: String?): AutoGroups {
		val zone = try {
			ZoneId.of(tz ?: DEFAULT_ZONE)
		} catch (e: DateTimeException) {
			throw ApiProblem.invalidRequest("tz must be an IANA time zone")
		}
		return groups.groups(userId, zone)
	}

	private companion object {
		const val DEFAULT_ZONE = "Asia/Seoul"
	}
}
