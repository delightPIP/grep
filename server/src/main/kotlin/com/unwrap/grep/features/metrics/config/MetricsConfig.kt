package com.unwrap.grep.features.metrics.config

import com.unwrap.grep.features.archive.api.ItemSavedTimes
import com.unwrap.grep.features.metrics.domain.MetricEventRepository
import com.unwrap.grep.features.metrics.domain.MetricEventService
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import java.time.Clock

@Configuration(proxyBeanMethods = false)
class MetricsConfig {

	@Bean
	fun metricEventService(events: MetricEventRepository, savedTimes: ItemSavedTimes, clock: Clock) =
		MetricEventService(events, savedTimes, clock)
}
