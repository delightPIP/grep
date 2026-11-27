package com.unwrap.grep.features.archive.testing

import com.unwrap.grep.TestcontainersConfiguration
import com.unwrap.grep.support.FakeSupabaseAuth
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.ResultActionsDsl
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import java.util.UUID

/** 자료 API 테스트 공통 바탕. 두 테스트 클래스가 같은 Spring 문맥(DB 컨테이너 하나)을 나눠 쓴다. */
@Import(TestcontainersConfiguration::class, FakeObjectStorageConfiguration::class)
@SpringBootTest
@AutoConfigureMockMvc
abstract class ArchiveApiTestSupport {

	@Autowired
	lateinit var mockMvc: MockMvc

	@Autowired
	lateinit var jdbc: JdbcClient

	@Autowired
	lateinit var storage: FakeObjectStorage

	companion object {
		@JvmStatic
		@DynamicPropertySource
		fun supabase(registry: DynamicPropertyRegistry) {
			registry.add("spring.security.oauth2.resourceserver.jwt.jwk-set-uri") { FakeSupabaseAuth.jwkSetUri }
			registry.add("spring.security.oauth2.resourceserver.jwt.issuer-uri") { FakeSupabaseAuth.issuer }
			registry.add("grep.web-origin") { "http://web.test" }
		}
	}

	/** 새 사용자 토큰. 테스트마다 따로 써서 번호·같은 자료 판정이 서로 섞이지 않게 한다. */
	fun newUser(): String = FakeSupabaseAuth.token()

	fun saveItem(token: String, json: String, key: String? = UUID.randomUUID().toString()): ResultActionsDsl =
		mockMvc.post("/items") {
			header("Authorization", "Bearer $token")
			if (key != null) header("Idempotency-Key", key)
			contentType = MediaType.APPLICATION_JSON
			content = json
		}

	fun saveLink(token: String, url: String, key: String = UUID.randomUUID().toString()) =
		saveItem(token, """{"kind":"link","url":"$url"}""", key)

	fun createUpload(token: String, fileName: String, size: Long): ResultActionsDsl =
		mockMvc.post("/uploads") {
			header("Authorization", "Bearer $token")
			contentType = MediaType.APPLICATION_JSON
			content = """{"fileName":"$fileName","size":$size}"""
		}

	/** 업로드 자리를 만들고 클라이언트가 PUT한 것처럼 객체를 넣는다. uploadId를 돌려준다. */
	fun upload(token: String, fileName: String, bytes: ByteArray): String {
		val body = createUpload(token, fileName, bytes.size.toLong())
			.andExpect { status { isCreated() } }
			.andReturn().response.contentAsString
		val uploadId = Regex("\"uploadId\":\"([^\"]+)\"").find(body)!!.groupValues[1]
		storage.put(objectPathOf(uploadId), bytes, "application/octet-stream")
		return uploadId
	}

	fun objectPathOf(uploadId: String): String =
		jdbc.sql("SELECT object_path FROM uploads WHERE id = :id").param("id", UUID.fromString(uploadId))
			.query(String::class.java).single()

	fun getMe(token: String) = mockMvc.get("/me") { header("Authorization", "Bearer $token") }

	fun listItems(token: String, vararg params: Pair<String, String>) = mockMvc.get("/items") {
		header("Authorization", "Bearer $token")
		params.forEach { (name, value) -> param(name, value) }
	}

	fun getStatuses(token: String, numbers: String?) = mockMvc.get("/items/status") {
		header("Authorization", "Bearer $token")
		if (numbers != null) param("numbers", numbers)
	}

	/** 링크 [count]건을 저장한다. 번호는 1부터 차례로 붙는다. */
	fun saveLinks(token: String, count: Int) = (1..count).forEach {
		saveLink(token, "https://example.com/item/$it").andExpect { status { isCreated() } }
	}

	fun moveToTrash(token: String, number: Long) {
		val userId = userIdOf(token)
		jdbc.sql("UPDATE items SET deleted_at = now() WHERE user_id = :userId AND number = :number")
			.param("userId", userId).param("number", number).update()
	}

	fun countItems(token: String): Int =
		jdbc.sql("SELECT count(*) FROM items WHERE user_id = :userId").param("userId", userIdOf(token))
			.query(Int::class.java).single()

	fun userIdOf(token: String): UUID {
		val body = getMe(token).andReturn().response.contentAsString
		return UUID.fromString(Regex("\"userId\":\"([^\"]+)\"").find(body)!!.groupValues[1])
	}
}
