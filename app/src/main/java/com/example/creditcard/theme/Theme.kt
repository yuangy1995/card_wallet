package com.example.creditcard.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

// 🌑 深色科技色彩架构
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
    primaryContainer = NeonGreen
)

// ☀️ 浅色轻奢色彩架构
private val LightColorScheme = lightColorScheme(
    primary = GoldPrimary,
    secondary = NavySecondary,
    error = WarmOrange,
    background = LightBg,
    surface = LightCardBg,
    onPrimary = LightCardBg,
    onSecondary = TextDark,
    onBackground = TextDark,
    onSurface = TextDark,
    primaryContainer = ForestGreen
)

/**
 * 信用卡应用全局主题包装器
 * 支持深色科技暗黑风与浅色轻奢白风的无缝热切换
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
        content = content
    )
}
