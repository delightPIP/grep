package com.unwrap.grep.core

import android.content.Context
import android.content.SharedPreferences
import com.unwrap.grep.swiftbridge.HistoryStoreBridge
import java.util.Optional

/**
 * Swift `HistoryStoreBridge`의 구현(COM-009). 터미널 기록을 `SharedPreferences`에 저장하고 읽는다.
 */
class SharedPrefsHistoryStore(
    private val readValue: (String) -> String?,
    private val writeValues: (subject: String, payload: String) -> Unit,
    private val clearValues: () -> Unit,
) : HistoryStoreBridge {
    constructor(context: Context) : this(context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE))

    constructor(prefs: SharedPreferences) : this(
        readValue = { key -> prefs.getString(key, null) },
        writeValues = { subject, payload ->
            prefs.edit().putString(KEY_SUBJECT, subject).putString(KEY_PAYLOAD, payload).apply()
        },
        clearValues = {
            prefs.edit().remove(KEY_SUBJECT).remove(KEY_PAYLOAD).apply()
        },
    )

    override fun loadEncoded(): Optional<String> {
        val subject = readValue(KEY_SUBJECT)?.takeIf { it.isNotEmpty() } ?: return Optional.empty()
        val payload = readValue(KEY_PAYLOAD) ?: return Optional.empty()
        return Optional.of("$subject\n$payload")
    }

    override fun save(subject: String, payload: String) {
        writeValues(subject, payload)
    }

    override fun clear() {
        clearValues()
    }

    private companion object {
        const val PREFS_NAME = "grep_history_store"
        const val KEY_SUBJECT = "subject"
        const val KEY_PAYLOAD = "payload"
    }
}
