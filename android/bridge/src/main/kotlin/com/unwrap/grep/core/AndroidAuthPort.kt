package com.unwrap.grep.core

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Base64
import com.unwrap.grep.swiftbridge.AuthServiceBridge
import com.unwrap.grep.swiftbridge.AuthServiceHandle
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.net.URLEncoder
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Optional
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Supabase OAuth 설정. `supabaseUrl`과 `supabaseAnonKey`가 비어 있으면 외부 로그인을 열 수 없다. */
data class AuthConfig(
    val supabaseUrl: String,
    val supabaseAnonKey: String,
    val redirectUri: String = DEFAULT_REDIRECT_URI,
) {
    val isConfigured: Boolean
        get() = supabaseUrl.isNotBlank() && supabaseAnonKey.isNotBlank()

    companion object {
        const val DEFAULT_REDIRECT_URI = "grep://auth/callback"
    }
}

/** 세션 저장소 추상화. 단위 테스트에서 SharedPreferences 없이 검증한다. */
interface AuthSessionStorage {
    fun load(): StoredSession?
    fun save(session: StoredSession)
    fun clear()
}

data class StoredSession(
    val accessToken: String,
    val refreshToken: String,
    val expiresAtEpochSeconds: Long,
)

class SharedPrefsAuthSessionStorage(
    private val prefs: SharedPreferences,
) : AuthSessionStorage {
    constructor(context: Context) : this(context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE))

    override fun load(): StoredSession? {
        val access = prefs.getString(KEY_ACCESS_TOKEN, null)?.takeIf { it.isNotEmpty() } ?: return null
        val refresh = prefs.getString(KEY_REFRESH_TOKEN, null) ?: ""
        val expiresAt = prefs.getLong(KEY_EXPIRES_AT, 0L)
        return StoredSession(access, refresh, expiresAt)
    }

    override fun save(session: StoredSession) {
        prefs.edit()
            .putString(KEY_ACCESS_TOKEN, session.accessToken)
            .putString(KEY_REFRESH_TOKEN, session.refreshToken)
            .putLong(KEY_EXPIRES_AT, session.expiresAtEpochSeconds)
            .apply()
    }

    override fun clear() {
        prefs.edit()
            .remove(KEY_ACCESS_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .remove(KEY_EXPIRES_AT)
            .apply()
    }

    private companion object {
        const val PREFS_NAME = "grep_auth_session"
        const val KEY_ACCESS_TOKEN = "access_token"
        const val KEY_REFRESH_TOKEN = "refresh_token"
        const val KEY_EXPIRES_AT = "expires_at"
    }
}

/**
 * Swift `AuthServiceBridge`의 Android 구현(ACC-001, ADR-BCK-006).
 * Supabase GoTrue PKCE OAuth 흐름으로 로그인하고, 만료된 접근 토큰은 갱신 토큰으로 조용히 새로 받는다.
 */
class AndroidAuthPort(
    private val config: AuthConfig,
    private val storage: AuthSessionStorage,
    private val openBrowser: (Uri) -> Boolean,
    private val onSignInComplete: (requestID: Long, outcome: String, reason: String) -> Unit,
    private val onSignOutComplete: (requestID: Long) -> Unit,
    private val onAccessTokenComplete: (requestID: Long, token: String?) -> Unit,
    private val nowEpochSeconds: () -> Long = { System.currentTimeMillis() / 1000L },
    private val executor: ExecutorService = Executors.newCachedThreadPool(),
    private val postToMain: (() -> Unit) -> Unit = defaultMainPoster(),
    private val postDelayedToMain: (Long, () -> Unit) -> Unit = defaultMainDelayedPoster(),
) : AuthServiceBridge {
    constructor(
        context: Context,
        config: AuthConfig,
        handle: AuthServiceHandle,
    ) : this(
        config = config,
        storage = SharedPrefsAuthSessionStorage(context.applicationContext),
        openBrowser = { uri ->
            try {
                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } catch (_: Throwable) {
                false
            }
        },
        onSignInComplete = { id, outcome, reason -> handle.completeSignIn(id, outcome, reason) },
        onSignOutComplete = { id -> handle.completeSignOut(id) },
        onAccessTokenComplete = { id, token -> handle.completeAccessToken(id, Optional.ofNullable(token)) },
    )

    private data class PendingSignIn(
        val requestID: Long,
        val codeVerifier: String,
    )

    private var pendingSignIn: PendingSignIn? = null

    override fun startSignIn(requestID: Long, provider: String) {
        if (!config.isConfigured) {
            onSignInComplete(requestID, OUTCOME_FAILED, REASON_DENIED)
            return
        }
        val verifier = generateCodeVerifier()
        val challenge = codeChallengeS256(verifier)
        val authorizeUrl = buildAuthorizeUrl(config, provider, challenge)
        pendingSignIn = PendingSignIn(requestID, verifier)
        val opened = openBrowser(Uri.parse(authorizeUrl))
        if (!opened) {
            pendingSignIn = null
            onSignInComplete(requestID, OUTCOME_FAILED, REASON_DENIED)
        }
    }

    /** `MainActivity.onNewIntent`로 들어온 OAuth 콜백 URI를 처리한다. */
    fun handleRedirectUri(uri: Uri): Boolean {
        val pending = pendingSignIn ?: return false
        val redirect = Uri.parse(config.redirectUri)
        if (uri.scheme != redirect.scheme || uri.host != redirect.host) return false
        pendingSignIn = null

        val error = uri.getQueryParameter("error")
        if (error == "access_denied") {
            onSignInComplete(pending.requestID, OUTCOME_CANCELLED, "")
            return true
        }
        val code = uri.getQueryParameter("code")
        if (!error.isNullOrEmpty() || code.isNullOrEmpty()) {
            onSignInComplete(pending.requestID, OUTCOME_FAILED, REASON_DENIED)
            return true
        }

        executor.submit {
            val result = runCatching { exchangePkceCode(code, pending.codeVerifier) }
            postToMain {
                result.fold(
                    onSuccess = { session ->
                        storage.save(session)
                        onSignInComplete(pending.requestID, OUTCOME_SUCCESS, "")
                    },
                    onFailure = { throwable ->
                        onSignInComplete(pending.requestID, OUTCOME_FAILED, mapFailureReason(throwable))
                    },
                )
            }
        }
        return true
    }

    /** 브라우저에서 콜백 없이 앱으로 돌아오면 사용자가 취소한 것으로 본다(ACC-001 규칙 8). */
    fun onHostResumed() {
        val snapshot = pendingSignIn ?: return
        postDelayedToMain(CANCEL_GRACE_MILLIS) {
            val current = pendingSignIn ?: return@postDelayedToMain
            if (current.requestID == snapshot.requestID) {
                pendingSignIn = null
                onSignInComplete(current.requestID, OUTCOME_CANCELLED, "")
            }
        }
    }

    override fun startSignOut(requestID: Long) {
        val existing = storage.load()
        storage.clear()
        if (existing == null || !config.isConfigured) {
            onSignOutComplete(requestID)
            return
        }
        executor.submit {
            runCatching { revokeSession(existing.accessToken) }
            postToMain { onSignOutComplete(requestID) }
        }
    }

    override fun startAccessToken(requestID: Long) {
        val session = storage.load()
        if (session == null) {
            onAccessTokenComplete(requestID, null)
            return
        }
        if (session.expiresAtEpochSeconds > nowEpochSeconds() + REFRESH_LEEWAY_SECONDS) {
            onAccessTokenComplete(requestID, session.accessToken)
            return
        }
        if (session.refreshToken.isBlank() || !config.isConfigured) {
            storage.clear()
            onAccessTokenComplete(requestID, null)
            return
        }
        executor.submit {
            val refreshed = runCatching { refreshSession(session.refreshToken) }.getOrNull()
            postToMain {
                if (refreshed != null) {
                    storage.save(refreshed)
                    onAccessTokenComplete(requestID, refreshed.accessToken)
                } else {
                    storage.clear()
                    onAccessTokenComplete(requestID, null)
                }
            }
        }
    }

    fun shutdown() {
        pendingSignIn = null
        executor.shutdownNow()
    }

    private fun exchangePkceCode(code: String, codeVerifier: String): StoredSession {
        val payload = JSONObject()
            .put("auth_code", code)
            .put("code_verifier", codeVerifier)
            .toString()
        val response = postAuthJson("/auth/v1/token?grant_type=pkce", payload, bearerToken = null)
        return parseSession(response)
    }

    private fun refreshSession(refreshToken: String): StoredSession {
        val payload = JSONObject().put("refresh_token", refreshToken).toString()
        val response = postAuthJson("/auth/v1/token?grant_type=refresh_token", payload, bearerToken = null)
        return parseSession(response)
    }

    private fun revokeSession(accessToken: String) {
        postAuthJson("/auth/v1/logout", "{}", bearerToken = accessToken)
    }

    private fun postAuthJson(path: String, body: String, bearerToken: String?): JSONObject {
        val base = config.supabaseUrl.trimEnd('/')
        val connection = URL(base + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = TIMEOUT_MILLIS
            connection.readTimeout = TIMEOUT_MILLIS
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("apikey", config.supabaseAnonKey)
            if (bearerToken != null) {
                connection.setRequestProperty("Authorization", "Bearer $bearerToken")
            }
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.use { it.readBytes().toString(Charsets.UTF_8) } ?: ""
            if (status !in 200..299) {
                throw AuthDeniedException("Auth request failed with status $status")
            }
            return if (text.isBlank()) JSONObject() else JSONObject(text)
        } finally {
            connection.disconnect()
        }
    }

    private fun parseSession(json: JSONObject): StoredSession {
        val accessToken = json.optString("access_token")
        if (accessToken.isBlank()) throw AuthDeniedException("Missing access_token")
        val refreshToken = json.optString("refresh_token")
        val expiresIn = json.optLong("expires_in", DEFAULT_EXPIRES_IN_SECONDS)
        val expiresAt = json.optLong("expires_at", nowEpochSeconds() + expiresIn)
        return StoredSession(accessToken, refreshToken, expiresAt)
    }

    private fun mapFailureReason(error: Throwable): String = when (error) {
        is AuthDeniedException -> REASON_DENIED
        is SocketTimeoutException -> REASON_TIMED_OUT
        else -> REASON_DISCONNECTED
    }

    private class AuthDeniedException(message: String) : Exception(message)

    companion object {
        const val OUTCOME_SUCCESS = "success"
        const val OUTCOME_CANCELLED = "cancelled"
        const val OUTCOME_FAILED = "failed"
        const val REASON_DISCONNECTED = "disconnected"
        const val REASON_TIMED_OUT = "timedOut"
        const val REASON_DENIED = "denied"

        private const val CANCEL_GRACE_MILLIS = 1_500L
        private const val REFRESH_LEEWAY_SECONDS = 30L
        private const val DEFAULT_EXPIRES_IN_SECONDS = 3_600L
        private const val TIMEOUT_MILLIS = 10_000

        internal fun buildAuthorizeUrl(config: AuthConfig, provider: String, challenge: String): String {
            val base = config.supabaseUrl.trimEnd('/')
            val encodedProvider = URLEncoder.encode(provider, "UTF-8")
            val encodedRedirect = URLEncoder.encode(config.redirectUri, "UTF-8")
            val encodedChallenge = URLEncoder.encode(challenge, "UTF-8")
            return "$base/auth/v1/authorize?provider=$encodedProvider&redirect_to=$encodedRedirect" +
                "&code_challenge=$encodedChallenge&code_challenge_method=S256"
        }

        internal fun generateCodeVerifier(): String {
            val bytes = ByteArray(32)
            SecureRandom().nextBytes(bytes)
            return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        }

        internal fun codeChallengeS256(verifier: String): String {
            val digest = MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.US_ASCII))
            return Base64.encodeToString(digest, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        }
    }
}

private fun defaultMainDelayedPoster(): (Long, () -> Unit) -> Unit {
    val main = Handler(Looper.getMainLooper())
    return { delayMillis, block -> main.postDelayed(block, delayMillis) }
}
