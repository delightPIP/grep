package com.unwrap.grep.features.processing.adapters.gemini

import com.unwrap.grep.features.archive.api.EmbeddingPurpose
import com.unwrap.grep.features.archive.api.EmbeddingResult
import com.unwrap.grep.features.demoseed.domain.DemoSeedFile
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable
import java.nio.file.Path
import kotlin.math.sqrt
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * 실제 Gemini 임베딩으로 뜻 찾기 거리 기준을 재는 수동 확인(#128, ADR-BCK-016 값 칸). `GEMINI_API_KEY`가 있을 때만 돈다.
 * 실행: `server/.env`를 환경변수로 올린 뒤 `./gradlew test --tests '*GeminiEmbedderLiveTest' -i`. 거리 표가 표준 출력에 찍힌다.
 * 데모 시드(지어낸 자료)만 보낸다(COM-002 규칙 3). 시드 34건 + 검색어 8건을 한 건씩 부른다.
 */
@EnabledIfEnvironmentVariable(named = "GEMINI_API_KEY", matches = ".+")
class GeminiEmbedderLiveTest {

	private val embedder = GeminiEmbedder(
		System.getenv("GEMINI_API_KEY"),
		System.getenv("GEMINI_EMBEDDING_MODEL")?.takeIf { it.isNotBlank() } ?: "gemini-embedding-001",
		"https://generativelanguage.googleapis.com",
	)

	private fun vector(text: String, purpose: EmbeddingPurpose): FloatArray {
		val result = embedder.embed(text, purpose)
		check(result is EmbeddingResult.Vector) { "embedding failed: $result" }
		return result.values
	}

	/** pgvector `<=>`와 같은 코사인 거리. */
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
	fun `시드자료와검색어를임베딩했을때_거리를재면_뜻이가까운검색어가먼검색어보다가까운지`() {
		// given
		val seed = DemoSeedFile.load(Path.of("../db/seed/demo")).items
		// JdbcEmbeddingQueue와 같은 입력: 제목·요약·본문 앞 2천 자
		val documents = seed.associate { entry ->
			entry.id to vector(
				listOfNotNull(entry.title, entry.handoffSummary, entry.body.take(2_000)).filter { it.isNotBlank() }.joinToString("\n"),
				EmbeddingPurpose.DOCUMENT,
			)
		}
		val related = listOf("보온병 할인 행사", "따뜻한 음료 신메뉴", "로고 사용 규정", "인스타 올리는 시간대")
		val unrelated = listOf("주식 투자 전략", "자동차 엔진오일 교체", "고양이 사료 추천", "해외 축구 이적 소식")

		// when
		val nearest = (related + unrelated).associateWith { query ->
			val q = vector(query, EmbeddingPurpose.QUERY)
			documents.map { (id, doc) -> id to distance(q, doc) }.sortedBy { it.second }.take(3)
		}

		// then
		nearest.forEach { (query, top) ->
			println("live distance [$query] " + top.joinToString { (id, d) -> "$id=${"%.3f".format(d)}" })
		}
		val worstRelated = related.maxOf { nearest.getValue(it).first().second }
		val bestUnrelated = unrelated.minOf { nearest.getValue(it).first().second }
		println("live distance: related 1st max=${"%.3f".format(worstRelated)}, unrelated 1st min=${"%.3f".format(bestUnrelated)}")
		assertTrue(worstRelated < bestUnrelated, "related $worstRelated should be closer than unrelated $bestUnrelated")
	}
}
