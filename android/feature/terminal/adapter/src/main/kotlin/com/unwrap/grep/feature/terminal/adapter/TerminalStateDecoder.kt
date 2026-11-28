package com.unwrap.grep.feature.terminal.adapter

import com.unwrap.grep.feature.terminal.ui.TerminalBlockUi
import com.unwrap.grep.feature.terminal.ui.TerminalChoiceUi
import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi
import com.unwrap.grep.feature.terminal.ui.TerminalFormat
import com.unwrap.grep.feature.terminal.ui.TerminalTone
import com.unwrap.grep.feature.terminal.ui.TerminalUiState
import org.json.JSONArray
import org.json.JSONObject

/**
 * Swift `TerminalStateEncoder` JSON 문자열을 순수 뷰 상태(`TerminalUiState`)로 변환한다.
 * 문구 원본은 `docs/policies/` 및 iOS `TerminalStateMapper` 기준을 따른다.
 */
internal fun decodeTerminalState(jsonString: String): TerminalUiState {
    if (jsonString.isBlank()) return TerminalUiState()
    val root = runCatching { JSONObject(jsonString) }.getOrNull() ?: return TerminalUiState()

    val itemCount = if (root.has("itemCount") && !root.isNull("itemCount")) root.optInt("itemCount") else null
    val input = root.optString("input", "")
    val processingCount = root.optInt("processingCount", 0)
    val isOffline = root.optBoolean("isOffline", false)
    val selection = decodeItemRefs(root.optJSONArray("selection"))
    val pickedNumbers = selection.map { it.number }.toSet()

    val rawLines = root.optJSONArray("lines") ?: JSONArray()
    val blocks = mutableListOf<MutableBlock>()
    var lastPromptTitle: String? = null

    for (i in 0 until rawLines.length()) {
        val line = rawLines.optJSONObject(i) ?: continue
        val kind = line.optString("kind")
        if (kind == "prompt") {
            val promptText = line.optString("text", "")
            val firstWord = promptText.trim().split(Regex("\\s+")).firstOrNull().orEmpty()
            if (firstWord.isNotEmpty()) lastPromptTitle = firstWord
            blocks += MutableBlock(id = "block_${blocks.size}_$i", prompt = promptText)
            continue
        }
        val current = blocks.lastOrNull() ?: MutableBlock(id = "block_0", prompt = null).also { blocks += it }
        if (kind == "unknownCommand") {
            current.failed = true
        }
        current.entries += decodeLineEntries(line, pickedNumbers)
    }

    return TerminalUiState(
        windowTitle = lastPromptTitle ?: "처음",
        statusText = TerminalFormat.statusText(
            itemCount = itemCount,
            selectionCount = selection.size,
            processingCount = processingCount,
            isOffline = isOffline,
        ),
        isOffline = isOffline,
        itemCount = itemCount,
        input = input,
        selection = selection,
        blocks = blocks.map { TerminalBlockUi(it.id, it.prompt, it.failed, it.entries) },
    )
}

private class MutableBlock(
    val id: String,
    val prompt: String?,
    var failed: Boolean = false,
    val entries: MutableList<TerminalEntryUi> = mutableListOf(),
)

private fun decodeLineEntries(line: JSONObject, pickedNumbers: Set<Int>): List<TerminalEntryUi> {
    return when (line.optString("kind")) {
        "unknownCommand" -> {
            val name = line.optString("text", "")
            listOf(TerminalEntryUi.TextLine(TerminalTone.ERROR, "✗", "없는 명령:", " $name"))
        }
        "missingArgument" -> {
            val message = when (line.optString("command")) {
                "keep" -> "저장할 것 없음  예: 담기 https://…"
                "seek" -> "검색어 없음  예: 찾기 결제"
                // #154 `고르기 빼기`를 번호 없이 치면 빼기 예시.
                "pick" -> if (line.optString("sub") == "unpick") "번호 없음  예: 고르기 빼기 131" else "번호 없음  예: 고르기 131"
                // ARC-011·ARC-012 사용자 문구.
                "peek" -> "번호 없음  예: 열기 131"
                "gather" -> "검색어 없음  예: 찾아두기 텀블러 캠페인"
                else -> return emptyList()
            }
            listOf(TerminalEntryUi.TextLine(TerminalTone.ERROR, "✗", message))
        }
        "missingTag" -> listOf(
            TerminalEntryUi.TextLine(TerminalTone.ERROR, "✗", "태그 없음  예: 찾기 #결제"),
        )
        "saved" -> {
            val item = line.optJSONObject("item") ?: return emptyList()
            val kind = item.optString("kind")
            val title = item.optString("title")
            val source = item.optString("source").takeIf { item.has("source") && !item.isNull("source") && it.isNotEmpty() }
            val status = item.optString("status")
            val mainText = when {
                kind == "text" -> "저장됨 (글)  ${TerminalFormat.formatTextTitle(title)}"
                source != null -> "저장됨  $title ($source)"
                else -> "저장됨  $title"
            }
            buildList {
                add(TerminalEntryUi.TextLine(TerminalTone.OK, "✓", mainText))
                if (status == "received" || status == "processing") {
                    add(TerminalEntryUi.TextLine(TerminalTone.MUTED, "·", "요약 생성 중"))
                }
            }
        }
        "alreadySaved" -> {
            val itemObj = line.optJSONObject("item") ?: return emptyList()
            val item = decodeItemRow(itemObj, pickedNumbers)
            listOf(
                TerminalEntryUi.TextLine(
                    TerminalTone.WARN,
                    "!",
                    "이미 저장됨 → ${item.number}번 (새로 만들지 않음)",
                ),
                TerminalEntryUi.ItemRow(item),
                TerminalEntryUi.CommandHint(
                    prefix = "→ ",
                    command = "고르기 ${item.number}",
                    submitImmediately = true,
                ),
            )
        }
        "inTrash" -> {
            val number = line.optInt("number")
            listOf(
                TerminalEntryUi.TextLine(
                    TerminalTone.WARN,
                    "!",
                    "휴지통에 있음 → ${number}번. 되살리기 $number",
                ),
            )
        }
        "saveFailed" -> {
            val failure = line.optString("failure")
            val recovery = line.optString("recovery")
            val fileName = line.optString("fileName")
            val fileExt = line.optString("fileExtension")
            val bytes = line.optInt("bytes", 0)
            val failureText = when (failure) {
                "disconnected" -> "연결 끊김"
                "timedOut" -> "응답 없음"
                "serverError" -> "서버 오류"
                "unsupportedFormat" -> "받지 않는 형식 (.$fileExt)"
                "tooLarge" -> "20MB 넘음 ($fileName · ${TerminalFormat.formatMegabytes(bytes)})"
                else -> "오류"
            }
            val isNetworkFailure = failure == "disconnected" || failure == "timedOut" || failure == "serverError"
            val recoverySuffix = when (recovery) {
                "inputKept" -> "  입력은 남겨 둠"
                "file" -> if (isNetworkFailure && fileName.isNotEmpty()) " ($fileName)" else ""
                else -> ""
            }
            buildList {
                add(TerminalEntryUi.TextLine(TerminalTone.ERROR, "✗", "저장 안 됨: $failureText$recoverySuffix"))
                if (recovery == "retry") {
                    val retry = line.optString("retry")
                    if (retry.isNotEmpty()) {
                        add(TerminalEntryUi.CommandHint(prefix = "→ 다시: ", command = retry, submitImmediately = true))
                    }
                }
            }
        }
        "recentList" -> {
            val items = decodeItemRows(line.optJSONArray("items"), pickedNumbers)
            val hasMore = line.optBoolean("hasMore", false)
            listOf(TerminalEntryUi.ItemList(header = null, items = items, hasMore = hasMore))
        }
        "searchResult" -> {
            val total = line.optInt("total", 0)
            val items = decodeItemRows(line.optJSONArray("items"), pickedNumbers)
            val hasMore = line.optBoolean("hasMore", false)
            val header = if (items.size < total) "${total}건 중 ${items.size}건" else "${total}건"
            listOf(TerminalEntryUi.ItemList(header = header, items = items, hasMore = hasMore))
        }
        "noResults" -> {
            val queryText = line.optJSONObject("query")?.optString("text").orEmpty()
            val recent = decodeItemRows(line.optJSONArray("items"), pickedNumbers)
            buildList {
                add(TerminalEntryUi.TextLine(TerminalTone.MUTED, "·", "0건: \"$queryText\""))
                if (recent.isNotEmpty()) {
                    add(TerminalEntryUi.TextLine(TerminalTone.MUTED, "·", "최근 저장 ${recent.size}건 (검색 결과 아님)"))
                    add(TerminalEntryUi.ItemList(header = null, items = recent, hasMore = false))
                }
            }
        }
        "picked" -> {
            val refs = decodeItemRefs(line.optJSONArray("refs"))
            val titles = refs.joinToString(" · ") { it.title }
            listOf(
                TerminalEntryUi.TextLine(TerminalTone.OK, "✓", "선택 ${refs.size}건  $titles"),
                TerminalEntryUi.CommandHint(
                    prefix = "→ ",
                    command = "넘기기",
                    suffix = " 또는 묶음 <이름>",
                    submitImmediately = true,
                ),
            )
        }
        "notFound" -> {
            val arr = line.optJSONArray("numbers") ?: JSONArray()
            val nums = (0 until arr.length()).map { arr.optInt(it) }.joinToString(", ")
            listOf(TerminalEntryUi.TextLine(TerminalTone.ERROR, "✗", "없는 번호: $nums"))
        }
        "invalidNumber" -> {
            val input = line.optString("text", "")
            listOf(TerminalEntryUi.TextLine(TerminalTone.ERROR, "✗", "잘못된 번호: $input  예: 고르기 131 140"))
        }
        "handedOff" -> {
            val handoff = line.optJSONObject("handoff") ?: return emptyList()
            val items = decodeItemRefs(handoff.optJSONArray("items"))
            val charCount = TerminalFormat.formatCount(handoff.optInt("charCount", 0))
            val missing = handoff.optInt("missingSummaryCount", 0)
            val text = handoff.optString("text", "")
            listOf(
                TerminalEntryUi.HandedOff(
                    summaryLine = "복사됨  ${items.size}건 · ${charCount}자 (제목·출처·저장 시각·요약)",
                    items = items,
                    missingSummaryCount = missing,
                    previewText = text,
                ),
            )
        }
        "handoffFailed" -> {
            val failure = line.optString("failure")
            val reason = commandFailureLabel(failure)
            val preview = line.optString("preview").takeIf { line.has("preview") && !line.isNull("preview") && it.isNotEmpty() }
            listOf(
                TerminalEntryUi.HandoffFailed(
                    errorLine = "복사 안 됨: $reason  선택은 남겨 둠",
                    isClipboardDenied = failure == "clipboardDenied",
                    previewText = preview,
                ),
            )
        }
        "commandFailed" -> {
            val cmdLabel = commandLabel(line.optString("command"))
            val reason = commandFailureLabel(line.optString("failure"))
            val retry = line.optString("retry")
            buildList {
                add(TerminalEntryUi.TextLine(TerminalTone.ERROR, "✗", "$cmdLabel 안 됨: $reason"))
                if (retry.isNotEmpty()) {
                    add(TerminalEntryUi.CommandHint(prefix = "→ 다시: ", command = retry, submitImmediately = true))
                }
            }
        }
        "handoffConfirm" -> {
            val total = line.optInt("total", 0)
            val choices = buildList {
                if (total > 10) add(TerminalChoiceUi(command = "앞10", label = "앞 10건만"))
                add(TerminalChoiceUi(command = "전부", label = "${total}건 전부"))
                add(TerminalChoiceUi(command = "취소", label = "그 외 입력"))
            }
            listOf(
                TerminalEntryUi.HandoffConfirm(
                    warningLine = "${total}건: 바로 복사 안 함 (5건 초과)",
                    choices = choices,
                ),
            )
        }
        "cancelled" -> listOf(TerminalEntryUi.TextLine(TerminalTone.MUTED, "·", "취소됨"))
        "welcome" -> listOf(TerminalEntryUi.Welcome)
        "guide" -> listOf(
            TerminalEntryUi.Guide(
                header = "저장: 링크·글 붙여 넣기, 파일 끌어다 놓기. 명령: 한글·영문 같음",
                rows = TerminalFormat.guideRows,
                exampleCommand = "찾기 결제 | 넘기기",
            ),
        )
        "about" -> {
            val cmd = line.optString("command")
            listOf(
                TerminalEntryUi.TextLine(
                    tone = TerminalTone.INFO,
                    symbol = "·",
                    emphasis = commandLabel(cmd),
                    tail = "  ${aboutDescription(cmd)}",
                ),
            )
        }
        "reconnected" -> listOf(TerminalEntryUi.TextLine(TerminalTone.OK, "✓", "연결됨"))
        else -> decodeFeatureLine(line, pickedNumbers) ?: emptyList()
    }
}
