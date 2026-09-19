package com.example.creditcard.ui

import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.example.creditcard.theme.CreditCardTheme
import com.example.creditcard.ui.security.LocalDataGate
import com.example.creditcard.utils.LocalCardLoadState
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "zh-rCN")
class LocalDataGateTest {
    @get:Rule val compose = createComposeRule()

    @Test fun loadingNeverShowsEmptyWalletAndRelockDestroysContent() {
        var phase by mutableStateOf(LocalCardLoadState.NOT_LOADED)
        compose.setContent {
            CreditCardTheme(darkTheme = false) {
                LocalDataGate(phase, {}) { Text("saved-card-content") }
            }
        }
        compose.onNodeWithTag("local_data_gate").assertIsDisplayed()
        compose.onNodeWithText("saved-card-content").assertDoesNotExist()
        compose.runOnIdle { phase = LocalCardLoadState.LOADING }
        compose.onNodeWithText("正在读取本机卡片…").assertIsDisplayed()
        compose.runOnIdle { phase = LocalCardLoadState.READY }
        compose.onNodeWithText("saved-card-content").assertIsDisplayed()
        compose.onNodeWithTag("local_data_gate").assertDoesNotExist()
        compose.runOnIdle { phase = LocalCardLoadState.NOT_LOADED }
        compose.onNodeWithText("saved-card-content").assertDoesNotExist()
    }

    @Test fun failedReadHasRetryInsteadOfEmptyWalletActions() {
        var retries = 0
        compose.setContent {
            CreditCardTheme(darkTheme = true) {
                LocalDataGate(LocalCardLoadState.FAILED, { retries++ }) { Text("empty-wallet") }
            }
        }
        compose.onNodeWithText("empty-wallet").assertDoesNotExist()
        compose.onNodeWithTag("local_data_retry").performClick()
        compose.runOnIdle { assertEquals(1, retries) }
    }
}
