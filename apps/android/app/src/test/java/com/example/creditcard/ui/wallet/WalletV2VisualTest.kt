package com.example.creditcard.ui.wallet

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.CreditCardTheme
import com.example.creditcard.ui.CardDetailScreen
import com.example.creditcard.ui.main.MainScreen
import com.example.creditcard.ui.main.SettingsMainPanel
import com.example.creditcard.utils.*
import java.io.File
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Synthetic fixtures only. PNGs are rendered by the same Compose code as the APK. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "zh-rCN-w393dp-h852dp-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WalletV2VisualTest {
    @get:Rule val compose = createAndroidComposeRule<ComponentActivity>()
    private val context get() = ApplicationProvider.getApplicationContext<Context>()
    private val banks = listOf("招商银行", "北京银行", "Capital One", "AMEX", "中国银行", "HSBC", "Revolut", "平安银行")
    private fun sample(i: Int) = SharedCard(id = "demo-$i", bank = banks[i % banks.size], alias = "示例卡 ${i + 1}",
        cardCategory = if (i % 3 == 0) "debit" else "credit", country = if (i % 8 == 2 || i % 8 == 3) "美国" else "中国",
        cardNumber = if (i % 8 == 3) "378282246310005" else "4111111111111111", cvv = "987", valid = "12/30",
        isQualified = "3", lastModifyTime = 200000L - i)

    private fun home(dark: Boolean = false, count: Int = 115, fontScale: Float = 1f) {
        context.getSharedPreferences(WalletPreferences.FILE, Context.MODE_PRIVATE).edit().clear().commit()
        context.getSharedPreferences("credit_card_sync_prefs", Context.MODE_PRIVATE).edit().clear().commit()
        DatabaseHelper(context).use { db -> repeat(count) { db.saveCard(sample(it)) } }
        ThemeManager.setThemeMode(context, if (dark) AppThemeMode.DARK else AppThemeMode.LIGHT)
        SecurityLockManager.init(context)
        SyncCoordinator.initLocalData(context)
        compose.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale)) {
                CreditCardTheme(dark) { MainScreen(onItemClick = {}) }
            }
        }
    }

    @Test fun compactLightHomeAndLongListRemainLazy() {
        home()
        compose.onNodeWithTag("wallet_header").assertIsDisplayed()
        val header = compose.onNodeWithTag("wallet_header").getUnclippedBoundsInRoot()
        assertTrue("Toolbar must not consume most of the phone", (header.bottom - header.top).value < 230f)
        compose.onNodeWithTag("wallet_card_demo-0").assertIsDisplayed()
        val instantiated = compose.onAllNodes(SemanticsMatcher("wallet card") {
            it.config.getOrNull(SemanticsProperties.TestTag)?.startsWith("wallet_card_demo-") == true
        }).fetchSemanticsNodes().size
        assertTrue("Only viewport and prefetch cards should be composed", instantiated < 24)
        capture("v2-home-cards-light")
        compose.onNode(hasScrollToIndexAction()).performScrollToNode(hasTestTag("wallet_card_demo-114"))
        compose.onNodeWithTag("wallet_card_demo-114").assertIsDisplayed()
        capture("v2-stack-last-card")
    }

    @Test fun darkHomeAndListModeAreBothLegible() {
        home(dark = true)
        capture("v2-home-cards-dark")
        compose.onNodeWithTag("wallet_mode_list").performClick()
        compose.onNodeWithTag("wallet_list_demo-0").assertIsDisplayed()
        capture("v2-home-list-dark")
    }

    @Test fun lightListAndEmptyFavoritesHaveNoDuplicateAddOverlay() {
        home()
        compose.onNodeWithTag("wallet_mode_list").performClick()
        capture("v2-home-list-light")
        compose.onNodeWithTag("wallet_favorites_filter").performScrollTo().performClick()
        compose.onNodeWithText("查看全部卡片").assertIsDisplayed()
        compose.onNodeWithText("新增信用卡").assertDoesNotExist()
        capture("v2-empty-starred")
        compose.onNodeWithText("查看全部卡片").performClick()
        compose.onNodeWithTag("wallet_list_demo-0").assertIsDisplayed()
    }

    @Test
    @Config(qualifiers = "zh-rCN-w320dp-h700dp-xhdpi")
    fun narrowPhoneWithLargeTextKeepsControlsReachable() {
        home(fontScale = 1.6f)
        compose.onNodeWithTag("wallet_mode_list").assertIsDisplayed().performClick()
        compose.onNodeWithTag("wallet_list_demo-0").assertIsDisplayed()
        capture("v2-small-large-font")
    }

    @Test fun detailUsesTheNewCardAndMaskedNumber() {
        DatabaseHelper(context).use { it.saveCard(sample(2)) }
        ThemeManager.setThemeMode(context, AppThemeMode.LIGHT)
        compose.setContent { CreditCardTheme(false) { CardDetailScreen("demo-2", {}, {}) } }
        compose.onNodeWithTag("wallet_detail_number").assertExists()
        compose.onNodeWithText(sample(2).cardNumber, substring = true).assertDoesNotExist()
        capture("v2-detail-light")
    }

    @Test
    @Config(qualifiers = "zh-rCN-w320dp-h700dp-xhdpi")
    fun nineteenDigitNumberDoesNotWrapAtLargeFont() {
        compose.setContent {
            CompositionLocalProvider(LocalDensity provides Density(2f, 1.6f)) {
                CreditCardTheme(false) {
                    Surface { Column(Modifier.width(288.dp).padding(16.dp)) {
                        WalletCardNumber("4000000000000000001", true, 0.7f, {}, {})
                    } }
                }
            }
        }
        val layouts = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag("wallet_detail_number").performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
        assertEquals(1, layouts.single().lineCount)
        assertFalse(layouts.single().hasVisualOverflow)
        capture("v2-number-19-digits-large-font")
    }

    @Test fun settingsHasCompactOverlayThemeSelection() {
        ThemeManager.setThemeMode(context, AppThemeMode.LIGHT)
        SecurityLockManager.init(context)
        compose.setContent { CreditCardTheme(false) {
            SettingsMainPanel(false, {}, {}, {}, {}, {}, {}, {})
        } }
        compose.onNodeWithTag("wallet_theme_LIGHT").assertIsSelected()
        val picker = compose.onNodeWithTag("wallet_theme_picker").getUnclippedBoundsInRoot()
        assertTrue((picker.bottom - picker.top).value < 100f)
        capture("v2-settings-light")
    }

    @Test fun configuredSyncAndEditorNeverShowAnOffSwitch() {
        // This only persists synthetic configuration. No connection button is pressed.
        SyncCoordinator.saveConfig(context, WebDAVConfig("https://example.invalid/dav", "demo", "not-a-real-password", "demo-key-12345", false))
        assertTrue(SyncCoordinator.loadConfig(context).isEnabled)
        compose.setContent { CreditCardTheme(false) { WalletSyncSettings({}) } }
        compose.onNodeWithText("配置完成后自动同步").assertExists()
        compose.onNodeWithText("开启双向自动同步").assertDoesNotExist()
        capture("v2-sync-status")
        compose.onNodeWithText("修改配置").performClick()
        compose.onNodeWithTag("sync_url").assertExists()
        capture("v2-sync-editor")
        compose.onNodeWithTag("sync_url").performTextReplacement("https://cancelled.invalid")
        compose.onNodeWithText("取消").performScrollTo().performClick()
        assertEquals("https://example.invalid/dav", SyncCoordinator.loadConfig(context).url)
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        compose.runOnIdle {
            val view = compose.activity.window.decorView
            val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
            view.draw(Canvas(bitmap))
            val folder = File("build/outputs/ui-review").apply { mkdirs() }
            File(folder, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            bitmap.recycle()
        }
    }
}
