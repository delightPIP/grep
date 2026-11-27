package com.unwrap.grep.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Optional

class PlatformPortsTest {
    @Test
    fun 기록을저장했을때_다시읽으면_계정과본문이줄바꿈으로합쳐져나오는지() {
        // given
        val map = mutableMapOf<String, String>()
        val store = SharedPrefsHistoryStore(
            readValue = { map[it] },
            writeValues = { subject, payload ->
                map["subject"] = subject
                map["payload"] = payload
            },
            clearValues = { map.clear() },
        )

        // when
        store.save("user-1", "{\"lines\":[]}")
        val loaded = store.loadEncoded()

        // then
        assertEquals(Optional.of("user-1\n{\"lines\":[]}"), loaded)
    }

    @Test
    fun 기록을지웠을때_다시읽으면_비어있는Optional을돌려주는지() {
        // given
        val map = mutableMapOf("subject" to "user-1", "payload" to "{}")
        val store = SharedPrefsHistoryStore(
            readValue = { map[it] },
            writeValues = { subject, payload ->
                map["subject"] = subject
                map["payload"] = payload
            },
            clearValues = { map.clear() },
        )

        // when
        store.clear()
        val loaded = store.loadEncoded()

        // then
        assertFalse(loaded.isPresent)
    }

    @Test
    fun 클립보드복사를요청했을때_OS가거부하면_false로응답하는지() {
        // given
        var capturedID = -1L
        var capturedCopied = true
        val port = AndroidClipboardPort(
            copyText = { false },
            onResult = { id, copied ->
                capturedID = id
                capturedCopied = copied
            },
        )

        // when
        port.startCopy(7L, "복사할 글")

        // then
        assertEquals(7L, capturedID)
        assertFalse(capturedCopied)
    }

    @Test
    fun 등록되지않은파일을업로드할때_실행하면_missingFile로실패하는지() {
        // given
        var failedID = -1L
        var failedReason = ""
        val port = AndroidFilePort(
            onComplete = {},
            onFail = { id, reason ->
                failedID = id
                failedReason = reason
            },
            postToMain = { it() },
        )

        // when
        port.startUpload(3L, "unknown-file", "https://example.com/upload")

        // then
        assertEquals(3L, failedID)
        assertEquals(AndroidFilePort.REASON_MISSING_FILE, failedReason)
        port.shutdown()
    }

    @Test
    fun 유효한세션이저장되어있을때_토큰을요청하면_저장된접근토큰을돌려주는지() {
        // given
        val storage = InMemorySessionStorage(
            StoredSession(accessToken = "tok-123", refreshToken = "ref-1", expiresAtEpochSeconds = 2_000L),
        )
        var resolvedToken: String? = null
        val port = AndroidAuthPort(
            config = AuthConfig("https://example.supabase.co", "anon-key"),
            storage = storage,
            openBrowser = { true },
            onSignInComplete = { _, _, _ -> },
            onSignOutComplete = {},
            onAccessTokenComplete = { _, token -> resolvedToken = token },
            nowEpochSeconds = { 1_000L },
            postToMain = { it() },
            postDelayedToMain = { _, _ -> },
        )

        // when
        port.startAccessToken(1L)

        // then
        assertEquals("tok-123", resolvedToken)
        port.shutdown()
    }

    @Test
    fun Supabase설정이비어있을때_로그인을시도하면_denied로실패하는지() {
        // given
        var outcome = ""
        var reason = ""
        val port = AndroidAuthPort(
            config = AuthConfig("", ""),
            storage = InMemorySessionStorage(null),
            openBrowser = { true },
            onSignInComplete = { _, out, r ->
                outcome = out
                reason = r
            },
            onSignOutComplete = {},
            onAccessTokenComplete = { _, _ -> },
            postToMain = { it() },
            postDelayedToMain = { _, _ -> },
        )

        // when
        port.startSignIn(2L, "google")

        // then
        assertEquals(AndroidAuthPort.OUTCOME_FAILED, outcome)
        assertEquals(AndroidAuthPort.REASON_DENIED, reason)
        assertTrue(outcome.isNotEmpty())
        port.shutdown()
    }
}

private class InMemorySessionStorage(
    private var current: StoredSession?,
) : AuthSessionStorage {
    override fun load(): StoredSession? = current
    override fun save(session: StoredSession) { current = session }
    override fun clear() { current = null }
}
