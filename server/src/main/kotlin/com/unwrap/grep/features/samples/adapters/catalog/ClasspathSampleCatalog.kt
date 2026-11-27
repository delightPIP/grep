package com.unwrap.grep.features.samples.adapters.catalog

import com.fasterxml.jackson.annotation.JsonIgnoreProperties
import com.unwrap.grep.features.demoseed.domain.SeedEntry
import com.unwrap.grep.features.demoseed.domain.SeedFile
import com.unwrap.grep.features.samples.domain.Sample
import com.unwrap.grep.features.samples.domain.SampleCatalog
import org.springframework.core.io.ClassPathResource
import org.springframework.stereotype.Component
import tools.jackson.databind.JsonNode
import tools.jackson.module.kotlin.jacksonObjectMapper
import tools.jackson.module.kotlin.readValue
import tools.jackson.module.kotlin.treeToValue
import java.net.URI

@JsonIgnoreProperties(ignoreUnknown = true)
private data class SamplesFile(val seedFile: String? = null, val items: List<JsonNode>)

/**
 * jar 안 `seed/`(build.gradle.kts가 db/seed/samples와 db/seed/demo를 복사한다). `seed/samples/samples.json`을 읽는다.
 * 항목이 `{"seed": "S04"}`이면 `seedFile`(데모 seed.json)의 그 자료를 쓰고 파일 경로는 seed.json 기준이다.
 * 아니면 seed.json 항목과 같은 모양이고 파일 경로는 samples.json 기준이다. 저장 순서는 `items` 순서다.
 */
@Component
class ClasspathSampleCatalog : SampleCatalog {
	private val json = jacksonObjectMapper()

	override fun load(): List<Sample> {
		val samples = json.readValue<SamplesFile>(read(SAMPLES_FILE))
		val samplesDir = parent(SAMPLES_FILE)
		val seedPath = samples.seedFile?.let { resolve(samplesDir, it) }
		val seedEntries = seedPath?.let { path -> json.readValue<SeedFile>(read(path)).items.associateBy { it.id } }.orEmpty()
		return samples.items.map { node ->
			val seedId = node.get("seed")?.asString()
			if (seedId == null) {
				Sample(json.treeToValue<SeedEntry>(node)) { read(resolve(samplesDir, it)) }
			} else {
				val entry = requireNotNull(seedEntries[seedId]) { "sample seed not found: $seedId" }
				Sample(entry) { read(resolve(parent(seedPath!!), it)) }
			}
		}
	}

	private fun read(path: String): ByteArray = ClassPathResource(path).inputStream.use { it.readAllBytes() }

	private fun parent(path: String): String = path.substringBeforeLast('/') + "/"

	/** `../demo/seed.json` 같은 상대 경로를 풀되 `seed/` 밖으로는 나가지 않는다. */
	private fun resolve(dir: String, relative: String): String {
		val path = URI(null, null, dir, null).resolve(URI(null, null, relative, null)).path
		require(path.startsWith(ROOT)) { "sample path must stay in $ROOT: $relative" }
		return path
	}

	private companion object {
		const val ROOT = "seed/"
		const val SAMPLES_FILE = "seed/samples/samples.json"
	}
}
