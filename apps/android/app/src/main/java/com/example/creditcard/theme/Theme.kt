package com.example.creditcard.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

private val ColorDarkPrimaryContainer = Color(0xFF294D40)
private val ColorDarkOutline = Color(0xFF81958A)
private val ColorDarkErrorContainer = Color(0xFF4B2527)
private val ColorDarkErrorText = Color(0xFFFFDAD7)
private val ColorLightPrimaryContainer = Color(0xFFD9EBDF)
private val ColorLightPrimaryText = Color(0xFF193D2E)
private val ColorLightOutline = Color(0xFF728579)
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
    onSecondary = DarkBg,
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
    onErrorContainer = ColorDarkErrorText,
    surfaceContainerLowest = DarkBg,
    surfaceContainerLow = DarkCardBg,
    surfaceContainer = DarkCardBg,
    surfaceContainerHigh = DarkSurfaceVariant,
    surfaceContainerHighest = DarkSurfaceVariant,
    inverseSurface = LightBg,
    inverseOnSurface = TextDark
)

private val LightColorScheme = lightColorScheme(
    primary = GoldPrimary,
    secondary = NavySecondary,
    error = ColorLightError,
    background = LightBg,
    surface = LightCardBg,
    onPrimary = LightCardBg,
    onSecondary = LightCardBg,
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
    onErrorContainer = ColorLightErrorText,
    surfaceContainerLowest = LightCardBg,
    surfaceContainerLow = LightBg,
    surfaceContainer = LightCardBg,
    surfaceContainerHigh = LightSurfaceVariant,
    surfaceContainerHighest = LightSurfaceVariant,
    inverseSurface = TextDark,
    inverseOnSurface = TextWhite
)

private val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(6.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(28.dp)
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
