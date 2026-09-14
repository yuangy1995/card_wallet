package com.example.creditcard.utils

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ThemeDefaultsTest {
    private val context get() = ApplicationProvider.getApplicationContext<Context>()
    private fun clear() { context.getSharedPreferences("credit_card_theme_prefs", Context.MODE_PRIVATE).edit().clear().commit() }

    @Test fun freshInstallFollowsLightSystem() {
        clear(); RuntimeEnvironment.setQualifiers("notnight"); ThemeManager.init(context)
        assertEquals(AppThemeMode.SYSTEM, ThemeManager.themeMode.value)
        assertFalse(ThemeManager.isDarkTheme.value)
    }
    @Test fun freshInstallFollowsDarkSystem() {
        clear(); RuntimeEnvironment.setQualifiers("night"); ThemeManager.init(context)
        assertEquals(AppThemeMode.SYSTEM, ThemeManager.themeMode.value)
        assertTrue(ThemeManager.isDarkTheme.value)
    }
    @Test fun storedPreferenceSurvivesRestartAndSystemChanges() {
        clear(); RuntimeEnvironment.setQualifiers("notnight")
        ThemeManager.setThemeMode(context, AppThemeMode.DARK); ThemeManager.init(context)
        assertEquals(AppThemeMode.DARK, ThemeManager.themeMode.value)
        assertTrue(ThemeManager.isDarkTheme.value)
        ThemeManager.setThemeMode(context, AppThemeMode.LIGHT); RuntimeEnvironment.setQualifiers("night"); ThemeManager.init(context)
        assertFalse(ThemeManager.isDarkTheme.value)
    }
    @Test fun invalidPreferenceAndResetUseSystem() {
        clear(); RuntimeEnvironment.setQualifiers("notnight")
        context.getSharedPreferences("credit_card_theme_prefs", Context.MODE_PRIVATE).edit().putString("theme_mode", "invalid").commit()
        ThemeManager.init(context); assertEquals(AppThemeMode.SYSTEM, ThemeManager.themeMode.value)
        ThemeManager.setThemeMode(context, AppThemeMode.DARK); ThemeManager.resetToDefault(context)
        assertEquals(AppThemeMode.SYSTEM, ThemeManager.themeMode.value)
        assertFalse(ThemeManager.isDarkTheme.value)
    }
    @Test fun systemSelectionReevaluatesAfterConfigurationChange() {
        clear(); RuntimeEnvironment.setQualifiers("notnight"); ThemeManager.init(context)
        RuntimeEnvironment.setQualifiers("night"); ThemeManager.init(context)
        assertTrue(ThemeManager.isDarkTheme.value)
        RuntimeEnvironment.setQualifiers("notnight"); ThemeManager.init(context)
        assertFalse(ThemeManager.isDarkTheme.value)
    }
}
