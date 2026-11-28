package com.unwrap.grep.feature.loggedin.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** 보관함 행 메타 줄에 붙일 꼬리(iOS `rowMetaLine`과 같은 우선순위: 경고 → 요약 생성 중 → 태그). */
internal data class ArchiveRowTail(val text: String, val isWarning: Boolean)

internal fun archiveRowTail(row: ArchiveItemRow): ArchiveRowTail? {
    val separator = if (row.meta.isEmpty()) "" else " · "
    val summary = row.summary
    return when {
        summary != null && row.summaryIsWarning -> ArchiveRowTail(separator + summary, isWarning = true)
        summary != null && summary.startsWith("· 요약 생성 중") -> ArchiveRowTail(separator + "요약 생성 중", isWarning = false)
        row.tags.isNotEmpty() -> ArchiveRowTail(" · " + row.tags.joinToString(" ") { "#$it" }, isWarning = false)
        else -> null
    }
}

/** 보관함 탭 순수 뷰(MOB-001, 시안 `MobileArchive.dc.html` · `MList.dc.html` · `MPickBar.dc.html`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ArchiveView(
    presentation: ArchivePresentation,
    onRefresh: () -> Unit,
    onLoadMore: () -> Unit,
    modifier: Modifier = Modifier,
    scrollToTopTrigger: Int = 0,
    onTogglePick: (Int) -> Unit = {},
    onMovePickedToTerminal: () -> Unit = {},
    onClearPicked: () -> Unit = {},
    listState: LazyListState = rememberLazyListState(),
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(LoggedInPalette.Surface),
    ) {
        GrepTopBar(
            title = "보관함",
            status = presentation.statusText,
            plain = true,
            statusTestTag = "archiveStatusText",
        )
        PullToRefreshBox(
            isRefreshing = presentation.isLoading && presentation.items.isNotEmpty(),
            onRefresh = onRefresh,
            modifier = Modifier.weight(1f).fillMaxWidth(),
        ) {
            val errorMessage = presentation.errorMessage
            when {
                presentation.isLoading && presentation.items.isEmpty() -> ArchiveLoading()
                errorMessage != null && presentation.items.isEmpty() -> ArchiveError(errorMessage, onRefresh)
                presentation.items.isEmpty() -> ArchiveEmpty(onRefresh)
                else -> ArchiveList(presentation, listState, scrollToTopTrigger, onTogglePick, onLoadMore)
            }
        }
        if (presentation.pickedCount > 0) {
            GrepPickBar(
                count = presentation.pickedCount,
                summary = presentation.pickedSummary,
                onMoveToTerminal = onMovePickedToTerminal,
                onClear = onClearPicked,
            )
        }
    }
}

@Composable
private fun ArchiveLoading() {
    Column(
        modifier = Modifier.fillMaxSize().testTag("archiveLoadingView"),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircularProgressIndicator(color = LoggedInPalette.Prompt, modifier = Modifier.size(28.dp))
        MonoText("· 자료 불러오는 중", LoggedInPalette.InkMuted)
    }
}

@Composable
private fun ArchiveError(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp)
            .testTag("archiveErrorView"),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MonoText("✗", LoggedInPalette.Danger, bold = true)
            MonoText("불러오기 안 됨: $message", LoggedInPalette.Ink, singleLine = false)
        }
        GrepUiButton(
            label = "다시 시도",
            modifier = Modifier.testTag("archiveRetryButton"),
            onClick = onRetry,
        )
    }
}

@Composable
private fun ArchiveEmpty(onRefresh: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
            .testTag("archiveEmptyView"),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MonoText("·", LoggedInPalette.Command, bold = true)
            MonoText("자료 0건", LoggedInPalette.Ink, bold = true)
        }
        MonoText(
            text = "터미널 탭에서 링크나 글을 저장하면 여기에 최근 순으로 모입니다.",
            color = LoggedInPalette.InkMuted,
            singleLine = false,
        )
        GrepUiButton(
            label = "새로고침",
            modifier = Modifier.testTag("archiveRefreshButton"),
            onClick = onRefresh,
        )
    }
}

@Composable
private fun ArchiveList(
    presentation: ArchivePresentation,
    listState: LazyListState,
    scrollToTopTrigger: Int,
    onTogglePick: (Int) -> Unit,
    onLoadMore: () -> Unit,
) {
    // MOB-001 규칙 8: 보관함 탭을 다시 누르면 맨 위로 간다.
    LaunchedEffect(scrollToTopTrigger) {
        if (scrollToTopTrigger > 0) listState.animateScrollToItem(0)
    }
    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize().testTag("archiveItemList"),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        items(presentation.items, key = { it.number }) { row ->
            ArchiveRow(row = row, onTogglePick = onTogglePick)
        }
        item {
            MonoText("· 왼쪽 칸: 고르기", LoggedInPalette.InkMuted, size = 12, modifier = Modifier.padding(top = 10.dp))
        }
        presentation.errorMessage?.let { message ->
            item {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    MonoText("✗ 불러오기 안 됨: $message", LoggedInPalette.Danger, size = 12, modifier = Modifier.weight(1f))
                    GrepUiButton(label = "다시 시도", kind = GrepButtonKind.GHOST, size = GrepButtonSize.SM, onClick = onLoadMore)
                }
            }
        }
        item { ArchiveFooter(presentation, onLoadMore) }
    }
}

@Composable
private fun ArchiveFooter(presentation: ArchivePresentation, onLoadMore: () -> Unit) {
    if (presentation.isLoadingMore) {
        Row(
            modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CircularProgressIndicator(color = LoggedInPalette.Prompt, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
            MonoText("· 더 불러오는 중", LoggedInPalette.InkMuted, size = 12)
        }
    } else if (presentation.hasMore) {
        Text(
            text = buildAnnotatedString {
                withStyle(SpanStyle(color = LoggedInPalette.InkMuted)) { append("→ ") }
                withStyle(SpanStyle(color = LoggedInPalette.Command, textDecoration = TextDecoration.Underline)) {
                    append("더 보기")
                }
            },
            fontFamily = FontFamily.Monospace,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 44.dp)
                .clickable(role = Role.Button, onClick = onLoadMore)
                .padding(vertical = 12.dp)
                .testTag("archiveMoreButton"),
        )
    }
}

/** 시안 `MList.dc.html`: 왼쪽 44dp 체크 칸 + 번호(4ch) + 제목·메타 두 줄. */
@Composable
private fun ArchiveRow(row: ArchiveItemRow, onTogglePick: (Int) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(3.dp))
            .background(if (row.isPicked) LoggedInPalette.Select else Color.Transparent)
            .heightIn(min = 56.dp)
            .testTag("archiveItem_${row.number}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PickCheckbox(row = row, onToggle = { onTogglePick(row.number) })
        Text(
            text = if (row.isPicked) "▸${row.number}" else "${row.number}",
            color = if (row.isPicked) LoggedInPalette.Command else LoggedInPalette.InkMuted,
            fontFamily = FontFamily.Monospace,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.End,
            modifier = Modifier.widthIn(min = 36.dp),
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(start = 8.dp, end = 8.dp, top = 6.dp, bottom = 6.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            MonoText(row.title, LoggedInPalette.Ink)
            ArchiveMetaLine(row)
        }
    }
}

@Composable
private fun PickCheckbox(row: ArchiveItemRow, onToggle: () -> Unit) {
    val action = if (row.isPicked) "선택 해제" else "고르기"
    Box(
        modifier = Modifier
            .size(width = 44.dp, height = 56.dp)
            .clickable(role = Role.Checkbox, onClick = onToggle)
            .semantics { contentDescription = "$action: ${row.title}" }
            .testTag("archiveCheck_${row.number}"),
        contentAlignment = Alignment.Center,
    ) {
        val boxShape = RoundedCornerShape(3.dp)
        Box(
            modifier = Modifier
                .size(20.dp)
                .clip(boxShape)
                .background(if (row.isPicked) LoggedInPalette.Prompt else Color.Transparent)
                .border(1.5.dp, if (row.isPicked) LoggedInPalette.Prompt else LoggedInPalette.Line, boxShape),
            contentAlignment = Alignment.Center,
        ) {
            if (row.isPicked) {
                Text("✓", color = LoggedInPalette.Surface, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun ArchiveMetaLine(row: ArchiveItemRow) {
    val tail = archiveRowTail(row)
    Text(
        text = buildAnnotatedString {
            withStyle(SpanStyle(color = LoggedInPalette.InkMuted)) { append(row.meta) }
            if (tail != null) {
                withStyle(SpanStyle(color = if (tail.isWarning) LoggedInPalette.Notice else LoggedInPalette.InkMuted)) {
                    append(tail.text)
                }
            }
        },
        fontFamily = FontFamily.Monospace,
        fontSize = 12.sp,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
}
