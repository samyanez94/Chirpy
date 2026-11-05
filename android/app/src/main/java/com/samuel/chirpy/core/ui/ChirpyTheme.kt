package com.samuel.chirpy.core.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import com.samuel.chirpy.R

// Dark foregrounds keep text on the exact brand blue readable in either theme.
private val OnBrandBlue = Color(0xFF001329)

private val LightColors = lightColorScheme(
    onPrimary = OnBrandBlue,
    primaryContainer = Color(0xFFDCEBFF),
    onPrimaryContainer = Color(0xFF001B3F),
    inversePrimary = Color(0xFFA8CBFF),
    onSecondary = OnBrandBlue,
    secondaryContainer = Color(0xFFDCEBFF),
    onSecondaryContainer = Color(0xFF001B3F),
    onTertiary = OnBrandBlue,
    tertiaryContainer = Color(0xFFDCEBFF),
    onTertiaryContainer = Color(0xFF001B3F),
    background = Color(0xFFFCFCFF),
    onBackground = Color(0xFF191C20),
    surface = Color(0xFFFCFCFF),
    onSurface = Color(0xFF191C20),
    surfaceVariant = Color(0xFFE0E7F0),
    onSurfaceVariant = Color(0xFF424A55),
    outline = Color(0xFF737C89),
    outlineVariant = Color(0xFFC3CBD6),
    inverseSurface = Color(0xFF2D3137),
    inverseOnSurface = Color(0xFFF0F2F7),
    surfaceBright = Color(0xFFFCFCFF),
    surfaceDim = Color(0xFFD8DBE1),
    surfaceContainerLowest = Color.White,
    surfaceContainerLow = Color(0xFFF5F7FC),
    surfaceContainer = Color(0xFFEFF2F8),
    surfaceContainerHigh = Color(0xFFE9EDF4),
    surfaceContainerHighest = Color(0xFFE3E7EF),
)

private val DarkColors = darkColorScheme(
    onPrimary = OnBrandBlue,
    primaryContainer = Color(0xFF003D80),
    onPrimaryContainer = Color(0xFFDCEBFF),
    inversePrimary = Color(0xFF005FC7),
    onSecondary = OnBrandBlue,
    secondaryContainer = Color(0xFF233F62),
    onSecondaryContainer = Color(0xFFDCEBFF),
    onTertiary = OnBrandBlue,
    tertiaryContainer = Color(0xFF003D80),
    onTertiaryContainer = Color(0xFFDCEBFF),
    background = Color(0xFF101318),
    onBackground = Color(0xFFE2E7EF),
    surface = Color(0xFF101318),
    onSurface = Color(0xFFE2E7EF),
    surfaceVariant = Color(0xFF424A55),
    onSurfaceVariant = Color(0xFFC3CBD6),
    outline = Color(0xFF8D97A5),
    outlineVariant = Color(0xFF424A55),
    inverseSurface = Color(0xFFE2E7EF),
    inverseOnSurface = Color(0xFF2D3137),
    surfaceBright = Color(0xFF363B43),
    surfaceDim = Color(0xFF101318),
    surfaceContainerLowest = Color(0xFF0B0E13),
    surfaceContainerLow = Color(0xFF191D24),
    surfaceContainer = Color(0xFF1D222A),
    surfaceContainerHigh = Color(0xFF282D35),
    surfaceContainerHighest = Color(0xFF323740),
)

@Composable
fun ChirpyTheme(content: @Composable () -> Unit) {
    val blue = colorResource(R.color.chirpy_blue)
    val colors = if (isSystemInDarkTheme()) DarkColors else LightColors
    MaterialTheme(
        colorScheme = colors.copy(
            primary = blue,
            secondary = blue,
            tertiary = blue,
            surfaceTint = blue,
        ),
        content = content,
    )
}
