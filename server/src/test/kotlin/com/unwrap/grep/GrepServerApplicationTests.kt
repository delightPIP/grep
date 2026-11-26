package com.unwrap.grep

import org.junit.jupiter.api.Test
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.annotation.Import

@Import(TestcontainersConfiguration::class)
@SpringBootTest
class GrepServerApplicationTests {

	@Test
	fun `DB가떠있을때_서버를시작하면_마이그레이션과함께컨텍스트가뜨는지`() {
		// given: Testcontainers Postgres(TestcontainersConfiguration)

		// when: @SpringBootTest가 컨텍스트를 띄운다

		// then: 예외 없이 여기까지 온다
	}

}
