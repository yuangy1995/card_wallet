package com.example.creditcard

import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

/**
 * 路由导航 Key 定义
 */
@Serializable data object Main : NavKey

@Serializable data class CardDetail(val cardId: String) : NavKey

@Serializable data class CardForm(val cardId: String? = null) : NavKey
