package com.unwrap.grep.features.demoseed.config

import com.unwrap.grep.features.archive.domain.ObjectStorage
import com.unwrap.grep.features.demoseed.domain.DemoSeedRepository
import com.unwrap.grep.features.demoseed.domain.DemoSeedService
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.transaction.support.TransactionTemplate
import java.time.Clock

@Configuration(proxyBeanMethods = false)
class DemoSeedConfig {

	@Bean
	fun demoSeedService(repository: DemoSeedRepository, storage: ObjectStorage, transaction: TransactionTemplate, clock: Clock) =
		DemoSeedService(repository, storage, transaction, clock)
}
