package com.unwrap.grep.core

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.unwrap.grep.swiftbridge.AuthServiceHandle
import com.unwrap.grep.swiftbridge.ClipboardPortHandle
import com.unwrap.grep.swiftbridge.FilePortHandle
import com.unwrap.grep.swiftbridge.HTTPTransportHandle
import com.unwrap.grep.swiftbridge.HistoryStoreHandle
import org.swift.swiftkit.core.SwiftArena

/**
 * Swift 라이브러리(`libGrepBridge.so`)와의 JNI 경계. Swift 쪽 짝은 `android/swift/Sources/GrepBridge/JNI.swift`다.
 * 모든 호출은 Android UI(메인) 스레드에서 한다.
 */
object SwiftBridge {
    private var renderListener: ((String) -> Unit)? = null

    private var httpTransport: Pair<HTTPTransportHandle, HttpUrlConnectionTransport>? = null
    private var authPort: Pair<AuthServiceHandle, AndroidAuthPort>? = null
    private var clipboardPort: Pair<ClipboardPortHandle, AndroidClipboardPort>? = null
    private var filePort: Pair<FilePortHandle, AndroidFilePort>? = null
    private var historyStore: Pair<HistoryStoreHandle, SharedPrefsHistoryStore>? = null

    init {
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "SwiftBridge must be loaded and attached on the Android UI (main) thread, " +
                "but was initialized on '${Thread.currentThread().name}'"
        }
        System.loadLibrary("c++_shared")
        System.loadLibrary("GrepBridge")
        check(nativeAttachMainLooper()) { "Failed to attach the Swift main queue to the main Looper" }
        Handler(Looper.getMainLooper()).postDelayed({
            check(nativeIsMainQueueDraining()) {
                "Swift @MainActor work did not run on the main Looper within ${SELF_CHECK_DELAY_MILLIS} ms"
            }
        }, SELF_CHECK_DELAY_MILLIS)
    }

    private const val SELF_CHECK_DELAY_MILLIS = 2_000L

    fun isMainQueueDraining(): Boolean = nativeIsMainQueueDraining()

    /** 전체 앱에 필요한 플랫폼 포트 다섯 가지를 Swift에 설치한다. [start] 전에 호출한다. */
    fun installPlatformPorts(context: Context, apiBaseUrl: String, authConfig: AuthConfig) {
        val appContext = context.applicationContext
        val arena = SwiftArena.ofAuto()

        if (httpTransport == null) {
            val handle = HTTPTransportHandle.init(arena)
            val transport = HttpUrlConnectionTransport(apiBaseUrl, handle)
            handle.install(transport)
            httpTransport = handle to transport
        }
        if (authPort == null) {
            val handle = AuthServiceHandle.init(arena)
            val port = AndroidAuthPort(appContext, authConfig, handle)
            handle.install(port)
            authPort = handle to port
        }
        if (clipboardPort == null) {
            val handle = ClipboardPortHandle.init(arena)
            val port = AndroidClipboardPort(appContext, handle)
            handle.install(port)
            clipboardPort = handle to port
        }
        if (filePort == null) {
            val handle = FilePortHandle.init(arena)
            val port = AndroidFilePort(handle)
            handle.install(port)
            filePort = handle to port
        }
        if (historyStore == null) {
            val handle = HistoryStoreHandle.init(arena)
            val store = SharedPrefsHistoryStore(appContext)
            handle.install(store)
            historyStore = handle to store
        }
    }

    /** OAuth 콜백 딥링크를 현재 인증 포트에 넘긴다. */
    fun handleAuthRedirect(uri: Uri): Boolean = authPort?.second?.handleRedirectUri(uri) ?: false

    /** Activity가 다시 포그라운드로 돌아왔을 때 진행 중인 OAuth 취소 여부를 확인한다. */
    fun onHostResumed() {
        authPort?.second?.onHostResumed()
    }

    /** 전체 앱 RIB 트리를 시작한다. */
    fun start(onRender: (String) -> Unit) {
        renderListener = onRender
        nativeStart()
    }

    /** 피처 하나만 띄운다(단독 실행 앱). */
    fun startDemo(feature: String, scenario: String?, onRender: (String) -> Unit) {
        renderListener = onRender
        nativeStartDemo(feature.toByteArray(Charsets.UTF_8), scenario?.toByteArray(Charsets.UTF_8))
    }

    fun stop() {
        nativeStop()
        renderListener = null
        uninstallPlatformPorts()
    }

    private fun uninstallPlatformPorts() {
        httpTransport?.let { (handle, transport) ->
            httpTransport = null
            handle.uninstall()
            transport.shutdown()
        }
        authPort?.let { (handle, port) ->
            authPort = null
            handle.uninstall()
            port.shutdown()
        }
        clipboardPort?.let { (handle, _) ->
            clipboardPort = null
            handle.uninstall()
        }
        filePort?.let { (handle, port) ->
            filePort = null
            handle.uninstall()
            port.shutdown()
        }
        historyStore?.let { (handle, _) ->
            historyStore = null
            handle.uninstall()
        }
    }

    /** Swift가 JNI로 부른다. */
    @JvmStatic
    fun onRender(tree: ByteArray) {
        renderListener?.invoke(tree.toString(Charsets.UTF_8))
    }

    private external fun nativeAttachMainLooper(): Boolean
    private external fun nativeIsMainQueueDraining(): Boolean
    private external fun nativeStart()
    private external fun nativeStartDemo(feature: ByteArray, scenario: ByteArray?)
    private external fun nativeStop()
}
