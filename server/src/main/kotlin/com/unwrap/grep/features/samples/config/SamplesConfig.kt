package com.unwrap.grep.features.samples.config

import com.unwrap.grep.features.archive.domain.ObjectStorage
import com.unwrap.grep.features.demoseed.domain.DemoSeedRepository
import com.unwrap.grep.features.samples.domain.SampleCatalog
import com.unwrap.grep.features.samples.domain.SampleRangeRepository
import com.unwrap.grep.features.samples.domain.SampleService
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.transaction.support.TransactionTemplate
import java.time.Clock

@Configuration(proxyBeanMethods = false)
class SamplesConfig {

	@Bean
	fun sampleService(
		catalog: SampleCatalog,
		ranges: SampleRangeRepository,
		items: DemoSeedRepository,
		storage: ObjectStorage,
		transaction: TransactionTemplate,
		clock: Clock,
	) = SampleService(catalog, ranges, items, storage, transaction, clock)
}
