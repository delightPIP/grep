package com.unwrap.grep.features.demoseed

import com.unwrap.grep.GrepServerApplication
import com.unwrap.grep.features.account.domain.AuthProvider
import com.unwrap.grep.features.demoseed.domain.DemoSeedService
import com.unwrap.grep.features.demoseed.domain.SeedResult
import org.springframework.boot.builder.SpringApplicationBuilder
import java.nio.file.Path
import kotlin.system.exitProcess

/**
 * 데모 시드 도구(#69). `cd server && ./gradlew seedDemo -Pemail=<계정 이메일> [-Pprovider=google]`.
 * 이메일은 화면·로그에 찍지 않는다. DB·스토리지 연결은 서버와 같은 환경변수(application.properties)를 쓴다.
 */
fun main(args: Array<String>) {
	val options = args.mapNotNull { arg -> arg.removePrefix("--").split("=", limit = 2).takeIf { it.size == 2 } }
		.associate { (key, value) -> key to value }
	val email = options["email"]?.takeIf { it.isNotBlank() } ?: fail("이메일이 없다. -Pemail=<계정 이메일>로 준다.")
	val provider = AuthProvider.fromClaim(options["provider"] ?: AuthProvider.GOOGLE.claimValue)
		?: fail("로그인 방식은 google 또는 github다.")
	val seedDir = Path.of(options["seed-dir"] ?: fail("시드 폴더가 없다."))

	// shortcut: 서버 빈을 그대로 쓰려고 웹 문맥을 빈 포트(0)로 띄운다. 워커는 끈다. 시드가 커지면 별도 문맥으로 나눈다.
	val context = SpringApplicationBuilder(GrepServerApplication::class.java)
		.properties("server.port=0", "grep.processing.enabled=false", "spring.main.banner-mode=off")
		.run()
	val code = context.use {
		when (val result = it.getBean(DemoSeedService::class.java).seed(provider, email, seedDir)) {
			is SeedResult.Seeded -> {
				println("✓ 자료 ${result.numbers.size}건을 넣었다(${provider.claimValue} 계정).")
				result.numbers.forEach { (seedId, number) -> println("  $seedId → $number") }
				0
			}
			SeedResult.UserNotFound -> {
				println("! 그 계정이 없다. 앱에서 ${provider.claimValue}로 한 번 로그인한 뒤 다시 실행한다.")
				1
			}
			is SeedResult.AlreadyHasItems -> {
				println("! 이 계정은 이미 번호 ${result.lastItemNumber}까지 받았다. 같은 계정에 다시 넣지 않는다(demo-seed 2절 8번).")
				2
			}
		}
	}
	exitProcess(code)
}

private fun fail(message: String): Nothing {
	System.err.println("! $message")
	exitProcess(64)
}
