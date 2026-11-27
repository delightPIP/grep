package com.unwrap.grep.features.archive.adapters.async

import com.unwrap.grep.features.archive.domain.ImportRunner
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.core.task.TaskExecutor
import org.springframework.stereotype.Component

/** Spring Boot 기본 작업 실행기(applicationTaskExecutor)에서 가져오기를 돌린다. */
@Component
class ExecutorImportRunner(@Qualifier("applicationTaskExecutor") private val executor: TaskExecutor) : ImportRunner {
	override fun run(task: Runnable) = executor.execute(task)
}
