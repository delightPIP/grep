package com.unwrap.grep.core

import com.unwrap.grep.swiftbridge.FilePortBridge
import com.unwrap.grep.swiftbridge.FilePortHandle
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future

/**
 * Swift `FilePortBridge`의 구현. 끌어다 놓거나 선택한 파일 바이트를 메모리에 들고 있다가
 * 서명 URL로 HTTP PUT 업로드를 수행하고, 완료·해제 시 바이트를 놓는다.
 */
class AndroidFilePort(
    private val onComplete: (requestID: Long) -> Unit,
    private val onFail: (requestID: Long, reason: String) -> Unit,
    private val executor: ExecutorService = Executors.newCachedThreadPool(),
    private val postToMain: (() -> Unit) -> Unit = defaultMainPoster(),
) : FilePortBridge {
    constructor(handle: FilePortHandle) : this(
        onComplete = { handle.completeUpload(it) },
        onFail = { id, reason -> handle.failUpload(id, reason) },
    )

    private val files = ConcurrentHashMap<String, ByteArray>()
    private val running = mutableMapOf<Long, Future<*>>()

    /** 업로드 대상 파일 바이트를 등록한다. */
    fun register(fileID: String, bytes: ByteArray) {
        files[fileID] = bytes
    }

    override fun startUpload(requestID: Long, fileID: String, uploadURL: String) {
        val bytes = files[fileID]
        if (bytes == null) {
            onFail(requestID, REASON_MISSING_FILE)
            return
        }
        running[requestID] = executor.submit {
            val outcome = runCatching { uploadBytes(uploadURL, bytes) }
            postToMain {
                if (running.remove(requestID) == null) return@postToMain
                outcome.fold(
                    onSuccess = { status ->
                        if (status in 200..299) {
                            onComplete(requestID)
                        } else {
                            onFail(requestID, REASON_REJECTED)
                        }
                    },
                    onFailure = { error ->
                        val reason = if (error is SocketTimeoutException) REASON_TIMED_OUT else REASON_UNREACHABLE
                        onFail(requestID, reason)
                    },
                )
            }
        }
    }

    override fun cancelUpload(requestID: Long) {
        running.remove(requestID)?.cancel(true)
    }

    override fun release(fileID: String) {
        files.remove(fileID)
    }

    fun shutdown() {
        running.clear()
        files.clear()
        executor.shutdownNow()
    }

    private fun uploadBytes(uploadURL: String, bytes: ByteArray): Int {
        val connection = URL(uploadURL).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "PUT"
            connection.connectTimeout = TIMEOUT_MILLIS
            connection.readTimeout = TIMEOUT_MILLIS
            connection.doOutput = true
            connection.setFixedLengthStreamingMode(bytes.size)
            connection.setRequestProperty("Content-Type", "application/octet-stream")
            connection.outputStream.use { it.write(bytes) }
            return connection.responseCode
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        const val REASON_UNREACHABLE = "unreachable"
        const val REASON_TIMED_OUT = "timedOut"
        const val REASON_REJECTED = "rejected"
        const val REASON_MISSING_FILE = "missingFile"
        private const val TIMEOUT_MILLIS = 30_000
    }
}
