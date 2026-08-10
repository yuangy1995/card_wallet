package com.example.creditcard.utils

import android.content.Context
import android.content.res.Configuration
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class AppThemeMode {
    SYSTEM, LIGHT, DARK
}

/**
 * 全局深浅色主题切换持久化管理器
 */
object ThemeManager {
    
    private val _themeMode = MutableStateFlow(AppThemeMode.DARK)
    val themeMode: StateFlow<AppThemeMode> = _themeMode

    private val _isDarkTheme = MutableStateFlow(true)
    val isDarkTheme: StateFlow<Boolean> = _isDarkTheme

    /**
     * 初始化加载用户存储的主题偏好
     */
    fun init(context: Context) {
        val prefs = context.getSharedPreferences("credit_card_theme_prefs", Context.MODE_PRIVATE)
        val modeStr = prefs.getString("theme_mode", AppThemeMode.DARK.name) ?: AppThemeMode.DARK.name
        val mode = try { AppThemeMode.valueOf(modeStr) } catch (e: Exception) { AppThemeMode.DARK }
        _themeMode.value = mode
        updateIsDark(context, mode)
    }

    /**
     * 设置具体的主题模式
     */
    fun setThemeMode(context: Context, mode: AppThemeMode) {
        _themeMode.value = mode
        updateIsDark(context, mode)
        
        val prefs = context.getSharedPreferences("credit_card_theme_prefs", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("theme_mode", mode.name)
            .putBoolean("is_dark_theme", _isDarkTheme.value)
            .apply()
    }

    /**
     * 轮转切换深浅色主题，并持久化写入 SharedPreferences
     */
    fun toggleTheme(context: Context) {
        val nextMode = when (_themeMode.value) {
            AppThemeMode.DARK -> AppThemeMode.LIGHT
            AppThemeMode.LIGHT -> AppThemeMode.SYSTEM
            AppThemeMode.SYSTEM -> AppThemeMode.DARK
        }
        setThemeMode(context, nextMode)
    }

    private fun updateIsDark(context: Context, mode: AppThemeMode) {
        _isDarkTheme.value = when (mode) {
            AppThemeMode.DARK -> true
            AppThemeMode.LIGHT -> false
            AppThemeMode.SYSTEM -> {
                val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                nightMode == Configuration.UI_MODE_NIGHT_YES
            }
        }
    }

    fun resetToDefault(context: Context) {
        setThemeMode(context, AppThemeMode.DARK)
    }
}
