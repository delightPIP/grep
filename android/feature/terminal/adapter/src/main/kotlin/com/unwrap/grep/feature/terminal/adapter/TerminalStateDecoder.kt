package com.unwrap.grep.feature.terminal.adapter

import com.unwrap.grep.feature.terminal.ui.TerminalBlockUi
import com.unwrap.grep.feature.terminal.ui.TerminalChoiceUi
import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi
import com.unwrap.grep.feature.terminal.ui.TerminalFormat
import com.unwrap.grep.feature.terminal.ui.TerminalItemRefUi
import com.unwrap.grep.feature.terminal.ui.TerminalItemRowUi
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
                "pick" -> "번호 없음  예: 고르기 131"
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
        else -> emptyList()
    }
}

private fun decodeItemRefs(array: JSONArray?): List<TerminalItemRefUi> {
    if (array == null) return emptyList()
    return (0 until array.length()).mapNotNull { i ->
        val obj = array.optJSONObject(i) ?: return@mapNotNull null
        TerminalItemRefUi(number = obj.optInt("number"), title = obj.optString("title", ""))
    }
}

private fun decodeItemRows(array: JSONArray?, pickedNumbers: Set<Int>): List<TerminalItemRowUi> {
    if (array == null) return emptyList()
    return (0 until array.length()).mapNotNull { i ->
        val obj = array.optJSONObject(i) ?: return@mapNotNull null
        decodeItemRow(obj, pickedNumbers)
    }
}

private fun decodeItemRow(obj: JSONObject, pickedNumbers: Set<Int>): TerminalItemRowUi {
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

private fun commandLabel(command: String): String = when (command) {
    "keep" -> "담기"
    "recent" -> "최근"
    "seek" -> "찾기"
    "pick" -> "고르기"
    "handoff" -> "넘기기"
    "guide" -> "도움말"
    "about" -> "설명"
    "signOut" -> "로그아웃"
    "revise" -> "고치기"
    "drop" -> "버리기"
    "revive" -> "되살리기"
    "bin" -> "휴지통"
    else -> command
}

private fun commandFailureLabel(failure: String): String = when (failure) {
    "disconnected" -> "연결 끊김"
    "timedOut" -> "응답 없음"
    "serverError" -> "서버 오류"
    "clipboardDenied" -> "클립보드 거부"
    else -> "오류"
}

private fun aboutDescription(command: String): String = when (command) {
    "keep" -> "링크나 글, 파일을 저장한다. 예: 담기 https://…"
    "recent" -> "최근 저장한 자료 목록을 본다."
    "seek" -> "검색어와 #태그로 자료를 찾는다. 예: 찾기 결제 #웹훅"
    "pick" -> "번호로 넘길 자료를 고른다. 예: 고르기 131 140"
    "handoff" -> "고른 자료를 AI 도구에 붙여 넣을 글로 복사한다."
    "guide" -> "명령 목록을 본다."
    "about" -> "명령 하나를 설명한다. 예: 설명 찾기"
    "signOut" -> "이 기기에서 로그아웃한다."
    "revise" -> "자료의 제목·요약을 고친다. 예: 고치기 131"
    "drop" -> "자료를 휴지통으로 보낸다. 예: 버리기 131"
    "revive" -> "휴지통 자료를 되살린다. 예: 되살리기 131"
    "bin" -> "휴지통 목록을 본다."
    else -> ""
}
