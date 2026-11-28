package com.unwrap.grep.feature.terminal.adapter

import com.unwrap.grep.feature.terminal.ui.TerminalFormat
import com.unwrap.grep.feature.terminal.ui.TerminalItemRefUi
import com.unwrap.grep.feature.terminal.ui.TerminalItemRowUi
import org.json.JSONArray
import org.json.JSONObject

internal fun decodeItemRefs(array: JSONArray?): List<TerminalItemRefUi> {
    if (array == null) return emptyList()
    return (0 until array.length()).mapNotNull { i ->
        val obj = array.optJSONObject(i) ?: return@mapNotNull null
        TerminalItemRefUi(number = obj.optInt("number"), title = obj.optString("title", ""))
    }
}

internal fun decodeItemRows(array: JSONArray?, pickedNumbers: Set<Int>): List<TerminalItemRowUi> {
    if (array == null) return emptyList()
    return (0 until array.length()).mapNotNull { i ->
        val obj = array.optJSONObject(i) ?: return@mapNotNull null
        decodeItemRow(obj, pickedNumbers)
    }
}

internal fun decodeItemRow(obj: JSONObject, pickedNumbers: Set<Int>): TerminalItemRowUi {
    val number = obj.optInt("number")
    val kind = obj.optString("kind")
    val rawTitle = obj.optString("title", "")
    val title = if (kind == "text") TerminalFormat.formatTextTitle(rawTitle) else rawTitle
    val source = obj.optString("source").takeIf { obj.has("source") && !obj.isNull("source") && it.isNotEmpty() }
    val savedAt = TerminalFormat.formatSavedAt(obj.optString("savedAt", ""))
    val meta = listOfNotNull(source, savedAt.takeIf { it.isNotEmpty() }).joinToString(" · ")
    val status = obj.optString("status")
    val listSummary = obj.optString("listSummary").takeIf { obj.has("listSummary") && !obj.isNull("listSummary") && it.isNotEmpty() }
    val partialNote = obj.optString("partialNote").takeIf { obj.has("partialNote") && !obj.isNull("partialNote") && it.isNotEmpty() }

    val (summary, summaryIsWarning) = when (status) {
        "received", "processing" -> "· 요약 생성 중" to false
        "blocked" -> "! 본문 못 가져옴 → 고치기 $number" to true
        "failed" -> "! 요약 못 만듦  제목·출처만 넘김" to true
        else -> {
            val combined = when {
                listSummary != null && partialNote != null -> "$listSummary ($partialNote)"
                listSummary != null -> listSummary
                else -> null
            }
            combined to false
        }
    }

    val matchedIn = obj.optString("matchedIn").takeIf { obj.has("matchedIn") && !obj.isNull("matchedIn") }
    val matchLabel = if (matchedIn == "imageText") "이미지 속 글자" else null
    val tagsArray = obj.optJSONArray("tags") ?: JSONArray()
    val tags = (0 until minOf(tagsArray.length(), 3)).map { tagsArray.optString(it) }.filter { it.isNotEmpty() }

    return TerminalItemRowUi(
        number = number,
        title = title,
        meta = meta,
        summary = summary,
        summaryIsWarning = summaryIsWarning,
        matchLabel = matchLabel,
        tags = tags,
        isPicked = number in pickedNumbers,
    )
}
