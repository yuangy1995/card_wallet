package com.example.creditcard.ui.wallet

import com.example.creditcard.ui.main.getCardBrand
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class BrandingContractTest {
    private fun fixtures(): JsonObject {
        val stream = checkNotNull(javaClass.classLoader?.getResourceAsStream("branding.json"))
        return stream.bufferedReader().use { Json.parseToJsonElement(it.readText()).jsonObject }
    }
    @Test fun sharedNetworkHintsAndBoundaries() {
        fixtures().getValue("networks").jsonArray.forEach { value ->
            val item = value.jsonObject
            val number = item.getValue("number").jsonPrimitive.content
            val level = item.getValue("level").jsonPrimitive.content
            val expected = item.getValue("expected").jsonPrimitive.content
            val result = WalletNetwork.fromCard(number, level)
            assertEquals("$number / $level", expected, result.code)
            assertEquals(if (result == WalletNetwork.AMEX) "Amex" else if (result == WalletNetwork.UNKNOWN) "Unknown" else result.label,
                getCardBrand(number, level))
        }
    }
    @Test fun sharedIssuerAliasesAndUnknownFallback() {
        fixtures().getValue("issuers").jsonArray.forEach { value ->
            val item = value.jsonObject
            val name = item.getValue("name").jsonPrimitive.content
            val country = item.getValue("country").jsonPrimitive.content
            val expected = item.getValue("expected").jsonPrimitive.contentOrNull
            assertEquals(name, expected, WalletLogoCatalog.match(name, country)?.id)
        }
        assertEquals("societe", WalletLogoCatalog.normalized("ＳＯＣＩÉＴÉ"))
        assertNotEquals("citibank", WalletLogoCatalog.match("Citizens Bank")?.id)
        for (index in 0 until 300) assertNull(WalletLogoCatalog.match("不存在的测试银行-$index"))
        assertEquals("hsbc", WalletLogoCatalog.match("HSBC")?.id)
    }
}
