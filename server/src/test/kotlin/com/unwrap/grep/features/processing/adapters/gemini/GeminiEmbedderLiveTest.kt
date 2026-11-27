package com.unwrap.grep.features.processing.adapters.gemini

import com.unwrap.grep.features.archive.api.EmbeddingPurpose
import com.unwrap.grep.features.archive.api.EmbeddingResult
import com.unwrap.grep.features.demoseed.domain.DemoSeedFile
import com.unwrap.grep.features.demoseed.domain.SeedEntry
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable
import java.nio.file.Files
import java.nio.file.Path
import kotlin.math.sqrt
import kotlin.test.Test

/**
 * 실제 Gemini 임베딩으로 뜻 찾기 기준을 재는 수동 측정(#128, ADR-BCK-016 값 절). `GEMINI_API_KEY`가 있을 때만 돈다.
 * 실행: `server/.env`를 환경변수로 올린 뒤 `./gradlew test --tests '*GeminiEmbedderLiveTest'`.
 * 결과 표는 `build/embedding-report.txt`에 쓴다. 데모 시드(지어낸 자료)만 보낸다(COM-002 규칙 3).
 * 문서 입력 구성 몇 가지를 같은 검색어로 비교한다. WORKER는 JdbcEmbeddingQueue가 만드는 입력과 같다.
 */
@EnabledIfEnvironmentVariable(named = "GEMINI_API_KEY", matches = ".+")
class GeminiEmbedderLiveTest {

	private val embedder = GeminiEmbedder(
		System.getenv("GEMINI_API_KEY"),
		System.getenv("GEMINI_EMBEDDING_MODEL")?.takeIf { it.isNotBlank() } ?: "gemini-embedding-001",
		"https://generativelanguage.googleapis.com",
	)
	private val seedDir = Path.of("../db/seed/demo")

	/** 무료 등급 분당 한도에 걸리면 잠깐 쉬고 다시 부른다. */
	private fun vector(text: String, purpose: EmbeddingPurpose): FloatArray {
		repeat(6) { attempt ->
			when (val result = embedder.embed(text, purpose)) {
				is EmbeddingResult.Vector -> return result.values
				is EmbeddingResult.Unavailable -> Thread.sleep(5_000L * (attempt + 1))
			}
		}
		error("embedding failed: $text")
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

	/** 글 자료는 text_body(textFile), 그 밖은 body_text(seed body). */
	private fun body(entry: SeedEntry): String =
		entry.textFile?.let { Files.readString(seedDir.resolve(it)).replace("\r\n", "\n").trimEnd('\n') } ?: entry.body

	private val compositions: Map<String, (SeedEntry) -> String> = mapOf(
		"WORKER" to { e -> listOf(e.title, e.handoffSummary.orEmpty(), body(e).take(2_000)).filter { it.isNotBlank() }.joinToString("\n") },
		"TITLE_SUMMARY" to { e -> listOf(e.title, e.handoffSummary.orEmpty()).filter { it.isNotBlank() }.joinToString("\n") },
		"TITLE_SUMMARY_TAGS" to { e ->
			listOf(e.title, e.handoffSummary.orEmpty(), e.tags.joinToString(" ")).filter { it.isNotBlank() }.joinToString("\n")
		},
		"LABELED" to { e ->
			buildString {
				append("제목: ").append(e.title)
				e.listSummary?.let { append("\n한 줄 요약: ").append(it) }
				if (e.tags.isNotEmpty()) append("\n태그: ").append(e.tags.joinToString(", "))
				e.handoffSummary?.let { append("\n요약: ").append(it) }
			}
		},
		"LABELED_BODY" to { e ->
			buildString {
				append("제목: ").append(e.title)
				e.listSummary?.let { append("\n한 줄 요약: ").append(it) }
				if (e.tags.isNotEmpty()) append("\n태그: ").append(e.tags.joinToString(", "))
				e.handoffSummary?.let { append("\n요약: ").append(it) }
				body(e).take(2_000).takeIf { it.isNotBlank() }?.let { append("\n본문: ").append(it) }
			}
		},
	)

	/** 검색어와 맞아야 하는 시드 자료. 글자가 겹치지 않는 검색어를 일부러 섞었다. */
	private val related = linkedMapOf(
		"텀블러 할인 캠페인" to setOf("S30", "S28", "S23", "S25"),
		"보온병 할인" to setOf("S30", "S28", "S23", "S25"),
		"다회용컵 이벤트" to setOf("S16", "S23", "S28", "S30"),
		"따뜻한 음료 신메뉴" to setOf("S12", "S24", "S27", "S19"),
		"로고 사용 규정" to setOf("S01", "S04"),
		"인스타 올리는 시간대" to setOf("S03", "S26"),
		"연말 매출 분석" to setOf("S20", "S14"),
		"가을 시즌 메뉴 회고" to setOf("S11", "S02"),
		"포장 용기 가격 비교" to setOf("S05"),
		"경쟁 카페 가격표" to setOf("S18", "S28"),
		"짧은 동영상 길이" to setOf("S10"),
		"손님 방문 수 통계" to setOf("S08"),
		"신제품 홍보 기사 초안" to setOf("S12"),
		"팝업 매장 사례" to setOf("S06"),
	)
	private val unrelated = listOf(
		"주식 투자 전략", "자동차 엔진오일 교체", "고양이 사료 추천", "해외 축구 이적 소식", "부동산 청약 조건",
		"파이썬 비동기 프로그래밍", "등산화 고르는 법", "치과 임플란트 비용", "연말정산 공제 항목", "캠핑 텐트 설치",
		"영어 회화 공부법", "노트북 배터리 교체",
	)

	/** 한 검색어의 결과: 거리순 (자료, 거리). */
	private data class Ranked(val query: String, val hits: List<Pair<String, Double>>)

	@Test
	fun `시드자료와검색어를임베딩했을때_입력구성마다거리를재면_보고서를쓰는지`() {
		// given
		val seed = DemoSeedFile.load(seedDir).items.filter { it.status == "ready" }
		val queries = (related.keys + unrelated).associateWith { vector(it, EmbeddingPurpose.QUERY) }

		// when
		val report = StringBuilder()
		compositions.forEach { (name, input) ->
			val documents = seed.associate { it.id to vector(input(it), EmbeddingPurpose.DOCUMENT) }
			val ranked = queries.mapValues { (query, q) ->
				Ranked(query, documents.map { (id, d) -> id to distance(q, d) }.sortedBy { it.second })
			}
			report.append(section(name, ranked))
		}

		// then
		val out = Path.of("build/embedding-report.txt")
		Files.writeString(out, report.toString())
		println("embedding report written to ${out.toAbsolutePath()}")
	}

	private fun section(name: String, ranked: Map<String, Ranked>): String = buildString {
		append("== ").append(name).append('\n')
		related.forEach { (query, expected) ->
			val r = ranked.getValue(query)
			val firstRelevant = r.hits.indexOfFirst { it.first in expected }
			append("R [").append(query).append("] top=").append(top(r)).append(" relevantRank=").append(firstRelevant + 1)
				.append(" gap1-4=").append(fmt(r.hits[3].second - r.hits[0].second)).append('\n')
		}
		unrelated.forEach { query ->
			val r = ranked.getValue(query)
			append("U [").append(query).append("] top=").append(top(r))
				.append(" gap1-4=").append(fmt(r.hits[3].second - r.hits[0].second)).append('\n')
		}
		val relTop = related.keys.map { ranked.getValue(it).hits[0].second }
		val relHit = related.count { (q, e) -> ranked.getValue(q).hits[0].first in e }
		val unrTop = unrelated.map { ranked.getValue(it).hits[0].second }
		append("summary: related top1 in expected ").append(relHit).append('/').append(related.size)
			.append(", related top1 ").append(fmt(relTop.min())).append("~").append(fmt(relTop.max()))
			.append(", unrelated top1 ").append(fmt(unrTop.min())).append("~").append(fmt(unrTop.max())).append('\n')
		append(sweep(ranked)).append('\n')
	}

	/**
	 * 기준 후보를 훑는다. 절대 기준(1위 거리 < X)과 상대 기준(1위 거리 < X 이고 4위-1위 > Y)마다
	 * 관련 검색어에서 맞는 자료를 1위로 내는 수와 무관 검색어에서 무엇이든 내는 수를 센다.
	 */
	private fun sweep(ranked: Map<String, Ranked>): String = buildString {
		val xs = (30..48 step 2).map { it / 100.0 }
		val ys = listOf(0.0, 0.01, 0.02, 0.03, 0.04)
		append("sweep X,Y -> relatedOk/").append(related.size).append(" unrelatedShown/").append(unrelated.size).append('\n')
		for (y in ys) {
			append("  Y=").append(fmt(y)).append(':')
			for (x in xs) {
				val ok = related.count { (q, e) -> shows(ranked.getValue(q), x, y) && ranked.getValue(q).hits[0].first in e }
				val bad = unrelated.count { shows(ranked.getValue(it), x, y) }
				append(" X").append(fmt(x)).append('=').append(ok).append('/').append(bad)
			}
			append('\n')
		}
	}

	private fun shows(r: Ranked, x: Double, y: Double): Boolean =
		r.hits[0].second < x && r.hits[3].second - r.hits[0].second > y

	private fun top(r: Ranked) = r.hits.take(3).joinToString(",") { "${it.first}=${fmt(it.second)}" }

	private fun fmt(value: Double) = "%.3f".format(value)
}
