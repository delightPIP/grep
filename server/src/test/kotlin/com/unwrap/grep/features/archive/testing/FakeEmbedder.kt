package com.unwrap.grep.features.archive.testing

import com.unwrap.grep.features.archive.api.EMBEDDING_DIMENSIONS
import com.unwrap.grep.features.archive.api.Embedder
import com.unwrap.grep.features.archive.api.EmbeddingPurpose
import com.unwrap.grep.features.archive.api.EmbeddingResult
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Primary
import java.util.concurrent.ConcurrentHashMap

/** 실제 Gemini를 부르지 않는 임베딩. 테스트가 글마다 벡터를 정하고, 정하지 않은 글은 Unavailable이다. */
class FakeEmbedder : Embedder {
	val vectors = ConcurrentHashMap<String, FloatArray>()
	val calls = mutableListOf<Pair<String, EmbeddingPurpose>>()

	@Synchronized
	override fun embed(text: String, purpose: EmbeddingPurpose): EmbeddingResult {
		calls += text to purpose
		return vectors[text]?.let { EmbeddingResult.Vector(it, "fake-embedding") } ?: EmbeddingResult.Unavailable("no fake vector")
	}

	companion object {
		/** [axis]번 축의 단위 벡터. 다른 축과 코사인 거리 1, 같은 축과 0. */
		fun axis(axis: Int): FloatArray = FloatArray(EMBEDDING_DIMENSIONS).also { it[axis] = 1f }
	}
}

@TestConfiguration(proxyBeanMethods = false)
class FakeEmbedderConfiguration {
	@Bean
	@Primary
	fun fakeEmbedder(): FakeEmbedder = FakeEmbedder()
}
