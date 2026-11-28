package com.unwrap.grep.feature.terminal.ui

import java.text.NumberFormat
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

enum class TerminalTone {
    OK,
    WARN,
    ERROR,
    MUTED,
    INFO,
}

data class TerminalItemRefUi(
    val number: Int,
    val title: String,
)

data class TerminalItemRowUi(
    val number: Int,
    val title: String,
    val meta: String,
    val summary: String?,
    val summaryIsWarning: Boolean,
    val matchLabel: String?,
    val tags: List<String>,
    val isPicked: Boolean,
)

data class TerminalChoiceUi(
    val command: String,
    val label: String,
)

data class TerminalGuideRowUi(
    val korean: String,
    val english: String,
    val description: String,
)

sealed interface TerminalEntryUi {
    data class TextLine(
        val tone: TerminalTone,
        val symbol: String,
        val emphasis: String,
        val tail: String = "",
    ) : TerminalEntryUi

    data class ItemList(
        val header: String?,
        val items: List<TerminalItemRowUi>,
        val hasMore: Boolean,
    ) : TerminalEntryUi

    data class ItemRow(
        val item: TerminalItemRowUi,
    ) : TerminalEntryUi

    data class CommandHint(
        val prefix: String,
        val command: String,
        val suffix: String = "",
        val submitImmediately: Boolean = false,
    ) : TerminalEntryUi

    data class HandedOff(
        val summaryLine: String,
        val items: List<TerminalItemRefUi>,
        val missingSummaryCount: Int,
        val previewText: String,
    ) : TerminalEntryUi

    data class HandoffFailed(
        val errorLine: String,
        val isClipboardDenied: Boolean,
        val previewText: String?,
    ) : TerminalEntryUi

    data class HandoffConfirm(
        val warningLine: String,
        val choices: List<TerminalChoiceUi>,
    ) : TerminalEntryUi

    data object Welcome : TerminalEntryUi

    data class Guide(
        val header: String,
        val rows: List<TerminalGuideRowUi>,
        val exampleCommand: String,
    ) : TerminalEntryUi
}

data class TerminalBlockUi(
    val id: String,
    val prompt: String?,
    val failed: Boolean,
    val entries: List<TerminalEntryUi>,
)

data class TerminalUiState(
    val windowTitle: String = "처음",
    val statusText: String = "자료 · 선택 0",
    val isOffline: Boolean = false,
    /** 자료 전체 수. 아직 모르면 null. 보관함 머리 줄(`자료 N`)이 함께 쓴다. */
    val itemCount: Int? = null,
    val input: String = "",
    val selection: List<TerminalItemRefUi> = emptyList(),
    val blocks: List<TerminalBlockUi> = emptyList(),
)

object TerminalFormat {
    private val seoulZone: ZoneId = ZoneId.of("Asia/Seoul")
    private val savedAtFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")

    /** 상태줄 문구(COM-010): `자료 N · 선택 M [· 요약 생성 중 K] [· 연결 끊김]` */
    fun statusText(
        itemCount: Int?,
        selectionCount: Int,
        processingCount: Int,
        isOffline: Boolean,
    ): String {
        val parts = mutableListOf<String>()
        parts += if (itemCount != null) "자료 $itemCount" else "자료"
        parts += "선택 $selectionCount"
        if (processingCount > 0) parts += "요약 생성 중 $processingCount"
        if (isOffline) parts += "연결 끊김"
        return parts.joinToString(" · ")
    }

    /** ISO-8601 시각을 한국 시간 `yyyy-MM-dd HH:mm`으로 바꾼다. 파싱 실패 시 원문을 돌려준다. */
    fun formatSavedAt(raw: String): String = runCatching {
        Instant.parse(raw).atZone(seoulZone).format(savedAtFormatter)
    }.getOrDefault(raw)

    /** 바이트 크기를 `24MB` 또는 `21.5MB`로 바꾼다. */
    fun formatMegabytes(bytes: Int): String {
        val mb = bytes.toDouble() / (1024.0 * 1024.0)
        val rounded = kotlin.math.round(mb * 10.0) / 10.0
        return if (rounded % 1.0 == 0.0) {
            "${rounded.toInt()}MB"
        } else {
            String.format(Locale.US, "%.1fMB", rounded)
        }
    }

    /** 한국어 천 단위 쉼표 숫자. */
    fun formatCount(count: Int): String = NumberFormat.getNumberInstance(Locale.KOREA).format(count)

    /** 글(text) 자료 제목: 첫 줄 최대 24자. */
    fun formatTextTitle(raw: String): String {
        val firstLine = raw.lineSequence().firstOrNull().orEmpty().trimEnd()
        return if (firstLine.length <= 24) firstLine else firstLine.take(24).trimEnd()
    }

    /** `도움말` 13줄 명령 목록(commands 2절). */
    val guideRows: List<TerminalGuideRowUi> = listOf(
        TerminalGuideRowUi("담기", "keep", "자료 저장"),
        TerminalGuideRowUi("최근", "recent", "최근 자료 목록"),
        TerminalGuideRowUi("찾기", "seek", "검색"),
        TerminalGuideRowUi("고르기", "pick", "번호로 선택"),
        TerminalGuideRowUi("넘기기", "handoff", "AI 도구용 글 복사"),
        TerminalGuideRowUi("묶음", "pack", "선택에 이름 붙이기"),
        TerminalGuideRowUi("고치기", "revise", "제목·요약 수정"),
        TerminalGuideRowUi("버리기", "drop", "삭제"),
        TerminalGuideRowUi("가져오기", "bring", "북마크 파일 가져오기"),
        TerminalGuideRowUi("연결", "plug", "AI 도구 연결"),
        TerminalGuideRowUi("로그아웃", "signout", "로그아웃"),
        TerminalGuideRowUi("도움말", "guide", "명령 목록"),
        TerminalGuideRowUi("설명", "about", "명령 설명"),
    )
}
