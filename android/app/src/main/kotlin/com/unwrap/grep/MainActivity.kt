package com.unwrap.grep

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.unwrap.grep.core.AuthConfig
import com.unwrap.grep.core.RibActivity
import com.unwrap.grep.core.RibTreeStarter
import com.unwrap.grep.core.SwiftBridge
import com.unwrap.grep.core.rememberAttachedHandle
import com.unwrap.grep.feature.loggedout.adapter.LOGGED_OUT_KIND
import com.unwrap.grep.feature.loggedout.adapter.LoggedOutScreen
import com.unwrap.grep.swiftbridge.TerminalScreenHandle
import com.unwrap.grep.swiftbridge.TerminalViewBridge
import org.json.JSONObject

/** 전체 앱. 화면 종류를 피처 어댑터 모듈의 Composable로 잇는 곳은 여기뿐이다. */
class MainActivity : RibActivity() {
    override val startTree: RibTreeStarter = { onRender ->
        val apiBaseUrl = intent.getStringExtra(EXTRA_API_BASE_URL) ?: DEFAULT_API_BASE_URL
        val authConfig = AuthConfig(
            supabaseUrl = intent.getStringExtra(EXTRA_SUPABASE_URL).orEmpty(),
            supabaseAnonKey = intent.getStringExtra(EXTRA_SUPABASE_ANON_KEY).orEmpty(),
        )
        SwiftBridge.installPlatformPorts(applicationContext, apiBaseUrl, authConfig)
        SwiftBridge.start(onRender)
    }

    @Composable
    override fun FeatureNode(node: JSONObject) {
        val id = node.getLong("id")
        when (node.getString("kind")) {
            LOGGED_OUT_KIND -> LoggedOutScreen(id)
            TERMINAL_KIND -> TerminalPlaceholderScreen(id)
            else -> error("Unknown screen kind: ${node.getString("kind")}")
        }
    }

    private companion object {
        const val TERMINAL_KIND = "terminal"
    }
}

private class TerminalPlaceholderAdapter : TerminalViewBridge {
    var itemCount: Int by mutableIntStateOf(-1)
        private set
    var isOffline: Boolean by mutableStateOf(false)
        private set

    override fun render(itemCount: Int, isOffline: Boolean) {
        this.itemCount = itemCount
        this.isOffline = isOffline
    }
}

/**
 * shortcut: #79 2단계에서 `:feature:terminal` 및 `:feature:loggedin` 하단 탭 컨테이너로 교체한다.
 */
@Composable
private fun TerminalPlaceholderScreen(screenId: Long) {
    val adapter = remember { TerminalPlaceholderAdapter() }
    val handle = rememberAttachedHandle(
        create = { TerminalScreenHandle.init(screenId, it) },
        attach = { it.attach(adapter) },
        detach = { it.detach() },
    )
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "그렙 ~ $ 로그인됨",
            color = Color(0xFF7FE0A3),
            fontFamily = FontFamily.Monospace,
        )
        if (adapter.itemCount >= 0) {
            Text(
                text = "자료 ${adapter.itemCount}",
                color = Color(0xFF99A2AD),
                fontFamily = FontFamily.Monospace,
            )
        }
        Button(onClick = { handle.submitCommand("로그아웃") }) {
            Text("로그아웃")
        }
    }
}
