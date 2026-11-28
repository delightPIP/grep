package com.unwrap.grep.feature.loggedin.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex

/** MOB-001 규칙 1·3: 왼쪽부터 터미널·보관함·설정 3탭. 앱을 열면 늘 터미널 탭에서 시작한다. */
enum class LoggedInTab(val label: String, val iconGlyph: String) {
    TERMINAL("터미널", ">_"),
    ARCHIVE("보관함", "[]"),
    SETTINGS("설정", "::"),
}

/** MOB-001 규칙 4: 키보드·시트·고르기 중에는 탭바를 숨긴다. */
fun shouldShowBottomTabBar(
    isKeyboardVisible: Boolean,
    isSelecting: Boolean,
    isModalPresented: Boolean,
): Boolean = !isKeyboardVisible && !isSelecting && !isModalPresented

object LoggedInTabTags {
    const val TAB_BAR = "loggedInTabBar"
    fun tab(tab: LoggedInTab): String = "loggedInTab_${tab.name.lowercase()}"
}

private val SurfaceColor = LoggedInPalette.Surface
private val SurfaceRaisedColor = LoggedInPalette.SurfaceRaised
private val LineColor = LoggedInPalette.Line
private val InkMutedColor = LoggedInPalette.InkMuted
private val PromptColor = LoggedInPalette.Prompt

/**
 * 로그인 후 하단 탭 컨테이너(MOB-001).
 * - 탭을 옮겨도 터미널 컴포지션을 유지해 출력 기록과 입력 내용을 보존한다(MOB-001 규칙 6).
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LoggedInTabContainer(
    selectedTab: LoggedInTab,
    onSelectTab: (LoggedInTab) -> Unit,
    isSelecting: Boolean,
    terminalContent: @Composable () -> Unit,
    archiveContent: @Composable () -> Unit,
    settingsContent: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    isModalPresented: Boolean = false,
    onReselect: (LoggedInTab) -> Unit = {},
) {
    val isKeyboardVisible = WindowInsets.isImeVisible
    val showTabBar = shouldShowBottomTabBar(
        isKeyboardVisible = isKeyboardVisible,
        isSelecting = isSelecting,
        isModalPresented = isModalPresented,
    )

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(SurfaceColor),
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
        ) {
            // 터미널은 항상 컴포지션에 유지해 탭 전환 시 상태 보존(MOB-001 규칙 6)
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .zIndex(if (selectedTab == LoggedInTab.TERMINAL) 1f else 0f)
                    .graphicsLayer { alpha = if (selectedTab == LoggedInTab.TERMINAL) 1f else 0f },
            ) {
                terminalContent()
            }

            if (selectedTab == LoggedInTab.ARCHIVE) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .zIndex(2f)
                        .background(SurfaceColor),
                ) {
                    archiveContent()
                }
            } else if (selectedTab == LoggedInTab.SETTINGS) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .zIndex(2f)
                        .background(SurfaceColor),
                ) {
                    settingsContent()
                }
            }
        }

        if (showTabBar) {
            BottomTabBar(
                selectedTab = selectedTab,
                onSelect = { tab ->
                    if (tab == selectedTab) onReselect(tab) else onSelectTab(tab)
                },
            )
        }
    }
}

@Composable
private fun BottomTabBar(
    selectedTab: LoggedInTab,
    onSelect: (LoggedInTab) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(SurfaceRaisedColor)
            .navigationBarsPadding()
            .testTag(LoggedInTabTags.TAB_BAR),
    ) {
        HorizontalDivider(thickness = 1.dp, color = LineColor)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 52.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            LoggedInTab.entries.forEach { tab ->
                val active = tab == selectedTab
                val contentColor = if (active) PromptColor else InkMutedColor
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .heightIn(min = 48.dp)
                        .clickable { onSelect(tab) }
                        .padding(vertical = 6.dp)
                        .testTag(LoggedInTabTags.tab(tab)),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text(
                        text = tab.iconGlyph,
                        color = contentColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = tab.label,
                        color = contentColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 11.sp,
                        fontWeight = if (active) FontWeight.Bold else FontWeight.Normal,
                    )
                }
            }
        }
    }
}
