package com.unwrap.grep.features.processing.domain

/** 링크 본문 가져오기(ARC-006). 열지 않는 주소 검사와 상한은 구현이 지킨다. */
interface LinkFetcher {
	fun fetch(url: String): FetchResult
}

sealed interface FetchResult {
	/** [mediaType]은 `text/html`처럼 매개변수 없는 소문자. [truncated]면 크기 상한에서 끊었다. */
	class Fetched(val bytes: ByteArray, val mediaType: String, val charset: String?, val truncated: Boolean) : FetchResult

	/** V2 `blocked_reason` 값(`login_required`, `access_denied`, `disallowed_url`). 다시 시도하지 않는다. */
	data class Blocked(val reason: String) : FetchResult

	/** 시간 초과, 5xx 등. 나중에 다시 시도한다(ARC-005 규칙 5). */
	data class Transient(val error: String) : FetchResult

	data class Failed(val error: String) : FetchResult
}

/** PDF·docx 글자 꺼내기(COM-004 형식 표). */
interface DocumentText {
	fun pdf(bytes: ByteArray): ExtractResult
	fun docx(bytes: ByteArray): ExtractResult
}

sealed interface ExtractResult {
	/** [partialNote]는 일부만 읽었을 때 요약 끝에 붙일 말(ARC-004 규칙 8). */
	data class Text(val text: String, val partialNote: String? = null) : ExtractResult
	data object Encrypted : ExtractResult
	data object Unreadable : ExtractResult
}

/** 외부 LLM(ADR-BCK-014). 제공사 호출은 이 포트 뒤 어댑터 하나에만 둔다. */
interface Summarizer {
	val model: String
	val promptVersion: String
	fun summarize(input: SummaryInput): SummaryResult
}

class SummaryImage(val bytes: ByteArray, val mimeType: String)

/** COM-002: 보내는 것은 본문 글, 이미지, 제목, 출처뿐이다. 계정 정보는 싣지 않는다. */
class SummaryInput(val title: String, val source: String?, val text: String?, val image: SummaryImage?)

sealed interface SummaryResult {
	/** [imageText]는 이미지에서 읽은 글자(이미지가 아니면 null). 찾기 본문으로 쓴다. */
	data class Summary(
		val listSummary: String,
		val handoffSummary: String,
		val tags: List<String>,
		val imageText: String?,
	) : SummaryResult

	/** 모델이 거절했다(H-06 가정: `failed`). */
	data class Refused(val reason: String) : SummaryResult

	data class Transient(val error: String) : SummaryResult
}
