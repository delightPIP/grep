package com.unwrap.grep.feature.loggedout.adapter

import com.unwrap.grep.feature.loggedout.ui.LoggedOutNoticeUi
import com.unwrap.grep.feature.loggedout.ui.SignInFailureReasonUi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LoggedOutDecodeTest {
    @Test
    fun 브리지가실패코드를넘겼을때_해석하면_해당실패이유로바뀌는지() {
        // given
        val kind = "failed"

        // when
        val disconnected = decodeLoggedOutNotice(kind, "disconnected")
        val timedOut = decodeLoggedOutNotice(kind, "timedOut")
        val denied = decodeLoggedOutNotice(kind, "denied")

        // then
        assertEquals(LoggedOutNoticeUi.Failed(SignInFailureReasonUi.DISCONNECTED), disconnected)
        assertEquals(LoggedOutNoticeUi.Failed(SignInFailureReasonUi.TIMED_OUT), timedOut)
        assertEquals(LoggedOutNoticeUi.Failed(SignInFailureReasonUi.DENIED), denied)
    }

    @Test
    fun 브리지가안내없음을넘겼을때_해석하면_null을돌려주는지() {
        // given
        val kind: String? = null

        // when
        val decoded = decodeLoggedOutNotice(kind, null)

        // then
        assertNull(decoded)
    }
}
