package com.example.creditcard.ui.wallet

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.activity.ComponentActivity
import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import com.example.creditcard.CardForm
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.CreditCardTheme
import com.example.creditcard.ui.main.MainScreen
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
class WalletFeedbackTest {
    @get:Rule val compose = createAndroidComposeRule<ComponentActivity>()
    private val context get() = ApplicationProvider.getApplicationContext<Context>()
    private val card = SharedCard(id = "feedback", bank = "未收录测试机构", alias = "测试卡", cardNumber = "4111111111111111", isQualified = "3")
    private var addedCategory = ""
    private fun home(dark: Boolean = false) {
        context.getSharedPreferences("credit_card_sync_prefs", Context.MODE_PRIVATE).edit().clear().commit()
        context.getSharedPreferences(WalletPreferences.FILE, Context.MODE_PRIVATE).edit().clear().commit()
        ThemeManager.setThemeMode(context, if (dark) AppThemeMode.DARK else AppThemeMode.LIGHT)
        SecurityLockManager.init(context); SyncCoordinator.initLocalData(context)
        compose.setContent { CreditCardTheme(dark) { MainScreen(onItemClick = { if (it is CardForm) addedCategory = it.cardCategory }) } }
    }

    @Test fun emptyWalletOnlyOffersAnchoredFabAndBothCardCategories() {
        home(dark = true)
        compose.onNodeWithTag("wallet_add_fab").assertIsDisplayed()
        compose.onNodeWithTag("wallet_add_header").assertDoesNotExist()
        compose.onNode(hasText("添加卡片") and hasAnyAncestor(hasTestTag("wallet_empty"))).assertDoesNotExist()
        capture("feedback-empty-dark")
        compose.onNodeWithTag("wallet_add_fab").performClick()
        compose.onNodeWithTag("wallet_add_menu").assertIsDisplayed()
        capture("feedback-empty-add-menu")
        compose.onNodeWithText("新增信用卡").performClick()
        compose.runOnIdle { assertEquals("credit", addedCategory) }
        compose.onNodeWithTag("wallet_add_fab").performClick()
        compose.onNodeWithText("新增储蓄卡").performClick()
        compose.runOnIdle { assertEquals("debit", addedCategory) }
    }

    @Test fun firstCardAndLastDeletionSwitchTheAddLocation() {
        home()
        compose.onNodeWithTag("wallet_add_fab").assertIsDisplayed()
        compose.runOnIdle { SyncCoordinator.commitCardChanges(context, listOf(card)) }
        compose.onNodeWithTag("wallet_add_fab").assertDoesNotExist()
        compose.onNodeWithTag("wallet_add_header").assertIsDisplayed().performClick()
        compose.onNodeWithText("新增储蓄卡").performClick()
        compose.runOnIdle { assertEquals("debit", addedCategory) }
        compose.runOnIdle { SyncCoordinator.commitCardChanges(context, emptyList(), setOf(card.id)) }
        compose.onNodeWithTag("wallet_add_fab").assertIsDisplayed()
        compose.onNodeWithTag("wallet_add_header").assertDoesNotExist()
        capture("feedback-empty-light")
    }

    @Test fun filteredEmptyWalletKeepsHeaderAddAndResetAction() {
        home()
        compose.runOnIdle { SyncCoordinator.commitCardChanges(context, listOf(card)) }
        compose.onNodeWithTag("wallet_favorites_filter").performClick()
        compose.onNodeWithTag("wallet_add_fab").assertDoesNotExist()
        compose.onNodeWithTag("wallet_add_header").assertIsDisplayed()
        compose.onNodeWithText("查看全部卡片").assertIsDisplayed().performClick()
        compose.onNodeWithTag("wallet_card_feedback").assertIsDisplayed()
    }

    @Test fun unknownIssuerUsesGenericCardInBothModes() {
        home()
        compose.runOnIdle { SyncCoordinator.commitCardChanges(context, listOf(card)) }
        compose.onNodeWithTag("wallet_bank_fallback", useUnmergedTree = true).assertIsDisplayed()
        compose.onNodeWithText("未收").assertDoesNotExist()
        compose.onNodeWithText("CW").assertDoesNotExist()
        capture("feedback-generic-card")
        compose.onNodeWithTag("wallet_mode_list").performClick()
        compose.onNodeWithTag("wallet_bank_fallback", useUnmergedTree = true).assertIsDisplayed()
        compose.onNodeWithText("未收").assertDoesNotExist()
        capture("feedback-generic-list")
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        compose.runOnIdle {
            val view = compose.activity.window.decorView
            val image = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
            view.draw(Canvas(image))
            val folder = File("build/outputs/ui-review").apply { mkdirs() }
            File(folder, "$name.png").outputStream().use { image.compress(Bitmap.CompressFormat.PNG, 100, it) }
            image.recycle()
        }
    }
}
