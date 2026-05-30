package com.example.creditcard

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.navigation3.runtime.entryProvider
import androidx.navigation3.runtime.rememberNavBackStack
import androidx.navigation3.ui.NavDisplay
import com.example.creditcard.ui.CardDetailScreen
import com.example.creditcard.ui.CardFormScreen
import com.example.creditcard.ui.main.MainScreen

/**
 * Android 原生 App 全局路由导航控制器
 * 基于 Google 官方最新的 AndroidX Navigation3 打造，实现高效的页面解耦与路由跳转
 */
@Composable
fun MainNavigation() {
    val backStack = rememberNavBackStack(Main)
    val popBackStack = {
        if (backStack.size > 1) {
            backStack.removeLastOrNull()
        }
    }

    // 系统全面屏返回手势优先回退应用内导航栈，避免直接结束 Activity。
    BackHandler(enabled = backStack.size > 1) {
        popBackStack()
    }

    NavDisplay(
        backStack = backStack,
        onBack = popBackStack,
        entryProvider = entryProvider {
            
            // 1. 卡包主界面路由
            entry<Main> {
                MainScreen(
                    onItemClick = { navKey -> backStack.add(navKey) }
                )
            }
            
            // 2. 卡片防窥详情界面路由
            entry<CardDetail> { key ->
                CardDetailScreen(
                    cardId = key.cardId,
                    onBack = popBackStack,
                    onEdit = { id -> backStack.add(CardForm(id)) }
                )
            }
            
            // 3. 新建/修改信用卡表单路由
            entry<CardForm> { key ->
                CardFormScreen(
                    cardId = key.cardId,
                    prefillCardNumber = key.prefillCardNumber,
                    prefillValid = key.prefillValid,
                    onBack = popBackStack,
                    onNavigateToDetail = { id -> backStack.add(CardDetail(id)) }
                )
            }
        }
    )
}
