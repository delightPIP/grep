package com.unwrap.grep.feature.loggedin.ui

/** 보관함 목록의 자료 한 행(시안 `MList.dc.html`). */
data class ArchiveItemRow(
    val number: Int,
    val title: String,
    val meta: String,
    val summary: String?,
    val summaryIsWarning: Boolean,
    val tags: List<String>,
    val isPicked: Boolean = false,
)

/** 보관함 순수 뷰가 그리는 값 전체. */
data class ArchivePresentation(
    val statusText: String = "자료",
    val items: List<ArchiveItemRow> = emptyList(),
    val pickedCount: Int = 0,
    val pickedSummary: String = "",
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = false,
    val errorMessage: String? = null,
)

/** 설정 탭 순수 뷰가 그리는 값 전체(시안 `MobileSettings.dc.html` M10). */
data class SettingsPresentation(
    val accountLabel: String? = null,
    val accountDetail: String? = null,
    val isSigningOut: Boolean = false,
    val appVersionLabel: String = "그렙 0.1",
)
