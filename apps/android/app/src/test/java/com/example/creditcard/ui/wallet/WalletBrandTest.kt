package com.example.creditcard.ui.wallet

import org.junit.Assert.*
import org.junit.Test

class WalletBrandTest {
    @Test fun matchesChineseTraditionalAndEnglishBanks() {
        assertEquals(WalletBank.CMB, WalletBank.fromName("招商银行"))
        assertEquals(WalletBank.CMB, WalletBank.fromName("China Merchants Bank"))
        assertEquals(WalletBank.BOC, WalletBank.fromName("中國銀行（香港）"))
        assertEquals(WalletBank.BOCOM, WalletBank.fromName("Bank of Communications"))
        assertEquals(WalletBank.ICBC, WalletBank.fromName("ICBC"))
        assertEquals(WalletBank.HSBC, WalletBank.fromName("HSBC UK"))
        assertEquals(WalletBank.AMEX, WalletBank.fromName("American Express"))
    }

    @Test fun unknownBanksDoNotPickAnUnrelatedLogo() {
        assertEquals(WalletBank.UNKNOWN, WalletBank.fromName(""))
        assertEquals(WalletBank.UNKNOWN, WalletBank.fromName("Bank of Montreal"))
        assertEquals(WalletBank.UNKNOWN, WalletBank.fromName("ABCXYZ"))
        assertEquals(WalletBank.BOCOM, WalletBank.fromName("交通银行"))
    }

    @Test fun recognizesMainCardNetworksLocally() {
        assertEquals(WalletNetwork.VISA, WalletNetwork.fromNumber("4111 1111 1111 1111"))
        assertEquals(WalletNetwork.MASTERCARD, WalletNetwork.fromNumber("5555-5555-5555-4444"))
        assertEquals(WalletNetwork.AMEX, WalletNetwork.fromNumber("378282246310005"))
        assertEquals(WalletNetwork.JCB, WalletNetwork.fromNumber("3530111333300000"))
        assertEquals(WalletNetwork.UNIONPAY, WalletNetwork.fromNumber("6217000000000000"))
        assertEquals(WalletNetwork.DISCOVER, WalletNetwork.fromNumber("6011111111111117"))
        assertEquals(WalletNetwork.DINERS, WalletNetwork.fromNumber("30569309025904"))
    }

    @Test fun mastercardTwoSeriesBoundariesAreInclusive() {
        assertEquals(WalletNetwork.UNKNOWN, WalletNetwork.fromNumber("2220000000000000"))
        assertEquals(WalletNetwork.MASTERCARD, WalletNetwork.fromNumber("2221000000000000"))
        assertEquals(WalletNetwork.MASTERCARD, WalletNetwork.fromNumber("2720000000000000"))
        assertEquals(WalletNetwork.UNKNOWN, WalletNetwork.fromNumber("2721000000000000"))
    }

    @Test fun ambiguousOrPartialNumbersUseGenericMark() {
        listOf("", "4", "4111", "**** 4242", "1234567890123456").forEach {
            assertEquals(WalletNetwork.UNKNOWN, WalletNetwork.fromNumber(it))
        }
    }

    @Test fun exposesOnlyLastFourDigits() {
        assertEquals("1111", walletLastFour("4111 1111 1111 1111"))
        assertEquals("----", walletLastFour("123"))
        assertEquals("----", walletLastFour(""))
    }
}
