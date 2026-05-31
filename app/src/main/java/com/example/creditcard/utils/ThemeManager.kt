package com.example.creditcard.utils

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * 全局深浅色主题切换持久化管理器
 */
object ThemeManager {
    
    private val _isDarkTheme = MutableStateFlow(true) // 默认开启高质感科技暗黑风
    val isDarkTheme: StateFlow<Boolean> = _isDarkTheme

    /**
     * 初始化加载用户存储的主题偏好
     */
    fun init(context: Context) {
        val prefs = context.getSharedPreferences("credit_card_theme_prefs", Context.MODE_PRIVATE)
        _isDarkTheme.value = prefs.getBoolean("is_dark_theme", true)
    }

    /**
     * 轮转切换深浅色主题，并持久化写入 SharedPreferences
     */
    fun toggleTheme(context: Context) {
        val nextState = !_isDarkTheme.value
        _isDarkTheme.value = nextState
        
        val prefs = context.getSharedPreferences("credit_card_theme_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("is_dark_theme", nextState).apply()
    }

    fun resetToDefault(context: Context) {
        _isDarkTheme.value = true
        context.getSharedPreferences("credit_card_theme_prefs", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }
}
