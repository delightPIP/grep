package com.unwrap.grep

import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.context.annotation.Bean
import org.testcontainers.postgresql.PostgreSQLContainer
import org.testcontainers.images.builder.ImageFromDockerfile
import org.testcontainers.utility.DockerImageName

@TestConfiguration(proxyBeanMethods = false)
class TestcontainersConfiguration {

	@Bean
	@ServiceConnection
	fun postgresContainer(): PostgreSQLContainer {
		return PostgreSQLContainer(searchDatabaseImage())
	}

}

/**
 * 검색은 PGroonga, 뜻 찾기는 pgvector를 쓴다(둘 다 Supabase 확장, #56·#128). 두 확장이 함께 든 공식 이미지가 없어
 * PGroonga 데비안 이미지에 PGDG 저장소의 pgvector 패키지를 얹어 만든다. 처음 한 번은 패키지를 받느라 네트워크가 필요하고, 뒤로는 로컬 이미지를 쓴다.
 * pgvector 버전은 고정하지 않는다. PGDG가 옛 버전을 지워 고정하면 설치가 깨진다.
 */
const val PGROONGA_IMAGE = "groonga/pgroonga:4.0.4-debian-17"
private const val SEARCH_IMAGE = "grep-test/pgroonga-pgvector:4.0.4-debian-17"

fun searchDatabaseImage(): DockerImageName {
	val name = ImageFromDockerfile(SEARCH_IMAGE, false)
		.withDockerfileFromBuilder { builder ->
			builder.from(PGROONGA_IMAGE)
				// 이미지에 든 Apache Arrow 저장소는 서명 키가 맞지 않아 apt-get update가 실패한다. pgvector에는 필요 없어 목록에서 뺀다.
				.run("rm -f /etc/apt/sources.list.d/apache-arrow.sources && apt-get update && apt-get install -y --no-install-recommends postgresql-17-pgvector && rm -rf /var/lib/apt/lists/*")
				.build()
		}
		.get()
	return DockerImageName.parse(name).asCompatibleSubstituteFor("postgres")
}
