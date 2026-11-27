package com.unwrap.grep.core

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.unwrap.grep.swiftbridge.PlaceholderScreenHandle
import com.unwrap.grep.swiftbridge.PlaceholderViewBridge
import org.json.JSONObject
import org.swift.swiftkit.core.SwiftArena

/** 트리를 시작하는 방법. 전체 앱과 단독 실행 앱이 서로 다르게 넘긴다. */
typealias RibTreeStarter = (onRender: (String) -> Unit) -> Unit

/**
 * Swift RIB 트리를 소유하는 ViewModel. 화면 회전에도 트리를 유지하고, 화면을 완전히 떠날 때 내린다.
 */
class RibTreeViewModel(
    start: RibTreeStarter,
) : ViewModel() {
    var tree: JSONObject by mutableStateOf(JSONObject())
        private set

    init {
        start { tree = JSONObject(it) }
    }

    override fun onCleared() {
        SwiftBridge.stop()
    }
}

/**
 * Swift RIB 트리 하나를 그리는 Activity의 기반. 전체 앱과 피처별 단독 실행 앱이 상속한다.
 */
abstract class RibActivity : ComponentActivity() {
    protected abstract val startTree: RibTreeStarter

    @Composable
    protected abstract fun FeatureNode(node: JSONObject)

    private val viewModel: RibTreeViewModel by lazy {
        val start = startTree
        ViewModelProvider(
            this,
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    RibTreeViewModel(start) as T
            },
        )[RibTreeViewModel::class.java]
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.data?.let(SwiftBridge::handleAuthRedirect)
        setContent {
            MaterialTheme(colorScheme = GrepDarkColorScheme) {
                Surface(modifier = Modifier.fillMaxSize(), color = Color(0xFF0B0D10)) {
                    RibNode(viewModel.tree)
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.let(SwiftBridge::handleAuthRedirect)
    }

    override fun onResume() {
        super.onResume()
        SwiftBridge.onHostResumed()
    }

    @Composable
    fun RibNode(node: JSONObject?) {
        if (node == null || !node.has("kind")) return
        key(node.getLong("id")) {
            when (node.getString("kind")) {
                HostKind.ROOT -> RootNode(node)
                HostKind.PLACEHOLDER -> PlaceholderScreen(node.getLong("id"))
                else -> FeatureNode(node)
            }
        }
    }

    @Composable
    private fun RootNode(node: JSONObject) {
        val event = node.optString("event").takeIf { node.has("event") }
        if (event == null) {
            RibNode(node.optJSONObject("child"))
            return
        }
        Column(Modifier.fillMaxSize()) {
            Column(Modifier.weight(1f)) { RibNode(node.optJSONObject("child")) }
            Text(
                event,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(16.dp).testTag(HostTags.DEMO_EVENT),
            )
        }
    }

    companion object {
        const val EXTRA_API_BASE_URL: String = "apiBaseUrl"
        const val EXTRA_SUPABASE_URL: String = "supabaseUrl"
        const val EXTRA_SUPABASE_ANON_KEY: String = "supabaseAnonKey"
        const val EXTRA_DEMO_SCENARIO: String = "demoScenario"
        const val DEFAULT_API_BASE_URL: String = "http://10.0.2.2:8080"
    }
}

private val GrepDarkColorScheme = darkColorScheme(
    background = Color(0xFF0B0D10),
    surface = Color(0xFF14171C),
    onBackground = Color(0xFFE7E9EC),
    onSurface = Color(0xFFE7E9EC),
    primary = Color(0xFF7FE0A3),
    secondary = Color(0xFF86C8FF),
    error = Color(0xFFFF8F86),
)

/** Swift `HostScreenKind`와 같은 문자열. */
object HostKind {
    const val ROOT = "root"
    const val PLACEHOLDER = "placeholder"
}

object HostTags {
    const val DEMO_EVENT = "demoEvent"
    const val PLACEHOLDER_ACTION = "placeholderAction"
}

/**
 * 화면 핸들을 만들어 뷰를 붙이고, 화면이 컴포지션을 떠날 때 떼고 핸들의 Swift 메모리(arena)를 푼다.
 */
@Composable
fun <Handle> rememberAttachedHandle(
    create: (SwiftArena) -> Handle,
    attach: (Handle) -> Unit,
    detach: (Handle) -> Unit,
): Handle {
    val arena = remember { SwiftArena.ofConfined() }
    val handle = remember { create(arena) }
    DisposableEffect(handle) {
        attach(handle)
        onDispose {
            detach(handle)
            arena.close()
        }
    }
    return handle
}

private class PlaceholderView : PlaceholderViewBridge {
    var title: String by mutableStateOf("")
        private set
    var actionTitle: String by mutableStateOf("")
        private set

    override fun render(title: String, actionTitle: String) {
        this.title = title
        this.actionTitle = actionTitle
    }
}

@Composable
private fun PlaceholderScreen(screenId: Long) {
    val view = remember { PlaceholderView() }
    val handle = rememberAttachedHandle(
        create = { PlaceholderScreenHandle.init(screenId, it) },
        attach = { it.attach(view) },
        detach = { it.detach() },
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(view.title, color = MaterialTheme.colorScheme.onSurfaceVariant)
        TextButton(onClick = { handle.actionTapped() }, modifier = Modifier.testTag(HostTags.PLACEHOLDER_ACTION)) {
            Text(view.actionTitle)
        }
    }
}
