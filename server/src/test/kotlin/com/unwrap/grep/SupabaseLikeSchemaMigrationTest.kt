package com.unwrap.grep

import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.jdbc.core.simple.JdbcClient
import org.testcontainers.postgresql.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import kotlin.test.Test
import kotlin.test.assertEquals

@TestConfiguration(proxyBeanMethods = false)
class SupabaseLikePostgres {

	@Bean
	@ServiceConnection
	fun postgresContainer(): PostgreSQLContainer =
		PostgreSQLContainer(DockerImageName.parse(PGROONGA_IMAGE).asCompatibleSubstituteFor("postgres"))
			.withInitScript("supabase-like-public-schema.sql")
}

@Import(SupabaseLikePostgres::class)
@SpringBootTest
class SupabaseLikeSchemaMigrationTest {

	@Autowired
	lateinit var jdbc: JdbcClient

	@Test
	fun `public스키마에함수가미리있을때_서버를시작하면_기준선뒤에V1과V2를적용하는지`() {
		// given: public.rls_auto_enable()이 있는 DB(supabase-like-public-schema.sql)

		// when: @SpringBootTest가 서버를 시작하며 Flyway를 돌린다

		// then
		val applied = jdbc.sql("SELECT version FROM flyway_schema_history WHERE success ORDER BY installed_rank")
			.query(String::class.java)
			.list()
		assertEquals(listOf("0", "1", "2"), applied)
	}
}
