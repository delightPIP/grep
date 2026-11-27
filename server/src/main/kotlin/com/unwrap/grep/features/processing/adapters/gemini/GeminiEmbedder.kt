package com.unwrap.grep.features.processing.adapters.gemini

import com.unwrap.grep.features.archive.api.EMBEDDING_DIMENSIONS
import com.unwrap.grep.features.archive.api.Embedder
import com.unwrap.grep.features.archive.api.EmbeddingPurpose
import com.unwrap.grep.features.archive.api.EmbeddingResult
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import tools.jackson.core.JacksonException
import tools.jackson.module.kotlin.jacksonObjectMapper
import java.io.IOException
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.net.http.HttpTimeoutException
import java.time.Duration

/**
 * Gemini API embedContent(ADR-BCK-016 결정 1·2·5). 한 건씩 부르고 768차원으로 줄여 받는다.
 * 키는 `GEMINI_API_KEY`, 모델은 `GEMINI_EMBEDDING_MODEL`. 요청 모양: https://ai.google.dev/api/embeddings
 */
@Component
class GeminiEmbedder(
	@Value("\${grep.gemini.api-key}") private val apiKey: String,
	@Value("\${grep.gemini.embedding-model}") private val model: String,
	@Value("\${grep.gemini.base-url}") private val baseUrl: String,
) : Embedder {
	private val json = jacksonObjectMapper()
	private val client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build()

	override fun embed(text: String, purpose: EmbeddingPurpose): EmbeddingResult {
		if (apiKey.isBlank()) return EmbeddingResult.Unavailable("GEMINI_API_KEY is not set")
		val body = mapOf(
			"model" to "models/$model",
			"content" to mapOf("parts" to listOf(mapOf("text" to text))),
			"taskType" to if (purpose == EmbeddingPurpose.QUERY) "RETRIEVAL_QUERY" else "RETRIEVAL_DOCUMENT",
			"outputDimensionality" to EMBEDDING_DIMENSIONS,
		)
		val request = HttpRequest.newBuilder(URI("${baseUrl.trimEnd('/')}/v1beta/models/$model:embedContent"))
			.timeout(Duration.ofSeconds(20))
			.header("Content-Type", "application/json")
			.header("x-goog-api-key", apiKey)
			.POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)))
			.build()
		val response = try {
			client.send(request, HttpResponse.BodyHandlers.ofString())
		} catch (e: HttpTimeoutException) {
			return EmbeddingResult.Unavailable("gemini timeout")
		} catch (e: IOException) {
			return EmbeddingResult.Unavailable("gemini io: ${e.javaClass.simpleName}")
		}
		if (response.statusCode() != 200) return EmbeddingResult.Unavailable("gemini http ${response.statusCode()}")
		return parse(response.body())
	}

	internal fun parse(body: String): EmbeddingResult {
		val values = try {
			json.readTree(body).path("embedding").path("values")
		} catch (e: JacksonException) {
			return EmbeddingResult.Unavailable("gemini bad json")
		}
		if (!values.isArray || values.size() != EMBEDDING_DIMENSIONS) {
			return EmbeddingResult.Unavailable("gemini embedding size ${values.size()}")
		}
		return EmbeddingResult.Vector(FloatArray(values.size()) { values[it].floatValue() }, model)
	}
}
