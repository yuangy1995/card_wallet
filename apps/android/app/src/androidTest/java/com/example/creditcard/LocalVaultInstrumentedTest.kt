package com.example.creditcard

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import android.content.Context
import com.example.creditcard.utils.AndroidLocalDataCipher
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.data.CardImageAsset
import kotlinx.serialization.json.JsonPrimitive
import java.security.KeyStore
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LocalVaultInstrumentedTest {
    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    @Test fun realAndroidKeyStoreAndLargeDatabaseRoundTrip() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val alias = "wallet_instrumented_${UUID.randomUUID()}"
        val name = "$alias.db"
        try {
            val cipher = AndroidLocalDataCipher(context, alias)
            val input = "synthetic-only".toByteArray()
            val encrypted = cipher.seal(input, "fixture")
            assertArrayEquals(input, cipher.open(encrypted, "fixture"))
            assertNull("Key must not be exportable", keyStore().getKey(alias, null).encoded)
            val card = SharedCard(id="fixture", bank="SyntheticBank", cardImages=listOf(CardImageAsset(id="image", data="A".repeat(2_200_000), extraFields=mapOf("futureImage" to JsonPrimitive("kept")))), extraFields=mapOf("future" to JsonPrimitive("kept")))
            DatabaseHelper(context, cipher, name).use { it.saveCard(card); assertEquals(card, it.getAllCards().single()) }
            DatabaseHelper(context, AndroidLocalDataCipher(context, alias), name).use { assertEquals(card, it.getCardById(card.id)) }
        } finally {
            context.deleteDatabase(name)
            keyStore().deleteEntry(alias)
            java.io.File(context.filesDir, "$alias.marker").delete()
        }
    }

    @Test fun rejectsModifiedCiphertextAndWrongRecordPurpose() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val alias = "wallet_tamper_${UUID.randomUUID()}"
        try {
            val cipher = AndroidLocalDataCipher(context, alias)
            val plaintext = "synthetic-private-record".toByteArray()
            val encrypted = cipher.seal(plaintext, "cards:fixture:0")
            val modified = encrypted.copyOf().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() }
            assertTrue(runCatching { cipher.open(modified, "cards:fixture:0") }.isFailure)
            assertTrue(runCatching { cipher.open(encrypted, "cards:other:0") }.isFailure)
            assertArrayEquals(plaintext, cipher.open(encrypted, "cards:fixture:0"))
        } finally {
            keyStore().deleteEntry(alias)
            java.io.File(context.filesDir, "$alias.marker").delete()
        }
    }

    @Test fun reusedKeyHandleStillEnforcesDeletionAndPurpose() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val alias = "wallet_cached_handle_${UUID.randomUUID()}"
        try {
            val cipher = AndroidLocalDataCipher(context, alias)
            val plaintext = "synthetic".toByteArray()
            val encrypted = cipher.seal(plaintext, "record")
            repeat(115) { assertArrayEquals(plaintext, cipher.open(encrypted, "record")) }
            assertNull(keyStore().getKey(alias, null).encoded)
            assertTrue(runCatching { cipher.open(encrypted, "different-record") }.isFailure)
            keyStore().deleteEntry(alias)
            assertTrue(runCatching { cipher.open(encrypted, "record") }.isFailure)
            assertTrue(runCatching { cipher.seal(plaintext, "record") }.isFailure)
            assertFalse(keyStore().containsAlias(alias))
        } finally {
            keyStore().deleteEntry(alias)
            java.io.File(context.filesDir, "$alias.marker").delete()
        }
    }

    @Test fun missingExistingKeyNeverSilentlyCreatesReplacement() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val alias = "wallet_missing_key_${UUID.randomUUID()}"
        try {
            val original = AndroidLocalDataCipher(context, alias).seal("fixture".toByteArray(), "record")
            keyStore().deleteEntry(alias)
            val reopened = AndroidLocalDataCipher(context, alias)
            assertThrows(IllegalStateException::class.java) { reopened.open(original, "record") }
            assertThrows(IllegalStateException::class.java) { reopened.seal("replacement".toByteArray(), "record") }
            assertFalse(keyStore().containsAlias(alias))
            assertTrue(java.io.File(context.filesDir, "$alias.marker").exists())
        } finally {
            keyStore().deleteEntry(alias)
            java.io.File(context.filesDir, "$alias.marker").delete()
        }
    }
}
