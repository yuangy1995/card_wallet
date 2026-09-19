package com.example.creditcard.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.example.creditcard.CardDetail
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.CreditCardTheme
import com.example.creditcard.ui.components.WalletSection
import com.example.creditcard.ui.main.CreditCardTile
import com.example.creditcard.ui.main.MainScreen
import com.example.creditcard.ui.main.SettingsMainPanel
import com.example.creditcard.ui.main.ToolsPanel
import com.example.creditcard.ui.update.LocalAppUpdater
import com.example.creditcard.ui.update.UpdateSettingsPanel
import com.example.creditcard.update.AppUpdater
import android.app.Application
import com.example.creditcard.utils.AppThemeMode
import com.example.creditcard.utils.SecurityLockManager
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager
import java.io.File
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "zh-rCN-w393dp-h852dp-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WalletUiTest {
    @get:Rule val compose = createAndroidComposeRule<ComponentActivity>()
    private val sample = SharedCard(id = "sample", bank = "招商银行", alias = "日常用卡",
        cardNumber = "6225888888881234", type = "CNY", limit = 50000.0, valid = "12/30",
        accountBillDate = "10", dueDate = "28", isQualified = "3")

    @Test fun lightHomePreservesSearchAndCardNavigation() = home(dark = false)
    @Test fun darkHomePreservesSearchAndCardNavigation() = home(dark = true)

    @Test
    @Config(qualifiers = "zh-rCN-w960dp-h600dp-land-xhdpi")
    fun landscapeHomePreservesNavigation() = home(dark = false, imageName = "wallet-landscape")

    private fun home(dark: Boolean, imageName: String = if (dark) "wallet-dark" else "wallet-light") {
        val context = ApplicationProvider.getApplicationContext<Context>()
        DatabaseHelper(context).use {
            it.saveCard(sample)
            it.saveCard(sample.copy(id = "second", bank = "中国银行", alias = "旅行备用", cardNumber = "6217000012345678",
                cardCategory = "debit", type = "USD"))
        }
        ThemeManager.setThemeMode(context, if (dark) AppThemeMode.DARK else AppThemeMode.LIGHT)
        SecurityLockManager.init(context)
        SyncCoordinator.initLocalData(context)
        // MainActivity mounts MainScreen only after READY; the fixture uses the same gate.
        compose.waitUntil(timeoutMillis = 10_000) {
            SyncCoordinator.localDataState.value == com.example.creditcard.utils.LocalCardLoadState.READY
        }
        var opened: String? = null
        compose.setContent {
            CreditCardTheme(dark) {
                MainScreen(onItemClick = { if (it is CardDetail) opened = it.cardId })
            }
        }
        compose.onNodeWithText("我的卡包").assertIsDisplayed()
        compose.onNodeWithText(sample.cardNumber).assertDoesNotExist()
        capture(imageName)
        compose.onNode(hasSetTextAction()).performTextInput("1234")
        compose.onNode(hasScrollToIndexAction()).performScrollToNode(hasText("日常用卡"))
        compose.onNodeWithText("日常用卡").assertIsDisplayed().performClick()
        compose.runOnIdle { assertEquals("sample", opened) }
        compose.onNodeWithText("工具").performClick()
        compose.onNodeWithText("统计分析").assertIsDisplayed()
        compose.onNodeWithText("卡包").performClick()
        compose.onNodeWithText("日常用卡").assertIsDisplayed()
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(0)
        compose.onNode(hasSetTextAction()).assertTextContains("1234")
    }

    @Test fun settingsRetainsAllDestinationsAndAppearance() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        SecurityLockManager.init(context)
        ThemeManager.setThemeMode(context, AppThemeMode.LIGHT)
        var opened = ""
        compose.setContent {
            CreditCardTheme(false) {
                SettingsMainPanel(false, { opened = "sync" }, { opened = "security" }, { opened = "help" },
                    { opened = "about" }, { opened = "privacy" }, { opened = "storage" }, { opened = "updates" })
            }
        }
        compose.onNodeWithText("外观").assertIsDisplayed()
        capture("settings-light")
        listOf("云同步" to "sync", "安全锁" to "security", "存储管理" to "storage", "隐私与权限" to "privacy",
            "软件更新" to "updates", "使用帮助" to "help", "关于卡包" to "about").forEach { (text, destination) ->
            compose.onNodeWithText(text).performScrollTo().performClick()
            compose.runOnIdle { assertEquals(destination, opened) }
        }
    }

    @Test fun toolDestinationsRemainAvailable() {
        var opened = ""
        compose.setContent {
            CreditCardTheme(false) {
                ToolsPanel(listOf(sample), false, { opened = "stats" }, { opened = "verify" },
                    { opened = "history" }, { opened = "usage" }, { opened = "diagnostics" })
            }
        }
        capture("tools-light")
        listOf("统计分析" to "stats", "快速验卡" to "verify", "优惠用卡" to "usage",
            "资料检查" to "diagnostics", "同步记录" to "history").forEach { (text, destination) ->
            compose.onNodeWithText(text).performScrollTo().performClick()
            compose.runOnIdle { assertEquals(destination, opened) }
        }
    }

    @Test fun updatePreferenceIsVisibleAndPersistent() {
        val app = ApplicationProvider.getApplicationContext<Application>()
        val updater = AppUpdater(app)
        compose.setContent {
            CompositionLocalProvider(LocalAppUpdater provides updater) {
                CreditCardTheme(false) { UpdateSettingsPanel({}) }
            }
        }
        compose.onNodeWithText("检查更新").assertIsDisplayed()
        capture("updates-light")
        compose.onNode(isToggleable()).performClick()
        compose.runOnIdle {
            assertFalse(updater.state.value.automatic)
            assertFalse(AppUpdater(app).state.value.automatic)
        }
    }

    @Test fun sectionsExpandAndRemainUsableAtLargeFontSize() {
        compose.setContent {
            CompositionLocalProvider(LocalDensity provides Density(2f, 1.6f)) {
                CreditCardTheme(false) {
                    var expanded by remember { mutableStateOf(false) }
                    Column(Modifier.width(320.dp)) {
                        WalletSection("基本信息", expanded, { expanded = it }) { Text("卡片资料") }
                        CreditCardTile(sample, false, selectionMode = true, selected = true, onClick = {})
                    }
                }
            }
        }
        compose.onNodeWithText("卡片资料").assertDoesNotExist()
        compose.onNodeWithText("基本信息").performClick()
        compose.onNodeWithText("卡片资料").assertIsDisplayed()
        compose.onNodeWithContentDescription("已选择").assertIsDisplayed()
        capture("wallet-large-text")
    }

    private fun capture(name: String) {
        compose.runOnIdle {
            val view = compose.activity.window.decorView
            val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
            view.draw(Canvas(bitmap))
            val directory = File("build/outputs/ui-review").apply { mkdirs() }
            File(directory, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            bitmap.recycle()
        }
    }
}
