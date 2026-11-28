package com.unwrap.grep.feature.terminal.adapter

import com.unwrap.grep.feature.terminal.ui.TerminalChipUi
import com.unwrap.grep.feature.terminal.ui.TerminalDetailRowUi
import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi
import com.unwrap.grep.feature.terminal.ui.TerminalFormat
import org.json.JSONObject

/** ARC-005·COM-004 `본문 못 가져옴: <이유>`의 이유 낱말. 키는 api 값이다. */
private fun blockedReasonLabel(reason: String?): String? = when (reason) {
    "login_required" -> "로그인 필요"
    "access_denied" -> "접근 거부"
    "disallowed_url" -> "열지 않는 주소"
    "encrypted" -> "암호 걸린 PDF"
    "no_text" -> "글자 없음"
    else -> null
}

/** ARC-011 규칙 6 자세히 보기. 값이 없는 줄은 뺀다. */
internal fun decodeItemDetail(detail: JSONObject, pickedNumbers: Set<Int>): TerminalEntryUi.ItemDetail {
    val item = detail.optJSONObject("item") ?: JSONObject()
    val number = item.optInt("number")
    val kind = item.optString("kind")
    val status = item.optString("status")
    val reason = blockedReasonLabel(item.optNullableString("blockedReason"))
    val previewUrl = detail.optNullableString("previewUrl")
    val body = detail.optNullableString("body")

    val rows = buildList {
        add(
            TerminalDetailRowUi(
                label = "출처",
                value = detailSource(kind, item.optNullableString("source"), previewUrl),
                linkUrl = if (kind == "link") detail.optNullableString("url") else null,
            ),
        )
        add(TerminalDetailRowUi(label = "저장", value = TerminalFormat.formatSavedAt(item.optString("savedAt"))))
        detailStatus(kind, status, reason)?.let { add(it) }
        detail.optNullableString("handoffSummary")?.let { summary ->
            val label = if (item.optString("summarySource") == "user") "요약 (직접 고침)" else "AI 요약"
            add(TerminalDetailRowUi(label = label, value = summary))
        }
        val tags = detail.stringList("allTags")
        if (tags.isNotEmpty()) {
            add(TerminalDetailRowUi(label = "태그 (AI 추정)", value = "", chips = tags.map { TerminalChipUi("#$it", "찾기 #$it") }))
        }
        val bundles = detail.stringList("bundles")
        add(
            if (bundles.isEmpty()) {
                TerminalDetailRowUi(label = "묶음", value = "없음")
            } else {
                TerminalDetailRowUi(label = "묶음", value = "", chips = bundles.map { TerminalChipUi(it, "묶음 $it") })
            },
        )
    }

    val bodyHead = body?.let {
        val from = if (detail.optBoolean("bodyFromImage")) "(이미지에서 읽음) " else ""
        val length = detail.optNullableInt("bodyLength") ?: it.codePointCount(0, it.length)
        val partial = item.optNullableString("partialNote")?.let { note -> " ($note)" }.orEmpty()
        "$from${TerminalFormat.formatCount(length)}자$partial"
    }
    // 처리 중(상태 줄이 알림)과 ready는 본문 줄을 그리지 않는다. failed 이유 `처리 실패`는 handoff-format 3절 낱말.
    val noBodyReason = if (body != null) null else when (status) {
        "failed" -> "처리 실패"
        "blocked" -> reason
        else -> null
    }

    return TerminalEntryUi.ItemDetail(
        number = number,
        title = item.optString("title"),
        isPicked = number in pickedNumbers,
        rows = rows,
        bodyHead = bodyHead,
        body = body,
        bodyExpandedInitially = kind == "text",
        noBodyReason = noBodyReason,
        originalUrl = detail.optNullableString("originalUrl"),
        actions = listOf(
            chip("고르기 $number"),
            TerminalChipUi("묶음 <이름>", "묶음 "),
            chip("고치기 $number"),
            chip("버리기 $number"),
        ),
    )
}

/** ARC-011 규칙 6-2 출처 글. 링크는 호스트, 아니면 `직접 넣음 · <형식>`. 이미지는 미리보기 URL이 있는 파일이다. */
internal fun detailSource(kind: String, source: String?, previewUrl: String?): String = when {
    kind == "link" -> source.orEmpty()
    kind == "text" -> "직접 넣음 · 글"
    previewUrl != null -> "직접 넣음 · 이미지"
    source != null -> "직접 넣음 · ${source.uppercase()}"
    else -> "직접 넣음"
}

/** ARC-005 처리 상태 줄. 파일 이유(COM-004)에는 `제목·링크만 저장`을 붙이지 않는다. ready면 null. */
private fun detailStatus(kind: String, status: String, reason: String?): TerminalDetailRowUi? = when {
    status == "received" || status == "processing" -> TerminalDetailRowUi("상태", "· 요약 생성 중", isMuted = true)
    status == "failed" -> TerminalDetailRowUi("상태", "! 요약 못 만듦  제목·출처만 넘김", isWarning = true)
    status == "blocked" && reason != null -> TerminalDetailRowUi(
        label = "상태",
        value = if (kind == "link") "! 본문 못 가져옴: $reason  제목·링크만 저장" else "! 본문 못 가져옴: $reason",
        isWarning = true,
    )
    else -> null
}
