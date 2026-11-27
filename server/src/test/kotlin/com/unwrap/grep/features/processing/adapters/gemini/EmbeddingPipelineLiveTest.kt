package com.unwrap.grep.features.processing.adapters.gemini

import com.unwrap.grep.TestcontainersConfiguration
import com.unwrap.grep.features.archive.api.Embedder
import com.unwrap.grep.features.archive.api.EmbeddingPurpose
import com.unwrap.grep.features.archive.api.EmbeddingResult
import com.unwrap.grep.features.archive.testing.FakeObjectStorageConfiguration
import com.unwrap.grep.features.processing.domain.EmbeddingWorker
import com.unwrap.grep.support.FakeSupabaseAuth
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Import
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import java.nio.file.Files
import java.nio.file.Path
import java.util.UUID
import kotlin.math.sqrt
import kotlin.test.Test

/**
 * 저장 경로 전체를 실제 Gemini로 재현한다(#128 다시 맞추기). 샘플 8건 → 임베딩 워커 → pgvector 거리를,
 * 같은 입력 글을 새로 임베딩해 메모리에서 잰 거리와 나란히 `build/embedding-pipeline-report.txt`에 쓴다.
 * 두 값이 다르면 저장 경로가 벡터를 바꾸고 있다는 뜻이다. `GEMINI_API_KEY`가 있을 때만 돈다.
 */
@EnabledIfEnvironmentVariable(named = "GEMINI_API_KEY", matches = ".+")
@Import(TestcontainersConfiguration::class, FakeObjectStorageConfiguration::class)
@SpringBootTest
@AutoConfigureMockMvc
class EmbeddingPipelineLiveTest {

	@Autowired
	lateinit var mockMvc: MockMvc

	@Autowired
	lateinit var jdbc: JdbcClient

	@Autowired
	lateinit var worker: EmbeddingWorker

	@Autowired
	lateinit var embedder: Embedder

	companion object {
		@JvmStatic
		@DynamicPropertySource
		fun supabase(registry: DynamicPropertyRegistry) {
			registry.add("spring.security.oauth2.resourceserver.jwt.jwk-set-uri") { FakeSupabaseAuth.jwkSetUri }
			registry.add("spring.security.oauth2.resourceserver.jwt.issuer-uri") { FakeSupabaseAuth.issuer }
			registry.add("grep.web-origin") { "http://web.test" }
		}
	}

	private fun vector(text: String, purpose: EmbeddingPurpose): FloatArray {
		val result = embedder.embed(text, purpose)
		check(result is EmbeddingResult.Vector) { "embedding failed: $result" }
		return result.values
	}

	private fun distance(a: FloatArray, b: FloatArray): Double {
		var dot = 0.0
		var na = 0.0
		var nb = 0.0
		for (i in a.indices) {
			dot += a[i] * b[i]
			na += a[i] * a[i]
			nb += b[i] * b[i]
		}
		return 1 - dot / (sqrt(na) * sqrt(nb))
	}

	@Test
	fun `샘플을받고임베딩워커를돌렸을때_DB거리와메모리거리를재면_보고서를쓰는지`() {
		// given
		val token = FakeSupabaseAuth.token()
		val me = mockMvc.get("/me") { header("Authorization", "Bearer $token") }.andReturn().response.contentAsString
		val userId = UUID.fromString(Regex("\"userId\":\"([^\"]+)\"").find(me)!!.groupValues[1])
		mockMvc.post("/samples") { header("Authorization", "Bearer $token") }.andExpect { status { isCreated() } }
		while (worker.runOnce()) Unit

		// when
		// JdbcEmbeddingQueue.claimNext와 같은 입력 글
		val rows = jdbc.sql(
			"""
			SELECT number, title, embedding IS NOT NULL AS has_embedding, embedding_model,
			       concat_ws(E'\n', nullif(title, ''), nullif(coalesce(user_summary, handoff_summary), ''),
			                 nullif(left(CASE WHEN kind = 'text' THEN text_body ELSE body_text END, 2000), '')) AS input
			FROM items WHERE user_id = :userId ORDER BY number
			""".trimIndent(),
		).param("userId", userId).query().listOfRows()
		val fresh = rows.associate { (it["number"] as Number).toLong() to vector(it["input"] as String, EmbeddingPurpose.DOCUMENT) }
		val report = StringBuilder()
		rows.forEach { report.append("item ").append(it["number"]).append(' ').append(it["title"]).append(" embedded=")
			.append(it["has_embedding"]).append(" model=").append(it["embedding_model"]).append('\n') }
		listOf("텀블러 할인 캠페인", "보온병 할인", "로고 사용 규정").forEach { query ->
			val q = vector(query, EmbeddingPurpose.QUERY)
			val db = jdbc.sql(
				"SELECT number, embedding <=> CAST(:q AS vector) AS d FROM items WHERE user_id = :userId AND embedding IS NOT NULL ORDER BY d",
			).param("q", q.joinToString(",", "[", "]")).param("userId", userId)
				.query { rs, _ -> rs.getLong("number") to rs.getDouble("d") }.list()
			report.append("[").append(query).append("]\n")
			db.forEach { (number, d) ->
				report.append("  ").append(number).append(" db=").append("%.3f".format(d))
					.append(" memory=").append("%.3f".format(distance(q, fresh.getValue(number)))).append('\n')
			}
		}

		// then
		Files.writeString(Path.of("build/embedding-pipeline-report.txt"), report.toString())
	}
}
