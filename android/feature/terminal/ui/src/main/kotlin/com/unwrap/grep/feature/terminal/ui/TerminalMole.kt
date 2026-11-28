package com.unwrap.grep.feature.terminal.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp

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

@Composable
internal fun MoleMascotIdle(size: Dp, modifier: Modifier = Modifier) {
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
