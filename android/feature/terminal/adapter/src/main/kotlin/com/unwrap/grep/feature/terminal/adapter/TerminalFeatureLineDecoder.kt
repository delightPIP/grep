package com.unwrap.grep.feature.terminal.adapter

import com.unwrap.grep.feature.terminal.ui.TerminalChipUi
import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi
import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi.ChipLine
import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi.PlainLine
import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi.TextLine
import com.unwrap.grep.feature.terminal.ui.TerminalTone
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId

/**
 * #93~#137 피처 줄(정리·고치기·샘플·고르기 빼기·모든 기기 로그아웃·묶음·자세히 보기·찾아두기·연결·가져오기)을 그린다.
 * 문구는 웹 `web/features/logged-in/terminal.tsx`의 같은 줄과 같다(근거 정책은 각 줄 주석). 모르는 줄이면 null.
 */
internal fun decodeFeatureLine(line: JSONObject, pickedNumbers: Set<Int>): List<TerminalEntryUi>? =
    when (line.optString("kind")) {
        // ARC-008 정리
        "dropConfirm" -> confirm("버리기? ${line.optInt("total")}건 (휴지통으로)", "버리기")
        "dropped" -> {
            val numbers = refNumbers(line).joinToString(" ")
            listOf(ok("휴지통 ${refNumbers(line).size}건 (30일 뒤 삭제, 되살리기 $numbers)"))
        }
        "revived" -> listOf(ok("되살림 ${refNumbers(line).size}건"))
        "binList" -> binList(line, pickedNumbers)
        "binEmptyConfirm" -> confirm("비우기? ${line.optInt("total")}건 (되돌릴 수 없음)", "비우기")
        "binEmptied" -> {
            val count = line.optInt("count")
            listOf(if (count == 0) info(EMPTY_BIN) else ok("비움  ${count}건 영구 삭제"))
        }
        // ARC-002·004 고치기, ARC-010 샘플
        "revised" -> revised(line)
        "tagsRemoved" -> {
            val tags = line.stringList("tags").joinToString(" ") { "#$it" }
            val number = line.optJSONObject("item")?.optInt("number")
            listOf(ok("태그 지움 $tags (${number}번)"))
        }
        "samplesSaved" -> samplesSaved(line, pickedNumbers)
        // commands 6절 선택 빼기
        "unpicked" -> listOf(ok("뺌  선택 ${line.optInt("remaining")}건 남음"))
        "pickCleared" -> listOf(ok("선택 비움"))
        // ACC-002 모든 기기 로그아웃
        "signOutEverywhereConfirm" -> {
            val count = line.optNullableInt("count")
            val connections = if (count != null && count > 0) " · AI 도구 연결 ${count}개" else ""
            confirm("로그아웃? 모든 기기$connections (다른 기기는 최대 1시간 뒤)", "로그아웃")
        }
        // ARC-003 묶음, ARC-007 규칙 11 폴더 안내
        "bundleList" -> bundleList(line)
        "bundleAdded" -> {
            val name = line.optString("name")
            val already = line.optInt("alreadyCount").let { if (it > 0) " (이미 있음 ${it}건)" else "" }
            listOf(
                ok("묶음 $name: ${line.optInt("count")}건$already"),
                ChipLine(prefix = "→ 다음부터: ", chips = listOf(chip("넘기기 $name"))),
            )
        }
        "bundleView" -> {
            val items = decodeItemRows(line.optJSONArray("items"), pickedNumbers)
            val header = "묶음 ${line.optString("name")}  ${searchHeader(line.optInt("total"), items.size)}"
            listOf(TerminalEntryUi.ItemList(header = header, items = items, hasMore = line.optBoolean("hasMore")))
        }
        "bundleNotFound" -> listOf(
            ChipLine(prefix = "없는 묶음: ${line.optString("name")}  → ", chips = listOf(chip("묶음")), tone = TerminalTone.ERROR),
        )
        "bundleUnpicked" -> listOf(ok("뺌  묶음 ${line.optString("name")}: ${line.optInt("remaining")}건 남음"))
        "notInBundle" -> listOf(error("묶음에 없음: ${line.intList("numbers").joinToString(", ")}"))
        "bundleDeleteConfirm" ->
            confirm("지우기? 묶음 ${line.optString("name")} (자료 ${line.optInt("count")}건은 남음)", "지우기")
        "bundleDeleted" -> listOf(ok("삭제됨  묶음 ${line.optString("name")}"))
        "bundleNameInvalid" -> listOf(
            error(
                if (line.optString("failure") == "reserved") {
                    "묶음 이름: 숫자만 · #시작 · 빼기 · 지우기 불가"
                } else {
                    "묶음 이름: 띄어쓰기 없이 1~20자 (한글·영문·숫자·-·_)"
                },
            ),
        )
        "folderHint" -> listOf(
            ChipLine(
                prefix = "폴더 없음: 묶음이 폴더 역할  → ",
                chips = listOf(TerminalChipUi("고르기 <번호>", "고르기 "), TerminalChipUi("묶음 <이름>", "묶음 ")),
                separator = " · ",
                tone = TerminalTone.MUTED,
            ),
        )
        // ARC-011 자세히 보기
        "itemDetail" -> line.optJSONObject("detail")?.let { listOf(decodeItemDetail(it, pickedNumbers)) } ?: emptyList()
        "oneNumberOnly" -> listOf(error("번호 하나만  예: ${commandLabel(line.optString("command"))} 131"))
        // ARC-012 찾아두기
        "searchSaved" -> searchSaved(line)
        "savedSearchList" -> savedSearchList(line)
        "savedSearchPeriod" -> listOf(
            error("시점은 찾아두지 않음: ${line.optString("text")}"),
            ChipLine(prefix = "→ ", chips = listOf(chip(line.optString("suggestion")))),
        )
        "savedSearchTooLong" -> listOf(error("검색어 40자 초과"))
        "savedSearchDeleteConfirm" -> confirm("지우기? 찾아둔 ${line.optString("text")} (자료는 남음)", "지우기")
        "savedSearchDeleted" -> listOf(ok("지움  찾아둔 ${line.optString("text")}"))
        "savedSearchNotFound" -> listOf(error("찾아둔 것 없음: ${line.optString("text")}"))
        // ACC-002 AI 도구 연결
        "connectionList" -> connectionList(line)
        "disconnectConfirm" -> confirm("끊기? ${line.optString("name")} (다시 연결하려면 처음부터)", "끊기")
        "disconnected" -> {
            val client = line.optString("name")
            listOf(if (line.optBoolean("already")) warn("이미 끊김  $client") else ok("끊김  $client"))
        }
        "connectionNotFound" -> listOf(error("없는 연결: ${line.optInt("number")}"))
        "connectionEnded" -> {
            val reason = if (line.optString("failure") == "expired") "로그인 만료" else "다른 기기에서 끊음"
            listOf(
                warn("연결 끊김: ${line.optString("name")} ($reason)"),
                ChipLine(prefix = "→ ", chips = listOf(chip("연결"))),
            )
        }
        // commands 6절 북마크 가져오기
        "importPrompt" -> listOf(info("북마크 파일을 끌어다 놓기 (브라우저에서 내보낸 HTML, 한 번에 ${IMPORT_LIMIT}건)"))
        "importProgress" -> listOf(
            info("가져오는 중  ${line.optInt("done")} / ${line.optInt("total")}건"),
            PlainLine("  다른 명령을 쳐도 계속됨", dim = true),
        )
        "importFinished" -> importFinished(line)
        "importSuggest" -> listOf(ChipLine(prefix = "→ 북마크 파일이면: ", chips = listOf(chip("가져오기"))))
        else -> null
    }

private const val EMPTY_BIN = "휴지통 비어 있음"
private const val IMPORT_LIMIT = 200

private fun ok(text: String) = TextLine(TerminalTone.OK, "✓", text)
private fun warn(text: String) = TextLine(TerminalTone.WARN, "!", text)
private fun error(text: String) = TextLine(TerminalTone.ERROR, "✗", text)
private fun info(text: String) = TextLine(TerminalTone.MUTED, "·", text)
internal fun chip(command: String) = TerminalChipUi(label = command, command = command)

/** 확인 줄 뒤 `→ 실행: <낱말> 다시 입력 · 취소: 그 외 입력`(COM-007). */
private fun confirm(question: String, word: String): List<TerminalEntryUi> = listOf(
    warn(question),
    ChipLine(prefix = "→ 실행: ", chips = listOf(chip(word)), suffix = " 다시 입력 · 취소: 그 외 입력"),
)

internal fun searchHeader(total: Int, shown: Int): String = if (shown < total) "${total}건 중 ${shown}건" else "${total}건"

private fun binList(line: JSONObject, pickedNumbers: Set<Int>): List<TerminalEntryUi> {
    val total = line.optInt("total")
    if (total == 0) return listOf(info(EMPTY_BIN))
    val trash = line.optJSONArray("trash") ?: JSONArray()
    // ARC-008 규칙 10: 시각 칸에 영구 삭제까지 남은 날.
    val rows = (0 until trash.length()).mapNotNull { index ->
        val entry = trash.optJSONObject(index) ?: return@mapNotNull null
        val item = entry.optJSONObject("item") ?: return@mapNotNull null
        val row = decodeItemRow(item, pickedNumbers)
        val source = item.optNullableString("source")
        val meta = listOfNotNull(source, "${entry.optInt("daysLeft")}일 남음").joinToString(" · ")
        row.copy(meta = meta, summary = null, summaryIsWarning = false, matchLabel = null, tags = emptyList())
    }
    return listOf(
        TerminalEntryUi.ItemList(header = searchHeader(total, rows.size), items = rows, hasMore = line.optBoolean("hasMore")),
        ChipLine(
            prefix = "→ ",
            chips = listOf(TerminalChipUi("되살리기", "되살리기 "), chip("휴지통 비우기")),
        ),
    )
}

private fun revised(line: JSONObject): List<TerminalEntryUi> {
    val item = line.optJSONObject("item") ?: return emptyList()
    return buildList {
        add(ok("고침 ${item.optInt("number")}번  ${item.optString("title")}"))
        val summary = item.optNullableString("listSummary")
        if (item.optString("summarySource") == "user" && summary != null) {
            add(PlainLine("요약 (직접 고침)  $summary", dim = true))
        }
    }
}

private fun samplesSaved(line: JSONObject, pickedNumbers: Set<Int>): List<TerminalEntryUi> {
    val first = line.optInt("firstNumber")
    val last = line.optInt("lastNumber")
    val range = "$first-$last"
    return listOf(
        ok("샘플 ${last - first + 1}건 저장 (${range}번)"),
        ChipLine(prefix = "치우려면: ", chips = listOf(chip("버리기 $range")), tone = TerminalTone.MUTED),
        TerminalEntryUi.ItemList(header = null, items = decodeItemRows(line.optJSONArray("items"), pickedNumbers), hasMore = false),
    )
}

/** 이름 목록 한 줄 `<이름>  N건`. 이름을 누르면 그 명령을 실행한다(commands 6절 출력 원칙). */
private fun nameCountRows(line: JSONObject, commandPrefix: String): List<TerminalEntryUi> {
    val entries = line.optJSONArray("entries") ?: JSONArray()
    return (0 until entries.length()).mapNotNull { index ->
        val entry = entries.optJSONObject(index) ?: return@mapNotNull null
        val name = entry.optString("name")
        ChipLine(
            prefix = "",
            chips = listOf(TerminalChipUi(name, "$commandPrefix$name")),
            suffix = "  ${entry.optInt("count")}건",
        )
    }
}

private fun bundleList(line: JSONObject): List<TerminalEntryUi> {
    val rows = nameCountRows(line, "묶음 ")
    if (rows.isEmpty()) {
        return listOf(
            info("묶음 0개"),
            ChipLine(prefix = "→ ", chips = listOf(TerminalChipUi("고르기 <번호>", "고르기 "))),
            ChipLine(prefix = "→ ", chips = listOf(TerminalChipUi("묶음 <이름>", "묶음 "))),
        )
    }
    return listOf(PlainLine("${rows.size}개 묶음")) + rows
}

private fun searchSaved(line: JSONObject): List<TerminalEntryUi> {
    val query = line.optString("text")
    if (line.optBoolean("already")) return listOf(warn("이미 찾아둠: $query"))
    val total = line.optInt("total")
    return listOf(
        ok("찾아둠: $query  ${total}건"),
        info(if (total == 0) "맞는 자료가 저장되면 모임" else "보관함 저장한 찾기에 있음"),
    )
}

private fun savedSearchList(line: JSONObject): List<TerminalEntryUi> {
    val rows = nameCountRows(line, "찾아두기 ")
    if (rows.isEmpty()) {
        return listOf(
            info("찾아둔 것 없음"),
            ChipLine(prefix = "→ ", chips = listOf(TerminalChipUi("찾아두기 <검색어>", "찾아두기 "))),
        )
    }
    return listOf(PlainLine("${rows.size}개 찾아둠")) + rows
}

private val seoulZone: ZoneId = ZoneId.of("Asia/Seoul")

/** 연결 목록 날짜 `11/20`. 한국 날짜다(ARC-004 규칙 7). */
internal fun connectionDay(iso: String): String = runCatching {
    val date = Instant.parse(iso).atZone(seoulZone)
    "${date.monthValue}/${date.dayOfMonth}"
}.getOrDefault(iso)

private fun connectionList(line: JSONObject): List<TerminalEntryUi> {
    val connections = line.optJSONArray("connections") ?: JSONArray()
    return buildList {
        add(info("연결 주소  ${line.optString("text")}"))
        add(PlainLine("  AI 도구의 연결(MCP) 설정에 이 주소를 넣고 그렙 계정으로 로그인. 연결한 도구는 검색·읽기만 가능", dim = true))
        if (connections.length() == 0) {
            add(info("연결 0개"))
            return@buildList
        }
        add(PlainLine("${connections.length()}개 연결"))
        for (index in 0 until connections.length()) {
            val connection = connections.optJSONObject(index) ?: continue
            val read = connection.optNullableString("lastReadAt")?.let { "  읽음 ${connectionDay(it)}" }.orEmpty()
            add(
                PlainLine(
                    "${connection.optInt("number")}  ${connection.optString("client")}  " +
                        "연결 ${connectionDay(connection.optString("connectedAt"))}$read",
                ),
            )
        }
        add(ChipLine(prefix = "→ ", chips = listOf(TerminalChipUi("연결 끊기 <번호>", "연결 끊기 "))))
    }
}

private fun importFinished(line: JSONObject): List<TerminalEntryUi> {
    val result = line.optJSONObject("importResult") ?: return emptyList()
    return buildList {
        add(
            ok(
                "저장 ${result.optInt("saved")}건 · 건너뜀 ${result.optInt("skipped")}건 (이미 저장됨) · " +
                    "실패 ${result.optInt("failed")}건",
            ),
        )
        result.stringList("failedUrls").forEach { add(PlainLine("  실패: $it", dim = true)) }
        val overLimit = result.optInt("overLimit")
        if (overLimit > 0) {
            add(
                ChipLine(
                    prefix = "${IMPORT_LIMIT}건 넘어 안 가져옴 ${overLimit}건  → 나눠서 다시: ",
                    chips = listOf(chip("가져오기")),
                    tone = TerminalTone.WARN,
                ),
            )
        }
    }
}
