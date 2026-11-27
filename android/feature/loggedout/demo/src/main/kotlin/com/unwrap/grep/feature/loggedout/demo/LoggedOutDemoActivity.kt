package com.unwrap.grep.feature.loggedout.demo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.BorderStroke
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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.unwrap.grep.core.HostKind
import com.unwrap.grep.core.SwiftBridge
import com.unwrap.grep.feature.loggedout.adapter.LOGGED_OUT_KIND
import com.unwrap.grep.feature.loggedout.adapter.LoggedOutScreen
import org.json.JSONObject

/** iOS `LoggedOutDemoScenario`와 1:1 대응하는 데모 시나리오 목록. */
enum class LoggedOutDemoScenario(val rawValue: String, val label: String) {
    INITIAL("initial", "첫 화면 (로그인 성공)"),
    EXPIRED("expired", "로그인 만료 알림"),
    SIGNED_OUT("signedOut", "로그아웃 완료 알림"),
    CANCELLED("cancelled", "로그인 취소 응답"),
    FAIL_DISCONNECTED("failDisconnected", "로그인 실패: 연결 끊김"),
    FAIL_TIMED_OUT("failTimedOut", "로그인 실패: 응답 없음"),
    FAIL_DENIED("failDenied", "로그인 실패: 권한 거부"),
}

class LoggedOutDemoViewModel : ViewModel() {
    var activeScenario: LoggedOutDemoScenario? by mutableStateOf(null)
        private set
    var tree: JSONObject by mutableStateOf(JSONObject())
        private set
    var lastEvent: String by mutableStateOf("부모 이벤트 없음")
        private set

    fun launch(scenario: LoggedOutDemoScenario) {
        stop()
        activeScenario = scenario
        SwiftBridge.startDemo(LOGGED_OUT_KIND, scenario.rawValue) { raw ->
            val next = JSONObject(raw)
            val event = next.optString("event").takeIf { next.has("event") && it.isNotEmpty() }
            if (event != null) {
                lastEvent = "$event 수신"
                stop()
            } else {
                tree = next
            }
        }
    }

    fun stop() {
        if (activeScenario != null) {
            SwiftBridge.stop()
            activeScenario = null
            tree = JSONObject()
        }
    }

    override fun onCleared() {
        stop()
    }
}

/**
 * 로그인 피처 단독 실행 앱(ADR-0015, 이슈 #79 시나리오 규칙).
 * 시나리오 목록 화면에서 항목을 고르면 전체 화면으로 피처를 띄우고, 닫기·뒤로 가기로 목록에 돌아온다.
 */
class LoggedOutDemoActivity : ComponentActivity() {
    private val viewModel: LoggedOutDemoViewModel by lazy {
        ViewModelProvider(this)[LoggedOutDemoViewModel::class.java]
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = DemoDarkColorScheme) {
                Surface(modifier = Modifier.fillMaxSize(), color = SurfaceColor) {
                    val active = viewModel.activeScenario
                    if (active == null) {
                        ScenarioListScreen(
                            lastEvent = viewModel.lastEvent,
                            onSelect = viewModel::launch,
                        )
                    } else {
                        BackHandler { viewModel.stop() }
                        Box(modifier = Modifier.fillMaxSize()) {
                            DemoTreeNode(viewModel.tree)
                            OutlinedButton(
                                onClick = viewModel::stop,
                                shape = RoundedCornerShape(999.dp),
                                border = BorderStroke(1.dp, LineColor),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                colors = ButtonDefaults.outlinedButtonColors(
                                    containerColor = SurfaceRaisedColor.copy(alpha = 0.92f),
                                    contentColor = CommandColor,
                                ),
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .statusBarsPadding()
                                    .padding(top = 6.dp, end = 12.dp)
                                    .testTag("closeScenarioButton"),
                            ) {
                                Text(
                                    text = "닫기",
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DemoTreeNode(node: JSONObject?) {
    if (node == null || !node.has("kind")) return
    key(node.getLong("id")) {
        when (node.getString("kind")) {
            HostKind.ROOT -> DemoTreeNode(node.optJSONObject("child"))
            LOGGED_OUT_KIND -> LoggedOutScreen(node.getLong("id"))
            else -> error("Unknown screen kind in loggedout demo: ${node.getString("kind")}")
        }
    }
}

@Composable
private fun ScenarioListScreen(
    lastEvent: String,
    onSelect: (LoggedOutDemoScenario) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(SurfaceColor)
            .navigationBarsPadding(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(SurfaceRaisedColor)
                .statusBarsPadding(),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .padding(horizontal = 16.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                Text(
                    text = buildAnnotatedString {
                        withStyle(SpanStyle(color = PromptColor, fontWeight = FontWeight.Bold)) {
                            append("그렙")
                        }
                        withStyle(SpanStyle(color = InkColor, fontWeight = FontWeight.Bold)) {
                            append(" — LoggedOut Scenarios")
                        }
                    },
                    fontFamily = FontFamily.Monospace,
                    fontSize = 14.sp,
                )
            }
            HorizontalDivider(thickness = 1.dp, color = LineColor)
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Text(
                    text = "시나리오",
                    color = InkMutedColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
            items(LoggedOutDemoScenario.entries) { scenario ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp)
                        .background(SurfaceRaisedColor, RoundedCornerShape(8.dp))
                        .border(1.dp, LineColor, RoundedCornerShape(8.dp))
                        .clickable { onSelect(scenario) }
                        .padding(horizontal = 14.dp, vertical = 12.dp)
                        .testTag("scenario_${scenario.rawValue}"),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = scenario.label,
                        color = InkColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 14.sp,
                    )
                    Text(
                        text = "→",
                        color = CommandColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                        .background(SurfaceRaisedColor, RoundedCornerShape(8.dp))
                        .border(1.dp, LineColor, RoundedCornerShape(8.dp))
                        .padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = "마지막 부모 이벤트",
                        color = InkMutedColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = lastEvent,
                        color = PromptColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                        modifier = Modifier.testTag("exampleEvent"),
                    )
                }
            }
        }
    }
}

private val SurfaceColor = Color(0xFF14171C)
private val SurfaceRaisedColor = Color(0xFF1C2027)
private val LineColor = Color(0xFF2E343D)
private val InkColor = Color(0xFFE7E9EC)
private val InkMutedColor = Color(0xFF99A2AD)
private val PromptColor = Color(0xFF7FE0A3)
private val CommandColor = Color(0xFF86C8FF)

private val DemoDarkColorScheme = darkColorScheme(
    background = SurfaceColor,
    surface = SurfaceColor,
    onBackground = InkColor,
    onSurface = InkColor,
    primary = PromptColor,
    secondary = CommandColor,
)
