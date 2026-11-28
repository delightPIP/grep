package com.unwrap.grep.feature.loggedin.adapter

import com.unwrap.grep.feature.loggedin.ui.ArchiveItemRow
import com.unwrap.grep.swiftbridge.ArchiveLoaderHandle
import com.unwrap.grep.swiftbridge.ArchivePageCallback
import org.json.JSONArray
import org.json.JSONObject
import java.util.Optional

/** 보관함 목록 한 쪽 조회 결과. 행 값과 오류 문구는 Swift `ArchiveItemMapper`가 정책대로 만든다. */
sealed interface ArchivePageOutcome {
    data class Page(val rows: List<ArchiveItemRow>, val nextCursor: String?) : ArchivePageOutcome
    data object SessionExpired : ArchivePageOutcome
    data class Failed(val message: String) : ArchivePageOutcome
    data object Cancelled : ArchivePageOutcome
}

/** 보관함 목록 조회 포트. demo 앱과 단위 테스트는 가짜 구현으로 바꾼다. 결과는 메인 스레드에서 돌려준다. */
fun interface ArchiveItemLoader {
    fun loadPage(limit: Int, cursor: String?, onResult: (ArchivePageOutcome) -> Unit)
}

/** Swift `ArchiveLoaderHandle`(`GET /items`)로 목록을 불러온다. */
class SwiftArchiveItemLoader(private val handle: ArchiveLoaderHandle) : ArchiveItemLoader {
    override fun loadPage(limit: Int, cursor: String?, onResult: (ArchivePageOutcome) -> Unit) {
        handle.loadPage(
            limit,
            Optional.ofNullable(cursor),
            object : ArchivePageCallback {
                override fun complete(resultJson: String) {
                    onResult(decodeArchivePage(resultJson))
                }
            },
        )
    }
}

private const val SERVER_ERROR_MESSAGE = "서버 오류"

/** Swift `ArchivePageEncoder`가 만든 JSON을 읽는다. 읽을 수 없으면 서버 오류로 본다. */
internal fun decodeArchivePage(json: String): ArchivePageOutcome {
    val root = runCatching { JSONObject(json) }.getOrNull()
        ?: return ArchivePageOutcome.Failed(SERVER_ERROR_MESSAGE)
    return when (root.optString("type")) {
        "page" -> ArchivePageOutcome.Page(
            rows = decodeRows(root.optJSONArray("items")),
            nextCursor = root.optNullableString("nextCursor"),
        )
        "sessionExpired" -> ArchivePageOutcome.SessionExpired
        "cancelled" -> ArchivePageOutcome.Cancelled
        "failed" -> ArchivePageOutcome.Failed(root.optNullableString("message") ?: SERVER_ERROR_MESSAGE)
        else -> ArchivePageOutcome.Failed(SERVER_ERROR_MESSAGE)
    }
}

private fun decodeRows(array: JSONArray?): List<ArchiveItemRow> {
    if (array == null) return emptyList()
    return (0 until array.length()).mapNotNull { index ->
        val row = array.optJSONObject(index) ?: return@mapNotNull null
        val tags = row.optJSONArray("tags")
        ArchiveItemRow(
            number = row.getInt("number"),
            title = row.optString("title"),
            meta = row.optString("meta"),
            summary = row.optNullableString("summary"),
            summaryIsWarning = row.optBoolean("summaryIsWarning"),
            tags = if (tags == null) emptyList() else (0 until tags.length()).map { tags.optString(it) },
        )
    }
}

private fun JSONObject.optNullableString(name: String): String? =
    if (has(name) && !isNull(name)) optString(name) else null
