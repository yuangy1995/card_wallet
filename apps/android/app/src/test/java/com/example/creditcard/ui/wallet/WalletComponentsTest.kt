package com.example.creditcard.ui.wallet

import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.CreditCardTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "en")
class WalletComponentsTest {
    @get:Rule val compose = createComposeRule()
    private val sample = SharedCard(
        id = "sample", bank = "招商银行", alias = "Everyday card",
        cardNumber = "4111111111111111", cvv = "987", valid = "12/29"
    )

    @Test fun switchesBetweenCardAndListModes() {
        var isList by mutableStateOf(false)
        compose.setContent {
            CreditCardTheme(darkTheme = false) {
                WalletViewControls(isList, { isList = it }, false, 1, {})
            }
        }
        compose.onNodeWithTag("wallet_mode_cards").assertIsSelected()
        compose.onNodeWithTag("wallet_mode_list").performClick().assertIsSelected()
        compose.runOnIdle { assertTrue(isList) }
        compose.onNodeWithTag("wallet_mode_cards").performClick().assertIsSelected()
        compose.runOnIdle { assertFalse(isList) }
    }

    @Test fun favoritesFilterIsIndependentlyToggleable() {
        var onlyFavorites by mutableStateOf(false)
        compose.setContent {
            CreditCardTheme(darkTheme = false) {
                WalletViewControls(false, {}, onlyFavorites, 1, { onlyFavorites = it })
            }
        }
        compose.onNodeWithTag("wallet_favorites_filter").performClick()
        compose.runOnIdle { assertTrue(onlyFavorites) }
        compose.onNodeWithTag("wallet_favorites_filter").performClick()
        compose.runOnIdle { assertFalse(onlyFavorites) }
    }

    @Test fun starringCardDoesNotOpenDetailsOrExposeSensitiveData() {
        var starred by mutableStateOf(false)
        var openCount = 0
        compose.setContent {
            CreditCardTheme(darkTheme = false) {
                WalletCardFace(sample, starred, { starred = !starred }, collapsed = true) { openCount++ }
            }
        }
        compose.onNodeWithContentDescription("Star Everyday card").performClick()
        compose.onNodeWithContentDescription("Unstar Everyday card").assertExists()
        compose.onNodeWithText(sample.cardNumber, substring = true).assertDoesNotExist()
        compose.onNodeWithText(sample.cvv, substring = true).assertDoesNotExist()
        compose.runOnIdle { assertTrue(starred); assertEquals(0, openCount) }
        compose.onNodeWithTag("wallet_card_sample").performClick()
        compose.runOnIdle { assertEquals(1, openCount) }
    }

    @Test fun listModeHasTheSameStarActionInDarkTheme() {
        var starred by mutableStateOf(false)
        var openCount = 0
        compose.setContent {
            CreditCardTheme(darkTheme = true) {
                WalletListRow(sample, starred, { starred = !starred }) { openCount++ }
            }
        }
        compose.onNodeWithContentDescription("Star Everyday card").performClick()
        compose.onNodeWithContentDescription("Unstar Everyday card").assertExists()
        compose.runOnIdle { assertEquals(0, openCount) }
        compose.onNodeWithText(sample.cardNumber, substring = true).assertDoesNotExist()
    }

    @Test fun batchSelectionDoesNotOfferAConflictingStarAction() {
        compose.setContent {
            CreditCardTheme(darkTheme = false) {
                WalletListRow(sample, false, {}, selectionMode = true, selected = true) {}
            }
        }
        compose.onNodeWithTag("wallet_list_sample").assertIsSelected()
        compose.onNodeWithContentDescription("Star Everyday card").assertDoesNotExist()
    }
}
