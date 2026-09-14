package com.example.creditcard.ui.wallet

import org.junit.Assert.assertEquals
import org.junit.Test

class WalletBrandRegressionTest {
    @Test fun fullIssuerNameBeatsSharedBankOfChinaSuffix() {
        assertEquals(WalletBank.ICBC, WalletBank.fromName("Industrial and Commercial Bank of China"))
        assertEquals(WalletBank.ABC, WalletBank.fromName("Agricultural Bank of China"))
        assertEquals(WalletBank.BOC, WalletBank.fromName("Bank of China (Hong Kong)"))
    }

    @Test fun shortEnglishNamesRequireWholeWords() {
        assertEquals(WalletBank.UNKNOWN, WalletBank.fromName("Citizens Bank"))
        assertEquals(WalletBank.UNKNOWN, WalletBank.fromName("ABCXYZ"))
        assertEquals(WalletBank.CITI, WalletBank.fromName("Citi US"))
        assertEquals(WalletBank.HSBC, WalletBank.fromName("HSBC UK"))
        assertEquals(WalletBank.DBS, WalletBank.fromName("DBS Singapore"))
    }

    @Test fun sharedAcceptanceDoesNotRelabelUnionPayAsDiscover() {
        assertEquals(WalletNetwork.UNIONPAY, WalletNetwork.fromNumber("6222020000000000"))
        assertEquals(WalletNetwork.UNIONPAY, WalletNetwork.fromNumber("6229250000000000000"))
        assertEquals(WalletNetwork.DISCOVER, WalletNetwork.fromNumber("6011111111111117"))
    }
}
