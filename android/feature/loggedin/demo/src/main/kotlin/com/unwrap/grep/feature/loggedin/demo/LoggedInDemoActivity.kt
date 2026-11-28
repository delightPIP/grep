package com.unwrap.grep.feature.loggedin.demo

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.unwrap.grep.feature.loggedin.adapter.ArchiveItemLoader
import com.unwrap.grep.feature.loggedin.adapter.ArchivePageOutcome
import com.unwrap.grep.feature.loggedin.adapter.LoggedInTabsModel
import com.unwrap.grep.feature.loggedin.adapter.LoggedInTabsScreen
import com.unwrap.grep.feature.loggedin.ui.ArchiveItemRow
import com.unwrap.grep.feature.loggedin.ui.LoggedInTab

/** iOS `LoggedInExampleApp`(#91)과 같은 시나리오. */
enum class LoggedInDemoScenario(val label: String) {
    FULL_TABS("전체 3탭 · 터미널 시작 (보관함 25건)"),
    ARCHIVE_WITH_ITEMS("보관함 바로 보기 · 자료 있음 (더 보기)"),
    ARCHIVE_EMPTY("보관함 · 자료 0건"),
    ARCHIVE_OFFLINE_THEN_RECOVER("보관함 · 연결 끊김 (다시 시도 복구)"),
    SETTINGS_SIGN_OUT("설정 바로 보기 · 로그아웃 확인"),
}

class LoggedInDemoViewModel : ViewModel() {
    var activeScenario: LoggedInDemoScenario? by mutableStateOf(null)
        private set
    var model: LoggedInTabsModel? by mutableStateOf(null)
        private set
    var lastEvent: String by mutableStateOf("없음")
        private set

    private var picked: Set<Int> = emptySet()

    fun launch(scenario: LoggedInDemoScenario) {
        val (initialTab, loader, itemCount) = when (scenario) {
            LoggedInDemoScenario.FULL_TABS ->
                Triple(LoggedInTab.TERMINAL, DemoArchiveLoader(DemoMode.Paginated(sampleRows(25))), 25)
            LoggedInDemoScenario.ARCHIVE_WITH_ITEMS ->
                Triple(LoggedInTab.ARCHIVE, DemoArchiveLoader(DemoMode.Paginated(sampleRows(25))), 25)
            LoggedInDemoScenario.ARCHIVE_EMPTY ->
                Triple(LoggedInTab.ARCHIVE, DemoArchiveLoader(DemoMode.Empty), 0)
            LoggedInDemoScenario.ARCHIVE_OFFLINE_THEN_RECOVER ->
                Triple(LoggedInTab.ARCHIVE, DemoArchiveLoader(DemoMode.FailOnce("연결 끊김", sampleRows(6))), null)
            LoggedInDemoScenario.SETTINGS_SIGN_OUT ->
                Triple(LoggedInTab.SETTINGS, DemoArchiveLoader(DemoMode.Paginated(sampleRows(6))), 6)
        }
        picked = emptySet()
        lateinit var created: LoggedInTabsModel
        created = LoggedInTabsModel(
            archiveLoader = loader,
            sendCommand = { command -> handleCommand(created, command, itemCount) },
            initialTab = initialTab,
            onSessionExpired = {
                lastEvent = "로그인 만료"
                stop()
            },
        )
        created.updateTerminalContext(itemCount, emptySet())
        model = created
        activeScenario = scenario
    }

    fun stop() {
        model = null
        activeScenario = null
    }

    /** 실제 앱에서는 터미널 코어가 받는 명령을 여기서 흉내 낸다. */
    private fun handleCommand(target: LoggedInTabsModel, command: String, itemCount: Int?) {
        lastEvent = "터미널 명령: $command"
        val words = command.split(" ")
        picked = when {
            command == LoggedInTabsModel.SIGN_OUT_COMMAND -> {
                lastEvent = "로그아웃 명령 수신"
                stop()
                return
            }
            command == LoggedInTabsModel.CLEAR_PICKED_COMMAND -> emptySet()
            words.size == 3 && words[1] == "빼기" -> picked - words[2].toInt()
            words.size == 2 -> picked + words[1].toInt()
            else -> picked
        }
        target.updateTerminalContext(itemCount, picked)
    }
}

private sealed interface DemoMode {
    data object Empty : DemoMode
    data class Paginated(val rows: List<ArchiveItemRow>) : DemoMode
    data class FailOnce(val message: String, val rows: List<ArchiveItemRow>) : DemoMode
}

private class DemoArchiveLoader(private val mode: DemoMode) : ArchiveItemLoader {
    private val main = Handler(Looper.getMainLooper())
    private var attempt = 0

    override fun loadPage(limit: Int, cursor: String?, onResult: (ArchivePageOutcome) -> Unit) {
        attempt += 1
        val outcome = when (mode) {
            DemoMode.Empty -> ArchivePageOutcome.Page(emptyList(), null)
            is DemoMode.Paginated -> slice(mode.rows, limit, cursor)
            is DemoMode.FailOnce ->
                if (attempt == 1 && cursor == null) ArchivePageOutcome.Failed(mode.message) else slice(mode.rows, limit, cursor)
        }
        main.postDelayed({ onResult(outcome) }, DELAY_MILLIS)
    }

    private fun slice(rows: List<ArchiveItemRow>, limit: Int, cursor: String?): ArchivePageOutcome {
        val start = cursor?.toIntOrNull() ?: 0
        if (start >= rows.size) return ArchivePageOutcome.Page(emptyList(), null)
        val end = minOf(start + limit, rows.size)
        return ArchivePageOutcome.Page(rows.subList(start, end), if (end < rows.size) end.toString() else null)
    }

    private companion object {
        const val DELAY_MILLIS = 250L
    }
}

/** iOS 예제의 `sampleItems`를 Swift `ArchiveItemMapper`가 만든 값으로 옮긴 것. */
private fun sampleRows(count: Int): List<ArchiveItemRow> {
    val base = listOf(
        ArchiveItemRow(132, "Swift 6 동시성 마이그레이션 노트", "swift.org · 2026-11-27 15:00", "· 요약 생성 중", false, emptyList()),
        ArchiveItemRow(131, "결제위젯 연동 가이드", "tosspayments · 2026-11-26 14:03", "웹·모바일 결제위젯 SDK 설치와 승인 흐름 정리", false, listOf("결제", "sdk", "가이드")),
        ArchiveItemRow(118, "결제 실패 화면 모음.png", "이미지 · 2026-11-25 18:20", "카드 한도 초과·네트워크 오류 토스트 비교", false, listOf("결제", "에러")),
        ArchiveItemRow(99, "발표 데모에서 보여 줄 핵심 시나리오 메모", "2026-11-24 21:15", "담기 → 찾기 → 고르기 → 넘기기 흐름 점검", false, listOf("발표", "메모")),
        ArchiveItemRow(64, "결제 UX 스레드 모음", "threads.net · 2026-11-20 10:10", "! 본문 못 가져옴 → 고치기 64", true, listOf("결제")),
        ArchiveItemRow(42, "2026-아키텍처-회고.pdf", "PDF · 2026-11-18 17:00", "! 요약 못 만듦  제목·출처만 넘김", true, listOf("아키텍처")),
    )
    if (count <= base.size) return base.take(count)
    val extra = (base.size until count).map { offset ->
        val number = maxOf(1, 40 - (offset - base.size))
        ArchiveItemRow(
            number = number,
            title = "참고 자료 #$number",
            meta = "docs.example.com · 2026-11-10 12:00",
            summary = "보관함 페이지네이션 확인용 샘플 요약입니다.",
            summaryIsWarning = false,
            tags = listOf("샘플", "보관함"),
        )
    }
    return base + extra
}

class LoggedInDemoActivity : ComponentActivity() {
    private val viewModel: LoggedInDemoViewModel by lazy {
        ViewModelProvider(this)[LoggedInDemoViewModel::class.java]
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            Box(modifier = Modifier.fillMaxSize().background(SurfaceColor)) {
                val model = viewModel.model
                if (model == null) {
                    ScenarioListScreen(lastEvent = viewModel.lastEvent, onSelect = viewModel::launch)
                } else {
                    BackHandler { viewModel.stop() }
                    LoggedInTabsScreen(model = model) { DemoTerminalPlaceholder() }
                    // 머리 줄 오른쪽의 상태(`자료 N`)를 가리지 않도록 가운데에 둔다.
                    CloseButton(
                        onClick = viewModel::stop,
                        modifier = Modifier.align(Alignment.TopCenter),
                    )
                }
            }
        }
    }
}

@Composable
private fun DemoTerminalPlaceholder() {
    Column(
        modifier = Modifier.fillMaxSize().statusBarsPadding().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        MonoLabel("터미널", InkColor, bold = true)
        MonoLabel("· 터미널 탭은 :feature:terminal:demo에서 확인합니다", InkMutedColor)
    }
}

@Composable
private fun CloseButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .statusBarsPadding()
            .padding(top = 8.dp, end = 12.dp)
            .background(SurfaceRaisedColor, RoundedCornerShape(999.dp))
            .border(1.dp, LineColor, RoundedCornerShape(999.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .testTag("closeScenarioButton"),
    ) {
        MonoLabel("닫기", CommandColor, bold = true)
    }
}

@Composable
private fun ScenarioListScreen(lastEvent: String, onSelect: (LoggedInDemoScenario) -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item { MonoLabel("그렙 — LoggedIn Scenarios", InkColor, bold = true) }
        items(LoggedInDemoScenario.entries) { scenario ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp)
                    .background(SurfaceRaisedColor, RoundedCornerShape(8.dp))
                    .border(1.dp, LineColor, RoundedCornerShape(8.dp))
                    .clickable { onSelect(scenario) }
                    .padding(horizontal = 14.dp, vertical = 12.dp)
                    .testTag("scenario_${scenario.name.lowercase()}"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                MonoLabel(scenario.label, InkColor, modifier = Modifier.weight(1f))
                MonoLabel("→", CommandColor, bold = true)
            }
        }
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(SurfaceRaisedColor, RoundedCornerShape(8.dp))
                    .border(1.dp, LineColor, RoundedCornerShape(8.dp))
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                MonoLabel("마지막 이벤트", InkMutedColor, bold = true)
                MonoLabel(lastEvent, PromptColor, modifier = Modifier.testTag("exampleEvent"))
            }
        }
    }
}

@Composable
private fun MonoLabel(text: String, color: Color, modifier: Modifier = Modifier, bold: Boolean = false) {
    Text(
        text = text,
        color = color,
        fontFamily = FontFamily.Monospace,
        fontSize = 14.sp,
        fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal,
        modifier = modifier,
    )
}

private val SurfaceColor = Color(0xFF14171C)
private val SurfaceRaisedColor = Color(0xFF1C2027)
private val LineColor = Color(0xFF2E343D)
private val InkColor = Color(0xFFE7E9EC)
private val InkMutedColor = Color(0xFF99A2AD)
private val PromptColor = Color(0xFF7FE0A3)
private val CommandColor = Color(0xFF86C8FF)
