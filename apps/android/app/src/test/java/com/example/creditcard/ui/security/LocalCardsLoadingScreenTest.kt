package com.example.creditcard.ui.security

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.example.creditcard.theme.CreditCardTheme
import com.example.creditcard.utils.LocalCardLoadState
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "en")
class LocalCardsLoadingScreenTest {
    @get:Rule val compose = createComposeRule()

    @Test fun loadingShowsProgressInsteadOfEmptyWalletActions() {
        compose.setContent {
            CreditCardTheme(darkTheme = false) {
                LocalCardsLoadingScreen(LocalCardLoadState.LOADING) {}
            }
        }
        compose.onNodeWithText("Loading cards from this device…").assertIsDisplayed()
        compose.onNodeWithText("Add card").assertDoesNotExist()
        compose.onNodeWithText("Try again").assertDoesNotExist()
    }

    @Test fun failedReadPreservesDataAndOffersRetryInDarkTheme() {
        var retries = 0
        compose.setContent {
            CreditCardTheme(darkTheme = true) {
                LocalCardsLoadingScreen(LocalCardLoadState.ERROR) { retries++ }
            }
        }
        compose.onNodeWithText("Cards could not be loaded. Your saved data is unchanged. Please try again.").assertIsDisplayed()
        compose.onNodeWithText("Try again").performClick()
        compose.runOnIdle { assertEquals(1, retries) }
    }
}
