package com.unwrap.grep.features.archive.adapters.scheduling

import com.unwrap.grep.features.archive.domain.TrashService
import org.slf4j.LoggerFactory
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Configuration
import org.springframework.scheduling.annotation.EnableScheduling
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

/**
 * 휴지통 30일 자동 삭제(ARC-008 규칙 7, 비고 개발 답 2026-11-27). 하루 한 번 한국 시간 새벽에 돈다.
 * 서버가 그 시각에 꺼져 있었으면 다음 날 돌 때 밀린 자료까지 함께 지운다.
 */
@Component
@ConditionalOnProperty("grep.trash.purge.enabled", havingValue = "true", matchIfMissing = true)
class TrashPurgeScheduler(private val trash: TrashService) {

	@Scheduled(cron = "\${grep.trash.purge.cron:0 10 3 * * *}", zone = "Asia/Seoul")
	fun purge() {
		val count = trash.purgeExpired()
		if (count > 0) log.info("휴지통 30일 지난 자료 {}건 영구 삭제", count)
	}

	private companion object {
		val log = LoggerFactory.getLogger(TrashPurgeScheduler::class.java)
	}
}

@Configuration(proxyBeanMethods = false)
@EnableScheduling
@ConditionalOnProperty("grep.trash.purge.enabled", havingValue = "true", matchIfMissing = true)
class TrashPurgeSchedulingConfig
