package com.unwrap.grep.features.account.adapters.http

import com.unwrap.grep.features.account.domain.Account
import com.unwrap.grep.features.archive.api.ItemCounter
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

data class MeResponse(val userId: UUID, val authProvider: String, val itemCount: Long)

@RestController
class MeController(private val itemCounter: ItemCounter) {
	/** itemCount는 상태줄 `자료 N`. 휴지통 자료는 세지 않는다(openapi `Me`). */
	@GetMapping("/me")
	fun me(@RequestAttribute(AccountSessionFilter.CURRENT_ACCOUNT) account: Account): MeResponse =
		MeResponse(
			userId = account.userId,
			authProvider = account.provider.claimValue,
			itemCount = itemCounter.countActiveItems(account.userId),
		)
}
