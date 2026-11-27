package com.unwrap.grep.feature.loggedin.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LoggedInTabTest {
    @Test
    fun 로그인탭목록을조회할때_순서와이름을확인하면_터미널보관함설정순인지() {
        // given
        val tabs = LoggedInTab.entries

        // when
        val labels = tabs.map { it.label }

        // then
        assertEquals(listOf("터미널", "보관함", "설정"), labels)
    }

    @Test
    fun 키보드나선택이나모달이떠있을때_탭바표시여부를계산하면_숨겨지는지() {
        // given & when & then
        assertTrue(shouldShowBottomTabBar(isKeyboardVisible = false, isSelecting = false, isModalPresented = false))
        assertFalse(shouldShowBottomTabBar(isKeyboardVisible = true, isSelecting = false, isModalPresented = false))
        assertFalse(shouldShowBottomTabBar(isKeyboardVisible = false, isSelecting = true, isModalPresented = false))
        assertFalse(shouldShowBottomTabBar(isKeyboardVisible = false, isSelecting = false, isModalPresented = true))
    }
}
