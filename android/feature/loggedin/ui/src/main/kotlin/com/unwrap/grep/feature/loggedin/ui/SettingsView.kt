package com.unwrap.grep.feature.loggedin.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

/** 이 기기 로그아웃 확인 시트 문구(ACC-001). iOS `SettingsView`와 같다. */
internal object SignOutSheetCopy {
    const val TITLE = "로그아웃? 이 기기"
    val LINES = listOf("이 기기의 터미널 기록도 지움", "다른 기기와 AI 도구 연결은 그대로 둠")
    const val PRIMARY = "로그아웃"
    const val CANCEL = "취소"
}

/** 설정 탭 순수 뷰(MOB-001, ACC-001, ACC-002, 시안 `MobileSettings.dc.html` · `UiSettingRow.dc.html`). */
@Composable
fun SettingsView(
    presentation: SettingsPresentation,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
    resetToRootTrigger: Int = 0,
    onModalVisibilityChange: (Boolean) -> Unit = {},
    scrollState: ScrollState = rememberScrollState(),
) {
    var showSignOutSheet by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(showSignOutSheet) { onModalVisibilityChange(showSignOutSheet) }
    // MOB-001 규칙 8: 설정 탭을 다시 누르면 첫 화면으로 돌아간다.
    LaunchedEffect(resetToRootTrigger) {
        if (resetToRootTrigger > 0) {
            showSignOutSheet = false
            scrollState.animateScrollTo(0)
        }
    }
    BackHandler(enabled = showSignOutSheet) { showSignOutSheet = false }

    Box(modifier = modifier.fillMaxSize().background(LoggedInPalette.Surface)) {
        Column(modifier = Modifier.fillMaxSize()) {
            GrepTopBar(title = "설정")
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .verticalScroll(scrollState)
                    .padding(16.dp)
                    .testTag("settingsList"),
            ) {
                SettingsRows(presentation, onSignOutRequested = { showSignOutSheet = true })
            }
        }
        if (showSignOutSheet) {
            GrepBottomSheet(
                title = SignOutSheetCopy.TITLE,
                lines = SignOutSheetCopy.LINES,
                primaryLabel = SignOutSheetCopy.PRIMARY,
                primaryKind = GrepButtonKind.DANGER,
                cancelLabel = SignOutSheetCopy.CANCEL,
                onPrimary = {
                    showSignOutSheet = false
                    onSignOut()
                },
                onCancel = { showSignOutSheet = false },
            )
        }
    }
}

@Composable
private fun SettingsRows(presentation: SettingsPresentation, onSignOutRequested: () -> Unit) {
    SectionHeader("계정", isFirst = true)
    presentation.accountLabel?.let { label ->
        GrepSettingRow(label = label, sub = presentation.accountDetail.orEmpty())
    }
    GrepSettingRow(
        label = "이 기기 로그아웃",
        sub = "이 기기의 터미널 기록도 지움",
        actionLabel = if (presentation.isSigningOut) "로그아웃 중…" else "로그아웃",
        actionEnabled = !presentation.isSigningOut,
        actionTestTag = "settingsSignOutButton",
        onAction = onSignOutRequested,
    )
    GrepSettingRow(
        label = "모든 기기 로그아웃",
        sub = "AI 도구 연결도 끊김 · 준비 중",
        actionLabel = "모든 기기",
        actionKind = GrepButtonKind.DANGER,
        actionTestTag = "settingsFuture_signOutAll",
    )

    SectionHeader("AI 도구 연결")
    GrepSettingRow(label = "연결 목록", sub = "연결 주소 · 끊기 · 준비 중")

    SectionHeader("화면")
    GrepSettingRow(label = "테마", sub = "어두운 · 준비 중", actionLabel = "바꾸기", actionTestTag = "settingsFuture_theme")

    SectionHeader("자료")
    GrepSettingRow(
        label = "휴지통",
        sub = "30일 뒤 영구 삭제 · 준비 중",
        actionLabel = "열기",
        actionTestTag = "settingsFuture_trash",
    )

    SectionHeader("정보")
    GrepSettingRow(label = presentation.appVersionLabel, sub = "만든 팀 Unwrap")
}

@Composable
private fun SectionHeader(title: String, isFirst: Boolean = false) {
    MonoText(
        text = title,
        color = LoggedInPalette.Ink,
        bold = true,
        modifier = Modifier.padding(top = if (isFirst) 0.dp else 12.dp, bottom = 4.dp),
    )
}
