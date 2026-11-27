package com.unwrap.grep.feature.loggedout.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** 로그인 방식(ACC-001). Google과 GitHub 둘뿐이다. */
enum class AuthProviderUi(val rawValue: String, val buttonLabel: String) {
    GOOGLE("google", "Google로 계속"),
    GITHUB("github", "GitHub로 계속"),
}

/** 외부 로그인 실패 이유(ACC-001). */
enum class SignInFailureReasonUi(val label: String) {
    DISCONNECTED("연결 끊김"),
    TIMED_OUT("응답 없음"),
    DENIED("권한 거부"),
}

/** 로그인 화면 안내 한 줄(ACC-001 사용자 문구 원문). */
sealed interface LoggedOutNoticeUi {
    data object Cancelled : LoggedOutNoticeUi
    data class Failed(val reason: SignInFailureReasonUi) : LoggedOutNoticeUi
    data object Expired : LoggedOutNoticeUi
    data object SignedOut : LoggedOutNoticeUi
}

enum class NoticeTone { OK, WARN, ERROR }

data class FormattedNotice(
    val tone: NoticeTone,
    val symbol: String,
    val emphasis: String,
    val tail: String,
) {
    val fullText: String get() = "$symbol $emphasis$tail"
}

/** ACC-001 사용자 문구 원문으로 변환한다. */
fun formatLoggedOutNotice(notice: LoggedOutNoticeUi): FormattedNotice = when (notice) {
    LoggedOutNoticeUi.Cancelled -> FormattedNotice(NoticeTone.ERROR, "✗", "로그인 취소됨", "")
    is LoggedOutNoticeUi.Failed -> FormattedNotice(NoticeTone.ERROR, "✗", "로그인 실패:", " ${notice.reason.label}")
    LoggedOutNoticeUi.Expired -> FormattedNotice(NoticeTone.WARN, "!", "로그인 만료", " → 다시 로그인")
    LoggedOutNoticeUi.SignedOut -> FormattedNotice(NoticeTone.OK, "✓", "로그아웃됨", "")
}

object LoggedOutTags {
    const val TOP_BAR = "loggedOutTopBar"
    const val PROMPT = "loggedOutPrompt"
    const val NOTICE = "loggedOutNotice"
    const val GOOGLE_BUTTON = "loggedOutGoogleButton"
    const val GITHUB_BUTTON = "loggedOutGithubButton"
}

// grep-design/mockups/project/ds/grep/tokens.json (dark)
private val SurfaceColor = Color(0xFF14171C)
private val SurfaceRaisedColor = Color(0xFF1C2027)
private val LineColor = Color(0xFF2E343D)
private val InkColor = Color(0xFFE7E9EC)
private val InkMutedColor = Color(0xFF99A2AD)
private val PromptColor = Color(0xFF7FE0A3)
private val CommandColor = Color(0xFF86C8FF)
private val NoticeColor = Color(0xFFF2C86B)
private val DangerColor = Color(0xFFFF8F86)

// grep-design/mockups/project/ds/grep/components/bundle.js MOLE_PAL / MOLE.idle (16x16)
private val MolePalette = mapOf(
    'M' to Color(0xFF4A4460),
    'R' to Color(0xFF6A4228),
    'h' to Color(0xFFF5C9A3),
    'm' to Color(0xFF6C6585),
    'o' to Color(0xFF16120F),
    'q' to Color(0xFF99A2AD),
    'r' to Color(0xFF8A5A3A),
    's' to Color(0xFFF2A0A8),
    'w' to Color(0xFFFBFBF8),
    'y' to Color(0xFFF2C86B),
)

private val MoleIdleRows = listOf(
    "................",
    "................",
    ".....oooooo.....",
    "....ommmmmmo....",
    "...ommmmmmmmo...",
    "...omommmmomo...",
    "..ommomssmommo..",
    "..ommmssssmmmo..",
    "..ohhmmmmmmhho..",
    ".ohhhmmMMmmhhho.",
    ".ommmmMMMMmmmmo.",
    "..ommmmmmmmmmo..",
    ".rrommmmmmmmorr.",
    "rrrRrrrrrrRrrrrr",
    ".rrrrrRrrrrrrrr.",
    "................",
)

/**
 * 모바일 로그인 화면 순수 뷰(시안: MobileLogin.dc.html, 정책: ACC-001).
 * 로그인 전에는 탭바·입력줄을 두지 않는다.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LoggedOutView(
    notice: LoggedOutNoticeUi?,
    isSigningIn: Boolean,
    onSignIn: (AuthProviderUi) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(SurfaceColor)
            .navigationBarsPadding(),
    ) {
        // MTopBar: 그렙 — 로그인
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(SurfaceRaisedColor)
                .statusBarsPadding()
                .testTag(LoggedOutTags.TOP_BAR),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .padding(horizontal = 16.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                Text(
                    text = buildAnnotatedString {
                        withStyle(SpanStyle(color = PromptColor, fontWeight = FontWeight.Bold)) {
                            append("그렙")
                        }
                        withStyle(SpanStyle(color = InkColor, fontWeight = FontWeight.Bold)) {
                            append(" — 로그인")
                        }
                    },
                    fontFamily = FontFamily.Monospace,
                    fontSize = 14.sp,
                    lineHeight = 22.sp,
                )
            }
            HorizontalDivider(thickness = 1.dp, color = LineColor)
        }

        // 본문 (MobileLogin.dc.html main: padding 16px, gap 4px)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            // Grep.Banner (mascot: idle 48dp, tagline: 담기 → 찾기 → 넘기기)
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                MoleMascotIdle(size = 48.dp)
                Column {
                    Text(
                        text = "그렙 ~ $",
                        color = PromptColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 32.sp,
                        lineHeight = 40.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = "담기 → 찾기 → 넘기기",
                        color = InkMutedColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 14.sp,
                        lineHeight = 22.sp,
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // 상태·안내 줄 (Grep.Line)
            if (notice == null) {
                TerminalLine(
                    symbol = "·",
                    symbolColor = CommandColor,
                    emphasis = "로그인 필요",
                    emphasisColor = InkColor,
                    tail = "",
                    modifier = Modifier.testTag(LoggedOutTags.PROMPT),
                )
            } else {
                val formatted = formatLoggedOutNotice(notice)
                val toneColor = when (formatted.tone) {
                    NoticeTone.OK -> PromptColor
                    NoticeTone.WARN -> NoticeColor
                    NoticeTone.ERROR -> DangerColor
                }
                val emphasisColor = when (formatted.tone) {
                    NoticeTone.OK -> InkColor
                    NoticeTone.WARN -> NoticeColor
                    NoticeTone.ERROR -> DangerColor
                }
                TerminalLine(
                    symbol = formatted.symbol,
                    symbolColor = toneColor,
                    emphasis = formatted.emphasis,
                    emphasisColor = emphasisColor,
                    tail = formatted.tail,
                    modifier = Modifier.testTag(LoggedOutTags.NOTICE),
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            // UiCard (surface-raised, 1px line, radius 8px, padding 12px)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(SurfaceRaisedColor, RoundedCornerShape(8.dp))
                    .border(1.dp, LineColor, RoundedCornerShape(8.dp))
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    AuthProviderUi.entries.forEach { provider ->
                        val tag = when (provider) {
                            AuthProviderUi.GOOGLE -> LoggedOutTags.GOOGLE_BUTTON
                            AuthProviderUi.GITHUB -> LoggedOutTags.GITHUB_BUTTON
                        }
                        // UiButton (secondary, md 44dp, radius 3dp)
                        OutlinedButton(
                            onClick = { onSignIn(provider) },
                            enabled = !isSigningIn,
                            shape = RoundedCornerShape(3.dp),
                            border = BorderStroke(1.dp, LineColor),
                            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 0.dp),
                            colors = ButtonDefaults.outlinedButtonColors(
                                containerColor = SurfaceColor,
                                contentColor = CommandColor,
                                disabledContainerColor = SurfaceColor.copy(alpha = 0.5f),
                                disabledContentColor = InkMutedColor,
                            ),
                            modifier = Modifier
                                .heightIn(min = 44.dp)
                                .testTag(tag),
                        ) {
                            Text(
                                text = provider.buttonLabel,
                                fontFamily = FontFamily.Monospace,
                                fontSize = 14.sp,
                                lineHeight = 22.sp,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TerminalLine(
    symbol: String,
    symbolColor: Color,
    emphasis: String,
    emphasisColor: Color,
    tail: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            text = symbol,
            color = symbolColor,
            fontFamily = FontFamily.Monospace,
            fontSize = 14.sp,
            lineHeight = 22.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.width(20.dp),
        )
        Text(
            text = buildAnnotatedString {
                withStyle(SpanStyle(color = emphasisColor, fontWeight = FontWeight.Bold)) {
                    append(emphasis)
                }
                if (tail.isNotEmpty()) {
                    withStyle(SpanStyle(color = InkColor)) {
                        append(tail)
                    }
                }
            },
            fontFamily = FontFamily.Monospace,
            fontSize = 14.sp,
            lineHeight = 22.sp,
        )
    }
}

@Composable
private fun MoleMascotIdle(size: Dp, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(size)) {
        val cell = this.size.width / 16f
        MoleIdleRows.forEachIndexed { y, row ->
            row.forEachIndexed { x, ch ->
                val color = MolePalette[ch] ?: return@forEachIndexed
                drawRect(
                    color = color,
                    topLeft = Offset(x * cell, y * cell),
                    size = Size(cell, cell),
                )
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun LoggedOutViewInitialPreview() {
    LoggedOutView(notice = null, isSigningIn = false, onSignIn = {})
}

@Preview(showBackground = true)
@Composable
private fun LoggedOutViewExpiredPreview() {
    LoggedOutView(notice = LoggedOutNoticeUi.Expired, isSigningIn = false, onSignIn = {})
}
