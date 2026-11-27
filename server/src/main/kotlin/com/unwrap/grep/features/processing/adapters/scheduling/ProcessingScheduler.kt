package com.unwrap.grep.features.processing.adapters.scheduling

import com.unwrap.grep.features.processing.domain.ProcessingWorker
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Configuration
import org.springframework.scheduling.annotation.EnableScheduling
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

/**
 * 처리 워커는 서버 프로세스 안에서 돈다(ADR-0011 결정 4). 512MB 인스턴스라 스레드 하나로 한 건씩 처리한다.
 * 기다리는 작업이 있으면 한 번에 [BATCH]건까지 이어서 처리하고, 없으면 다음 주기까지 쉰다.
 */
@Component
@ConditionalOnProperty("grep.processing.enabled", havingValue = "true", matchIfMissing = true)
class ProcessingScheduler(private val worker: ProcessingWorker) {

	@Scheduled(fixedDelayString = "\${grep.processing.poll-delay:PT2S}")
	fun poll() {
		repeat(BATCH) { if (!worker.runOnce()) return }
	}

	private companion object {
		const val BATCH = 10
	}
}

@Configuration(proxyBeanMethods = false)
@EnableScheduling
@ConditionalOnProperty("grep.processing.enabled", havingValue = "true", matchIfMissing = true)
class ProcessingSchedulingConfig
