package com.samuel.chirpy.core.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors =
    lightColorScheme(
        primary = Color(0xFF28644B),
        background = Color(0xFFFCFCF8),
        surface = Color(0xFFFCFCF8),
    )
private val DarkColors =
    darkColorScheme(
        primary = Color(0xFF9CD5B4),
        background = Color(0xFF101511),
        surface = Color(0xFF101511),
    )

@Composable
fun ChirpyTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        content = content,
    )
}
