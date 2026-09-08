package com.example.creditcard.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

private val ColorDarkPrimaryContainer = Color(0xFF2B3E55)
private val ColorDarkOutline = Color(0xFF4A515C)
private val ColorDarkErrorContainer = Color(0xFF4B2527)
private val ColorDarkErrorText = Color(0xFFFFDAD7)
private val ColorLightPrimaryContainer = Color(0xFFD9E7F7)
private val ColorLightPrimaryText = Color(0xFF18324E)
private val ColorLightOutline = Color(0xFF7A828D)
private val ColorLightError = Color(0xFFB3261E)
private val ColorLightErrorContainer = Color(0xFFFFDAD6)
private val ColorLightErrorText = Color(0xFF410002)

private val DarkColorScheme = darkColorScheme(
    primary = NeonCyan,
    secondary = NeonPurple,
    error = NeonRed,
    background = DarkBg,
    surface = DarkCardBg,
    onPrimary = DarkBg,
    onSecondary = TextWhite,
    onBackground = TextWhite,
    onSurface = TextWhite,
    primaryContainer = ColorDarkPrimaryContainer,
    onPrimaryContainer = TextWhite,
    secondaryContainer = DarkSurfaceVariant,
    onSecondaryContainer = TextWhite,
    surfaceVariant = DarkSurfaceVariant,
    onSurfaceVariant = TextGray,
    outline = ColorDarkOutline,
    outlineVariant = DarkDivider,
    errorContainer = ColorDarkErrorContainer,
    onErrorContainer = ColorDarkErrorText
)

private val LightColorScheme = lightColorScheme(
    primary = GoldPrimary,
    secondary = NavySecondary,
    error = ColorLightError,
    background = LightBg,
    surface = LightCardBg,
    onPrimary = LightCardBg,
    onSecondary = TextDark,
    onBackground = TextDark,
    onSurface = TextDark,
    primaryContainer = ColorLightPrimaryContainer,
    onPrimaryContainer = ColorLightPrimaryText,
    secondaryContainer = LightSurfaceVariant,
    onSecondaryContainer = TextDark,
    surfaceVariant = LightSurfaceVariant,
    onSurfaceVariant = TextMuted,
    outline = ColorLightOutline,
    outlineVariant = LightDivider,
    errorContainer = ColorLightErrorContainer,
    onErrorContainer = ColorLightErrorText
)

private val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(6.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(20.dp)
)

/**
 * 信用卡应用全局主题包装器。
 * 深浅色模式使用同一套信息层级和语义颜色。
 */
@Composable
fun CreditCardTheme(
    darkTheme: Boolean,
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        shapes = AppShapes,
        content = content
    )
}
