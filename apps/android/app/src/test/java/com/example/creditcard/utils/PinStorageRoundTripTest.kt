package com.example.creditcard.utils

import android.content.Context
import android.content.ContextWrapper
import androidx.test.core.app.ApplicationProvider
import com.example.creditcard.data.CardSyncRecord
import com.example.creditcard.data.DatabaseHelper
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.decodeFromString
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.UUID
import javax.crypto.KeyGenerator

/** Isolated SQLite + synthetic AES key; real AndroidKeyStore has separate device tests. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [23, 34])
class PinStorageRoundTripTest {
    @Test fun pinUpgradeNeverRekeysOrRewritesTheWalletOrSyncState() = runBlocking {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val name = "pin-storage-${UUID.randomUUID()}"
        val securityContext = object : ContextWrapper(context) {
            override fun getApplicationContext(): Context = this
            override fun getSharedPreferences(key: String?, mode: Int) = context.getSharedPreferences("$name-$key", mode)
        }
        val preferences = securityContext.getSharedPreferences("credit_card_security_prefs", Context.MODE_PRIVATE)
        val sync = securityContext.getSharedPreferences("credit_card_sync_prefs", Context.MODE_PRIVATE)
        val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        val cipher = AesLocalRecordCipher { key }
        val input = checkNotNull(javaClass.classLoader?.getResourceAsStream("session-roundtrip.json"))
        val records = input.bufferedReader().use { AppJson.json.decodeFromString<List<CardSyncRecord>>(it.readText()) }
        val cards = records.mapNotNull { it.card }
        try {
            DatabaseHelper(context, cipher, "$name.db").use { db ->
                db.commitLocalChanges(records, cards, records.filter { it.state == "deleted" }.map { it.cardId }.toSet())
            }
            val before = context.getDatabasePath("$name.db").readBytes()
            sync.edit().putBoolean("pending", true).putString("snapshot", "synthetic.json").commit()
            val syncBefore = sync.all
            preferences.edit().putString("app_security_password_hash", "76eb14fe26d238c214b0f4ac405cfb0ee651fe0b21e972d1b0ea81211237c33a")
                .putBoolean("app_lock_state", true).commit()
            SecurityLockManager.init(securityContext)
            assertTrue(SecurityLockManager.verifyPassword(securityContext, "123456").success)
            assertFalse(preferences.contains("app_security_password_hash"))
            assertEquals(2, preferences.getInt("app_security_pin_version", 0))
            SecurityLockManager.lock(securityContext)
            assertTrue(SecurityLockManager.verifyPassword(securityContext, "123456").success)
            assertArrayEquals(before, context.getDatabasePath("$name.db").readBytes())
            assertEquals(syncBefore, sync.all)
            DatabaseHelper(context, cipher, "$name.db").use { db ->
                assertEquals(cards, db.getAllCards())
                assertEquals(records.sortedBy { it.cardId }, db.getAllSyncRecords().sortedBy { it.cardId })
                assertTrue(db.getAllCards().single().extraFields.isNotEmpty())
                assertTrue(db.getAllCards().single().cardImages.single().extraFields.isNotEmpty())
            }
        } finally {
            preferences.edit().clear().commit()
            sync.edit().clear().commit()
            SecurityLockManager.init(context)
            context.deleteDatabase("$name.db")
        }
    }
}
