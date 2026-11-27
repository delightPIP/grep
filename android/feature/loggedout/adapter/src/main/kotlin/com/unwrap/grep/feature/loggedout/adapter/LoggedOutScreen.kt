package com.unwrap.grep.feature.loggedout.adapter

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.unwrap.grep.core.rememberAttachedHandle
import com.unwrap.grep.feature.loggedout.ui.LoggedOutNoticeUi
import com.unwrap.grep.feature.loggedout.ui.LoggedOutView
import com.unwrap.grep.feature.loggedout.ui.SignInFailureReasonUi
import com.unwrap.grep.swiftbridge.LoggedOutScreenHandle
import com.unwrap.grep.swiftbridge.LoggedOutViewBridge
import java.util.Optional

/** Swift `LoggedOutAndroidViewFactory.kind`와 같은 문자열. */
const val LOGGED_OUT_KIND = "loggedOut"

/** 브리지 문자열을 순수 뷰 안내 값으로 바꾼다. */
internal fun decodeLoggedOutNotice(noticeKind: String?, failureReason: String?): LoggedOutNoticeUi? = when (noticeKind) {
    "cancelled" -> LoggedOutNoticeUi.Cancelled
    "failed" -> {
        val reason = when (failureReason) {
            "disconnected" -> SignInFailureReasonUi.DISCONNECTED
            "timedOut" -> SignInFailureReasonUi.TIMED_OUT
            else -> SignInFailureReasonUi.DENIED
        }
        LoggedOutNoticeUi.Failed(reason)
    }
    "expired" -> LoggedOutNoticeUi.Expired
    "signedOut" -> LoggedOutNoticeUi.SignedOut
    else -> null
}

/** Swift `LoggedOutViewBridge`의 구현. Swift가 넘긴 값을 Compose 상태로 든다. */
private class LoggedOutAdapter : LoggedOutViewBridge {
    var notice: LoggedOutNoticeUi? by mutableStateOf(null)
        private set
    var isSigningIn: Boolean by mutableStateOf(false)
        private set

    override fun render(noticeKind: Optional<String>, failureReason: Optional<String>, isSigningIn: Boolean) {
        this.notice = decodeLoggedOutNotice(noticeKind.orElse(null), failureReason.orElse(null))
        this.isSigningIn = isSigningIn
    }
}

/** 화면 핸들에 어댑터를 붙이고, 값과 콜백을 순수 뷰(`:feature:loggedout:ui`)에 넘긴다. */
@Composable
fun LoggedOutScreen(screenId: Long) {
    val adapter = remember { LoggedOutAdapter() }
    val handle = rememberAttachedHandle(
        create = { LoggedOutScreenHandle.init(screenId, it) },
        attach = { it.attach(adapter) },
        detach = { it.detach() },
    )
    LoggedOutView(
        notice = adapter.notice,
        isSigningIn = adapter.isSigningIn,
        onSignIn = { provider -> handle.signInTapped(provider.rawValue) },
    )
}
