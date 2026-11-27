package com.unwrap.grep

import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.context.annotation.Bean
import org.testcontainers.postgresql.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName

@TestConfiguration(proxyBeanMethods = false)
class TestcontainersConfiguration {

	@Bean
	@ServiceConnection
	fun postgresContainer(): PostgreSQLContainer {
		return PostgreSQLContainer(DockerImageName.parse(PGROONGA_IMAGE).asCompatibleSubstituteFor("postgres"))
	}

}

/** 검색은 PGroonga(Supabase 확장)를 쓴다. 테스트 DB도 같은 확장이 든 Postgres 17 이미지로 돈다(#56). */
const val PGROONGA_IMAGE = "groonga/pgroonga:4.0.4-alpine-17"
