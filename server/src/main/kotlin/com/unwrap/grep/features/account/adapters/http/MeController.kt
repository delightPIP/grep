package com.unwrap.grep.features.account.adapters.http

import com.unwrap.grep.features.account.domain.Account
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

data class MeResponse(val userId: UUID, val authProvider: String, val itemCount: Int)

@RestController
class MeController {
	@GetMapping("/me")
	fun me(@RequestAttribute(AccountSessionFilter.CURRENT_ACCOUNT) account: Account): MeResponse =
		// shortcut: 자료 테이블이 아직 없어 itemCount는 0, 자료 저장(archive) 모듈이 생기면 그 포트로 센다.
		MeResponse(userId = account.userId, authProvider = account.provider.claimValue, itemCount = 0)
}
