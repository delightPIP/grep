package com.unwrap.grep.feature.loggedout.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class LoggedOutNoticeFormatTest {
    @Test
    fun 로그인취소상태일때_안내문구를만들면_ACC001원문과일치하는지() {
        // given
        val notice = LoggedOutNoticeUi.Cancelled

        // when
        val formatted = formatLoggedOutNotice(notice)

        // then
        assertEquals(NoticeTone.ERROR, formatted.tone)
        assertEquals("✗ 로그인 취소됨", formatted.fullText)
    }

    @Test
    fun 로그인실패상태일때_안내문구를만들면_세가지이유를정확히표시하는지() {
        // given
        val disconnected = LoggedOutNoticeUi.Failed(SignInFailureReasonUi.DISCONNECTED)
        val timedOut = LoggedOutNoticeUi.Failed(SignInFailureReasonUi.TIMED_OUT)
        val denied = LoggedOutNoticeUi.Failed(SignInFailureReasonUi.DENIED)

        // when
        val textDisconnected = formatLoggedOutNotice(disconnected).fullText
        val textTimedOut = formatLoggedOutNotice(timedOut).fullText
        val textDenied = formatLoggedOutNotice(denied).fullText

        // then
        assertEquals("✗ 로그인 실패: 연결 끊김", textDisconnected)
        assertEquals("✗ 로그인 실패: 응답 없음", textTimedOut)
        assertEquals("✗ 로그인 실패: 권한 거부", textDenied)
    }

    @Test
    fun 로그인만료상태일때_안내문구를만들면_경고톤과원문으로나오는지() {
        // given
        val notice = LoggedOutNoticeUi.Expired

        // when
        val formatted = formatLoggedOutNotice(notice)

        // then
        assertEquals(NoticeTone.WARN, formatted.tone)
        assertEquals("! 로그인 만료 → 다시 로그인", formatted.fullText)
    }

    @Test
    fun 로그아웃상태일때_안내문구를만들면_성공톤과원문으로나오는지() {
        // given
        val notice = LoggedOutNoticeUi.SignedOut

        // when
        val formatted = formatLoggedOutNotice(notice)

        // then
        assertEquals(NoticeTone.OK, formatted.tone)
        assertEquals("✓ 로그아웃됨", formatted.fullText)
    }
}
