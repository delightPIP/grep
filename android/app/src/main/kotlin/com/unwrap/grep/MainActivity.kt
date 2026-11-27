package com.unwrap.grep

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.unwrap.grep.core.AuthConfig
import com.unwrap.grep.core.RibActivity
import com.unwrap.grep.core.RibTreeStarter
import com.unwrap.grep.core.SwiftBridge
import com.unwrap.grep.feature.loggedin.ui.LoggedInTabContainer
import com.unwrap.grep.feature.loggedout.adapter.LOGGED_OUT_KIND
import com.unwrap.grep.feature.loggedout.adapter.LoggedOutScreen
import com.unwrap.grep.feature.terminal.adapter.TERMINAL_KIND
import com.unwrap.grep.feature.terminal.adapter.TerminalScreen
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
            TERMINAL_KIND -> LoggedInHostScreen(id)
            else -> error("Unknown screen kind: ${node.getString("kind")}")
        }
    }
}

@Composable
private fun LoggedInHostScreen(terminalScreenId: Long) {
    var selectionCount by remember { mutableIntStateOf(0) }
    var scrollToBottomTrigger by remember { mutableIntStateOf(0) }

    LoggedInTabContainer(
        isSelecting = selectionCount > 0,
        onReselectTerminal = { scrollToBottomTrigger += 1 },
        terminalContent = {
            TerminalScreen(
                screenId = terminalScreenId,
                scrollToBottomTrigger = scrollToBottomTrigger,
                onSelectionCountChanged = { selectionCount = it },
            )
        },
    )
}
