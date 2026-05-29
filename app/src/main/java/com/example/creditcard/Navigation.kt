package com.example.creditcard

import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
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

    NavDisplay(
        backStack = backStack,
        onBack = { backStack.removeLastOrNull() },
        entryProvider = entryProvider {
            
            // 1. 卡包主界面路由
            entry<Main> {
                MainScreen(
                    onItemClick = { navKey -> backStack.add(navKey) },
                    modifier = Modifier.safeDrawingPadding()
                )
            }
            
            // 2. 卡片防窥详情界面路由
            entry<CardDetail> { key ->
                CardDetailScreen(
                    cardId = key.cardId,
                    onBack = { backStack.removeLastOrNull() },
                    onEdit = { id -> backStack.add(CardForm(id)) }
                )
            }
            
            // 3. 新建/修改信用卡表单路由
            entry<CardForm> { key ->
                CardFormScreen(
                    cardId = key.cardId,
                    onBack = { backStack.removeLastOrNull() },
                    onNavigateToDetail = { id -> backStack.add(CardDetail(id)) }
                )
            }
        }
    )
}
