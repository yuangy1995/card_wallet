package com.example.creditcard.ui

import android.content.Context
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.CreditCardTheme
import com.example.creditcard.ui.main.MainScreen
import com.example.creditcard.utils.AppThemeMode
import com.example.creditcard.utils.LocalCardLoadState
import com.example.creditcard.utils.SecurityLockManager
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "zh-rCN-w393dp-h852dp-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class StartupConfigUiTest {
    @get:Rule val compose = createAndroidComposeRule<ComponentActivity>()

    @Test fun homeAndSettingsDoNotDecryptBrokenCloudCredentialsDuringComposition() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val prefs = context.getSharedPreferences("credit_card_sync_prefs", Context.MODE_PRIVATE)
        val unreadable = "local-secret-v1:not-valid-base64"
        prefs.edit().putString("webdav_pass", unreadable).commit()
        val card = SharedCard(id = "startup-ui", bank = "SyntheticBank", alias = "本机测试卡片",
            cardNumber = "4111111111111111", isQualified = "3")
        DatabaseHelper(context).use { it.saveCard(card) }
        ThemeManager.setThemeMode(context, AppThemeMode.LIGHT)
        SecurityLockManager.init(context)
        SyncCoordinator.initLocalData(context)
        assertEquals(LocalCardLoadState.READY, SyncCoordinator.localDataState.value)
        assertEquals(listOf(card.id), SyncCoordinator.cardsFlow.value.map { it.id })
        compose.setContent {
            CreditCardTheme(false) { MainScreen(onItemClick = {}) }
        }
        compose.onNodeWithText("我的卡包").assertIsDisplayed()
        compose.onNode(hasScrollToIndexAction()).performScrollToNode(hasText(card.alias))
        compose.onNodeWithText(card.alias).assertIsDisplayed()
        compose.onNodeWithText("设置").performClick()
        compose.onNodeWithText("外观").assertIsDisplayed()
        compose.runOnIdle { assertEquals(unreadable, prefs.getString("webdav_pass", null)) }
    }
}
