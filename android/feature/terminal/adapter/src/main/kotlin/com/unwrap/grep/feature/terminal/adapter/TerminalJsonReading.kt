package com.unwrap.grep.feature.terminal.adapter

import org.json.JSONObject

internal fun refNumbers(line: JSONObject): List<Int> {
    val refs = line.optJSONArray("refs") ?: return emptyList()
    return (0 until refs.length()).mapNotNull { refs.optJSONObject(it)?.optInt("number") }
}

internal fun JSONObject.optNullableString(name: String): String? =
    if (has(name) && !isNull(name)) optString(name) else null

internal fun JSONObject.optNullableInt(name: String): Int? =
    if (has(name) && !isNull(name)) optInt(name) else null

internal fun JSONObject.stringList(name: String): List<String> {
    val array = optJSONArray(name) ?: return emptyList()
    return (0 until array.length()).map { array.optString(it) }
}

internal fun JSONObject.intList(name: String): List<Int> {
    val array = optJSONArray(name) ?: return emptyList()
    return (0 until array.length()).map { array.optInt(it) }
}
