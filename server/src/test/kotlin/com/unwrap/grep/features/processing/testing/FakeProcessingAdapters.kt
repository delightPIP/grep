package com.unwrap.grep.features.processing.testing

import com.unwrap.grep.features.processing.domain.FetchResult
import com.unwrap.grep.features.processing.domain.LinkFetcher
import com.unwrap.grep.features.processing.domain.Summarizer
import com.unwrap.grep.features.processing.domain.SummaryInput
import com.unwrap.grep.features.processing.domain.SummaryResult
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Primary

/** 정해 둔 응답을 주는 가짜 가져오기. 테스트마다 [respond]를 바꾼다. */
class FakeLinkFetcher : LinkFetcher {
	var respond: (String) -> FetchResult = { FetchResult.Failed("not set") }
	override fun fetch(url: String): FetchResult = respond(url)
}

/** 실제 Gemini를 부르지 않는 가짜 요약. 받은 입력을 [calls]에 남긴다. */
class FakeSummarizer : Summarizer {
	override val model = "fake-model"
	override val promptVersion = "test"
	val calls = mutableListOf<SummaryInput>()
	var respond: (SummaryInput) -> SummaryResult = { SummaryResult.Refused("not set") }

	override fun summarize(input: SummaryInput): SummaryResult {
		calls += input
		return respond(input)
	}
}

@TestConfiguration(proxyBeanMethods = false)
class FakeProcessingConfiguration {
	@Bean
	@Primary
	fun fakeLinkFetcher() = FakeLinkFetcher()

	@Bean
	@Primary
	fun fakeSummarizer() = FakeSummarizer()
}
