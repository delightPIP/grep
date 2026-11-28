package com.unwrap.grep.features.archive.domain

import com.unwrap.grep.shared.kernel.ApiErrorCode
import com.unwrap.grep.shared.kernel.ApiProblem
import org.jsoup.Jsoup
import org.slf4j.LoggerFactory
import org.springframework.transaction.support.TransactionTemplate
import java.util.UUID

/** 북마크 한 개. [title]은 비어 있으면 null. */
data class Bookmark(val url: String, val title: String?)

/** 브라우저가 내보낸 북마크 HTML(Netscape 형식). 폴더는 보지 않고 `<A HREF>`를 파일 차례대로 읽는다. */
object BookmarkHtml {
	fun parse(html: String): List<Bookmark> =
		Jsoup.parse(html).select("a[href]").map { anchor ->
			Bookmark(anchor.attr("href").trim(), anchor.text().trim().ifEmpty { null })
		}
}

/** openapi `ImportStatus`. */
data class ImportStatus(
	val id: UUID,
	val state: String,
	val total: Int,
	val done: Int,
	val saved: Int,
	val skipped: Int,
	val failed: Int,
	val overLimit: Int,
	val failedUrls: List<String>,
)

/** 링크 한 건의 결과. */
enum class ImportResult { SAVED, SKIPPED, FAILED }

/** imports(V4). 모든 조회는 user_id로 거른다(COM-006). */
interface ImportRepository {
	fun create(userId: UUID, total: Int, overLimit: Int): ImportStatus

	fun find(userId: UUID, id: UUID): ImportStatus?

	/** 한 건 끝날 때마다 센다. 실패면 주소를 [failedUrl]로 남긴다. */
	fun record(id: UUID, result: ImportResult, failedUrl: String?)

	fun finish(id: UUID)
}

/** 가져오기를 요청 스레드 밖에서 돌린다. */
fun interface ImportRunner {
	fun run(task: Runnable)
}

/**
 * 북마크 가져오기(F8, user-flow 10절). 앞 200건만 가져오고 넘는 수는 `overLimit`으로 센다.
 * 같은 링크(COM-001, 휴지통 포함)와 파일 안에서 겹친 링크는 건너뛴다. 처리 작업은 낮은 우선순위로 만든다(ADR-BCK-017).
 * shortcut: 진행은 서버 메모리의 작업이라 도는 중에 서버가 내려가면 그 가져오기는 `running`으로 남는다. 다시 시작이 필요해지면 작업 큐로 옮긴다.
 */
class BookmarkImportService(
	private val imports: ImportRepository,
	private val items: ItemRepository,
	private val transaction: TransactionTemplate,
	private val runner: ImportRunner,
) {

	fun start(userId: UUID, html: String): ImportStatus {
		if (html.isBlank()) throw ApiProblem.invalidRequest("html is required")
		val bookmarks = BookmarkHtml.parse(html)
		val taken = bookmarks.take(MAX_LINKS)
		val status = imports.create(userId, taken.size, bookmarks.size - taken.size)
		runner.run { importAll(userId, status.id, taken) }
		return status
	}

	fun status(userId: UUID, id: UUID): ImportStatus =
		imports.find(userId, id) ?: throw ApiProblem(ApiErrorCode.NOT_FOUND)

	private fun importAll(userId: UUID, id: UUID, bookmarks: List<Bookmark>) {
		try {
			bookmarks.forEach { bookmark ->
				val result = try {
					importOne(userId, bookmark)
				} catch (e: RuntimeException) {
					log.warn("import {} failed on one link", id, e)
					ImportResult.FAILED
				}
				imports.record(id, result, bookmark.url.takeIf { result == ImportResult.FAILED })
			}
		} finally {
			imports.finish(id)
		}
	}

	/** 저장과 같은 차례(사용자 행 잠금 → 같은 링크 → 번호 발급)로 넣어 앱 저장과 겹쳐도 하나만 남는다. */
	private fun importOne(userId: UUID, bookmark: Bookmark): ImportResult {
		val link = LinkNormalizer.normalize(bookmark.url) ?: return ImportResult.FAILED
		return transaction.execute {
			items.lockOwner(userId)
			if (items.findByNormalizedUrl(userId, link.value) != null) return@execute ImportResult.SKIPPED
			items.insert(
				NewItem(
					userId = userId, kind = ItemKind.LINK, title = bookmark.title ?: bookmark.url, source = link.host,
					idempotencyKey = UUID.randomUUID(), url = bookmark.url, normalizedUrl = link.value,
					lowPriority = true,
				),
			)
			ImportResult.SAVED
		}!!
	}

	companion object {
		/** 한 번에 가져오는 링크 수(발표 전 임시값, 공통 열린 질문). */
		const val MAX_LINKS = 200
		private val log = LoggerFactory.getLogger(BookmarkImportService::class.java)
	}
}
