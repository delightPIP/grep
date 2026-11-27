package com.unwrap.grep.core

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import com.unwrap.grep.swiftbridge.ClipboardPortBridge
import com.unwrap.grep.swiftbridge.ClipboardPortHandle

/**
 * Swift `ClipboardPortBridge`의 구현. 시스템 클립보드에 글을 넣고 성공 여부를 돌려준다(COM-008).
 */
class AndroidClipboardPort(
    private val copyText: (String) -> Boolean,
    private val onResult: (requestID: Long, copied: Boolean) -> Unit,
) : ClipboardPortBridge {
    constructor(context: Context, handle: ClipboardPortHandle) : this(
        copyText = { text ->
            try {
                val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                if (manager == null) {
                    false
                } else {
                    manager.setPrimaryClip(ClipData.newPlainText("grep", text))
                    true
                }
            } catch (_: Throwable) {
                false
            }
        },
        onResult = { requestID, copied -> handle.completeCopy(requestID, copied) },
    )

    override fun startCopy(requestID: Long, text: String) {
        onResult(requestID, copyText(text))
    }
}
