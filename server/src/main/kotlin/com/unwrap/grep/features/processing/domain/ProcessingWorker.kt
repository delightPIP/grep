package com.unwrap.grep.features.processing.domain

import com.unwrap.grep.features.archive.api.ItemBody
import com.unwrap.grep.features.archive.api.ItemOriginals
import com.unwrap.grep.features.archive.api.ProcessingJob
import com.unwrap.grep.features.archive.api.ProcessingOutcome
import com.unwrap.grep.features.archive.api.ProcessingQueue
import org.slf4j.LoggerFactory
import java.nio.charset.Charset
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * 처리 작업 한 건: 본문 읽기 → 하루 한도 → 요약·태그(ARC-005, ARC-006, COM-004, COM-005, ARC-002, ARC-004).
 * 본문 읽기는 AI 처리가 아니므로 한도에 닿아도 하고, 찾기 본문(search_text)은 그대로 쌓는다(COM-005 규칙 3).
 */
class ProcessingWorker(
	private val queue: ProcessingQueue,
	private val originals: ItemOriginals,
	private val fetcher: LinkFetcher,
	private val documents: DocumentText,
	private val summarizer: Summarizer,
	private val clock: Clock,
	private val limits: ProcessingLimits,
) {
	/** 작업 하나를 처리했으면 true, 기다리는 작업이 없으면 false. */
	fun runOnce(): Boolean {
		val job = queue.claimNext(LEASE, limits.lowPriorityGate(startOfKoreanDay(clock.instant()))) ?: return false
		if (job.inTrash) {
			queue.discard(job)
			return true
		}
		try {
			process(job)
		} catch (e: RuntimeException) {
			log.warn("processing job {} crashed", job.jobId, e)
			retryOrFail(job, "crash: ${e.javaClass.simpleName}", null)
		}
		return true
	}

	private fun process(job: ProcessingJob) {
		val content = when (val read = read(job)) {
			is Read.Content -> read
			is Read.Blocked -> return finish(job, ProcessingOutcome.Blocked(read.reason, read.searchBody))
			is Read.Transient -> return retryOrFail(job, read.error, null)
			is Read.Failed -> return finish(job, ProcessingOutcome.Failed(read.error, null))
		}
		val searchBody = content.text?.take(MAX_SEARCH_CHARS)
		// 글 자료는 text_body가 곧 본문이라 따로 남기지 않는다(V5).
		val body = content.text?.takeIf { job.kind != "text" }?.let { ItemBody.of(it) }
		if (limits.exceeded(queue.countClaimedSince(job.userId, startOfKoreanDay(clock.instant())))) {
			return finish(job, ProcessingOutcome.Failed("daily_limit", searchBody, body))
		}
		val input = SummaryInput(job.title, job.source, content.text?.let(::forLlm), content.image)
		when (val result = summarizer.summarize(input)) {
			is SummaryResult.Summary -> finish(job, ready(job, content, result, searchBody, body))
			is SummaryResult.Refused -> finish(job, ProcessingOutcome.Failed("refused: ${result.reason}", searchBody, body))
			is SummaryResult.Transient -> retryOrFail(job, result.error, searchBody, body)
		}
	}

	/** 빈 요약은 거절과 같이 `failed`(H-06 가정). 글자 없는 이미지는 `blocked`(no_text, handoff-format 3절). */
	private fun ready(
		job: ProcessingJob,
		content: Read.Content,
		result: SummaryResult.Summary,
		searchBody: String?,
		textBody: ItemBody?,
	): ProcessingOutcome {
		if (content.image != null && result.imageText.isNullOrBlank()) return ProcessingOutcome.Blocked(NO_TEXT, null)
		val body = textBody ?: result.imageText?.let { ItemBody.of(it, fromImage = true) }
		if (result.listSummary.isBlank() || result.handoffSummary.isBlank()) {
			return ProcessingOutcome.Failed("empty response", searchBody, body)
		}
		val truncatedForLlm = (content.text?.length ?: 0) > MAX_LLM_CHARS
		return ProcessingOutcome.Ready(
			fetchedTitle = content.title,
			listSummary = result.listSummary.trim(),
			handoffSummary = result.handoffSummary.trim(),
			tags = Tags.normalize(result.tags),
			partialNote = content.partialNote ?: PARTIAL_BODY.takeIf { truncatedForLlm },
			model = summarizer.model,
			promptVersion = summarizer.promptVersion,
			searchBody = searchBody ?: result.imageText?.take(MAX_SEARCH_CHARS),
			body = body,
		)
	}

	private fun read(job: ProcessingJob): Read = when (job.kind) {
		"text" -> Read.Content(text = job.textBody.orEmpty())
		"link" -> readLink(job.url ?: return Read.Failed("link without url"))
		"file" -> readFile(job)
		else -> Read.Failed("unknown kind ${job.kind}")
	}

	private fun readLink(url: String): Read = when (val fetched = fetcher.fetch(url)) {
		is FetchResult.Blocked -> Read.Blocked(fetched.reason)
		is FetchResult.Transient -> Read.Transient(fetched.error)
		is FetchResult.Failed -> Read.Failed(fetched.error)
		is FetchResult.Fetched -> {
			val partial = PARTIAL_BODY.takeIf { fetched.truncated }
			when (fetched.mediaType) {
				"text/html", "application/xhtml+xml" -> {
					val page = HtmlText.parse(String(fetched.bytes, charset(fetched.charset)))
					Read.Content(text = page.text, title = page.title, partialNote = partial)
				}
				"text/plain", "text/markdown" -> Read.Content(text = String(fetched.bytes, charset(fetched.charset)), partialNote = partial)
				"application/pdf" -> if (fetched.truncated) Read.Failed("pdf over size limit") else fromDocument(documents.pdf(fetched.bytes))
				else -> Read.Failed("unsupported media type ${fetched.mediaType}")
			}
		}
	}

	private fun readFile(job: ProcessingJob): Read {
		val path = job.objectPath ?: return Read.Failed("file without object path")
		val bytes = originals.read(path, MAX_FILE_BYTES) ?: return Read.Failed("original missing or too large")
		return when (val format = job.fileFormat) {
			"pdf" -> fromDocument(documents.pdf(bytes))
			"docx" -> fromDocument(documents.docx(bytes))
			"md", "txt" -> Read.Content(text = String(bytes, Charsets.UTF_8))
			in IMAGE_MIME -> Read.Content(image = SummaryImage(bytes, IMAGE_MIME.getValue(format!!)))
			else -> Read.Failed("unknown file format $format")
		}
	}

	/** COM-004 규칙 6: 암호 걸린 PDF, 글자를 꺼내지 못한 PDF·docx는 `blocked`. */
	private fun fromDocument(result: ExtractResult): Read = when (result) {
		is ExtractResult.Text ->
			if (result.text.isBlank()) Read.Blocked(NO_TEXT) else Read.Content(text = result.text, partialNote = result.partialNote)
		ExtractResult.Encrypted -> Read.Blocked("encrypted")
		ExtractResult.Unreadable -> Read.Blocked(NO_TEXT)
	}

	/** 일시적 오류는 [MAX_ATTEMPTS]번까지 미뤄 다시 하고, 다 쓰면 `failed`(ARC-005 규칙 5). */
	private fun retryOrFail(job: ProcessingJob, error: String, searchBody: String?, body: ItemBody? = null) {
		if (job.attempts >= MAX_ATTEMPTS) return finish(job, ProcessingOutcome.Failed(error, searchBody, body))
		queue.retryLater(job, RETRY_DELAY.multipliedBy(job.attempts.toLong()), error)
	}

	private fun finish(job: ProcessingJob, outcome: ProcessingOutcome) {
		if (!queue.finish(job, outcome)) log.info("job {} discarded: item moved to trash", job.jobId)
	}

	/** 넘기는 글은 앞부분만 보낸다. 넘치면 `본문 일부만 가져옴`을 붙인다. */
	private fun forLlm(text: String): String = text.take(MAX_LLM_CHARS)

	private fun charset(name: String?): Charset =
		name?.let { runCatching { Charset.forName(it) }.getOrNull() } ?: Charsets.UTF_8

	private fun startOfKoreanDay(now: Instant): Instant = LocalDate.ofInstant(now, KOREA).atStartOfDay(KOREA).toInstant()

	private sealed interface Read {
		data class Content(
			val text: String? = null,
			val image: SummaryImage? = null,
			val title: String? = null,
			val partialNote: String? = null,
		) : Read

		data class Blocked(val reason: String, val searchBody: String? = null) : Read
		data class Transient(val error: String) : Read
		data class Failed(val error: String) : Read
	}

	companion object {
		/** 일시적 오류 시도 횟수와 간격(ARC-005 규칙 5, 개발자 값). */
		const val MAX_ATTEMPTS = 3
		val RETRY_DELAY: Duration = Duration.ofMinutes(1)

		/** 리스. 이보다 오래 `running`이면 워커가 죽은 것으로 보고 다시 집는다. */
		val LEASE: Duration = Duration.ofMinutes(5)

		/** COM-004 파일 하나 20MB. */
		const val MAX_FILE_BYTES = 20L * 1024 * 1024

		/** LLM에 보내는 본문 글자 수와 찾기 본문 글자 수(개발자 값). */
		const val MAX_LLM_CHARS = 30_000
		const val MAX_SEARCH_CHARS = 20_000

		/** ARC-004 사용자 문구. */
		const val PARTIAL_BODY = "본문 일부만 가져옴"
		const val NO_TEXT = "no_text"

		/**
		 * 이미지는 원본 그대로 보낸다(COM-004 규칙 5). HEIC도 JPEG로 바꾸지 않는다.
		 * Gemini가 image/heic를 받아 요약하는 것을 실측했다(2026-11-27, gemini-3.5-flash, GeminiSummarizerLiveTest, #117).
		 */
		val IMAGE_MIME = mapOf("png" to "image/png", "jpeg" to "image/jpeg", "webp" to "image/webp", "heic" to "image/heic")

		private val KOREA: ZoneId = ZoneId.of("Asia/Seoul")
		private val log = LoggerFactory.getLogger(ProcessingWorker::class.java)
	}
}
