package com.unwrap.grep.features.demoseed.domain

import com.fasterxml.jackson.annotation.JsonIgnoreProperties
import com.unwrap.grep.features.archive.domain.FileFormat
import com.unwrap.grep.features.archive.domain.ItemKind
import com.unwrap.grep.features.archive.domain.ItemStatus
import tools.jackson.module.kotlin.jacksonObjectMapper
import tools.jackson.module.kotlin.readValue
import java.nio.file.Files
import java.nio.file.Path

/** `db/seed/demo/seed.json` 한 건(demo-seed 3절). 요약·태그·본문은 미리 만든 값이다. */
@JsonIgnoreProperties(ignoreUnknown = true)
data class SeedEntry(
	val id: String,
	val kind: String,
	val format: String,
	val title: String,
	val savedDaysAgo: Long,
	val status: String,
	val blockedReason: String? = null,
	val url: String? = null,
	val textFile: String? = null,
	val file: String? = null,
	val body: String = "",
	val listSummary: String? = null,
	val handoffSummary: String? = null,
	val tags: List<String> = emptyList(),
) {
	val itemKind: ItemKind get() = ItemKind.entries.first { it.value == kind }
	val itemStatus: ItemStatus get() = ItemStatus.of(status)

	/** 파일 자료만. seed.json `format`은 COM-004 형식 값(`jpeg` 등)이다. */
	val fileFormat: FileFormat get() = FileFormat.entries.first { it.value == format }
}

@JsonIgnoreProperties(ignoreUnknown = true)
data class SeedFile(val version: Int, val items: List<SeedEntry>)

object DemoSeedFile {
	const val FILE_NAME = "seed.json"

	/**
	 * 넣을 순서로 돌려준다. 오래된 것부터 넣어야 S01이 1번이 된다(demo-seed 2절 7번).
	 * 저장일이 겹치면 번호와 날짜 순서가 어긋나므로 거부한다(2절 1번 "모두 다른 날").
	 */
	fun load(seedDir: Path): SeedFile {
		val parsed = jacksonObjectMapper().readValue<SeedFile>(Files.readString(seedDir.resolve(FILE_NAME)))
		val days = parsed.items.map { it.savedDaysAgo }
		require(days.toSet().size == days.size) { "savedDaysAgo must be unique" }
		return parsed.copy(items = parsed.items.sortedByDescending { it.savedDaysAgo })
	}
}
