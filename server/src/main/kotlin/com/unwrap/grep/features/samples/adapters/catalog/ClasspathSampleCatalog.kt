package com.unwrap.grep.features.samples.adapters.catalog

import com.unwrap.grep.features.demoseed.domain.SeedFile
import com.unwrap.grep.features.samples.domain.SampleCatalog
import com.unwrap.grep.features.samples.domain.SampleSet
import org.springframework.core.io.ClassPathResource
import org.springframework.stereotype.Component
import tools.jackson.module.kotlin.jacksonObjectMapper
import tools.jackson.module.kotlin.readValue

/**
 * jar 안 `samples/`(build.gradle.kts가 db/seed/samples를 복사한다). 형식은 데모 시드 seed.json과 같고 `savedDaysAgo`는 쓰지 않는다.
 * 저장 순서는 seed.json `items` 순서다. 파일 경로는 `samples/` 밖을 가리킬 수 없다.
 */
@Component
class ClasspathSampleCatalog : SampleCatalog {

	override fun load(): SampleSet {
		val seed = jacksonObjectMapper().readValue<SeedFile>(read("seed.json"))
		return SampleSet(seed.items) { path -> read(path) }
	}

	private fun read(path: String): ByteArray {
		require(!path.startsWith("/") && ".." !in path.split('/', '\\')) { "sample path must stay in samples/: $path" }
		return ClassPathResource("$ROOT/$path").inputStream.use { it.readAllBytes() }
	}

	private companion object {
		const val ROOT = "samples"
	}
}
