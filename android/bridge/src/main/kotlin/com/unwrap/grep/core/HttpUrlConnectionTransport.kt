package com.unwrap.grep.core

import android.os.Handler
import android.os.Looper
import com.unwrap.grep.swiftbridge.HTTPTransportBridge
import com.unwrap.grep.swiftbridge.HTTPTransportHandle
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future

/**
 * Swift `HTTPTransportBridge`의 구현. 요청을 `HttpURLConnection`으로 보내 플랫폼의 인증서·프록시 설정을 그대로 쓴다.
 * 상태 코드가 오류여도 응답으로 돌려주며, 응답을 받지 못했을 때만 `fail(isTimeout)`을 부른다.
 */
class HttpUrlConnectionTransport(
    private val baseUrl: String,
    private val handle: HTTPTransportHandle,
    private val executor: ExecutorService = Executors.newCachedThreadPool(),
    private val postToMain: (() -> Unit) -> Unit = defaultMainPoster(),
) : HTTPTransportBridge {
    private val running = mutableMapOf<Long, Future<*>>()

    override fun start(requestID: Long, method: String, path: String, headers: String, body: String) {
        running[requestID] = executor.submit {
            val result = runCatching { send(method, path, headers, body) }
            postToMain {
                if (running.remove(requestID) == null) return@postToMain
                result.fold(
                    onSuccess = { (status, responseBody) -> handle.complete(requestID, status, responseBody) },
                    onFailure = { error -> handle.fail(requestID, error is SocketTimeoutException) },
                )
            }
        }
    }

    override fun cancel(requestID: Long) {
        running.remove(requestID)?.cancel(true)
    }

    fun shutdown() {
        running.clear()
        executor.shutdownNow()
    }

    internal fun send(method: String, path: String, headers: String, body: String): Pair<Int, String> {
        val normalizedBase = baseUrl.trimEnd('/')
        val connection = URL(normalizedBase + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = TIMEOUT_MILLIS
            connection.readTimeout = TIMEOUT_MILLIS
            headers.lineSequence().filter { it.isNotEmpty() }.forEach { line ->
                val (name, value) = line.split(": ", limit = 2)
                connection.setRequestProperty(name, value)
            }
            if (body.isNotEmpty()) {
                connection.doOutput = true
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val responseBody = stream?.use { it.readBytes().toString(Charsets.UTF_8) } ?: ""
            return status to responseBody
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        const val TIMEOUT_MILLIS = 10_000
    }
}

internal fun defaultMainPoster(): (() -> Unit) -> Unit {
    val main = Handler(Looper.getMainLooper())
    return { block -> main.post(block) }
}
