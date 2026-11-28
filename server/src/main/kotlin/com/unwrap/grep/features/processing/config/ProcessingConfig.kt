package com.unwrap.grep.features.processing.config

import com.unwrap.grep.features.archive.api.Embedder
import com.unwrap.grep.features.archive.api.EmbeddingQueue
import com.unwrap.grep.features.archive.api.ItemOriginals
import com.unwrap.grep.features.archive.api.ProcessingQueue
import com.unwrap.grep.features.processing.domain.DocumentText
import com.unwrap.grep.features.processing.domain.EmbeddingWorker
import com.unwrap.grep.features.processing.domain.LinkFetcher
import com.unwrap.grep.features.processing.domain.ProcessingLimits
import com.unwrap.grep.features.processing.domain.ProcessingWorker
import com.unwrap.grep.features.processing.domain.Summarizer
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import java.time.Clock

@Configuration(proxyBeanMethods = false)
class ProcessingConfig {

	@Bean
	fun processingLimits(
		@Value("\${grep.processing.daily-limit}") dailyLimit: Int,
		@Value("\${grep.processing.direct-save-reserve}") directSaveReserve: Int,
	) = ProcessingLimits(dailyLimit, directSaveReserve)

	@Bean
	fun processingWorker(
		queue: ProcessingQueue,
		originals: ItemOriginals,
		fetcher: LinkFetcher,
		documents: DocumentText,
		summarizer: Summarizer,
		clock: Clock,
		limits: ProcessingLimits,
	) = ProcessingWorker(queue, originals, fetcher, documents, summarizer, clock, limits)

	@Bean
	fun embeddingWorker(queue: EmbeddingQueue, embedder: Embedder, clock: Clock) = EmbeddingWorker(queue, embedder, clock)
}
