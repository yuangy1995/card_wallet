package com.example.creditcard

import android.content.Context
import android.content.ContextWrapper
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.utils.*
import java.io.File
import java.util.UUID
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class UnlockStartupInstrumentedTest {
    private class IsolatedContext(base: Context) : ContextWrapper(base) {
        private val prefix = "unlock_test_${UUID.randomUUID()}_"
        override fun getApplicationContext(): Context = this
        override fun getDatabasePath(name: String): File = super.getDatabasePath(prefix + name)
        override fun getFilesDir(): File = File(super.getFilesDir(), prefix).apply { mkdirs() }
        override fun getSharedPreferences(name: String, mode: Int) =
            super.getSharedPreferences(prefix + name, mode)
        // SQLiteOpenHelper opens through Context; give it the same isolated path.
        override fun openOrCreateDatabase(name: String, mode: Int, factory: android.database.sqlite.SQLiteDatabase.CursorFactory?) =
            super.openOrCreateDatabase(prefix + name, mode, factory)
        override fun openOrCreateDatabase(name: String, mode: Int, factory: android.database.sqlite.SQLiteDatabase.CursorFactory?,
            errorHandler: android.database.DatabaseErrorHandler?) =
            super.openOrCreateDatabase(prefix + name, mode, factory, errorHandler)
        override fun deleteDatabase(name: String): Boolean = super.deleteDatabase(prefix + name)
    }

    @Test fun unlockedLocalCardsAppearDespiteUnreadableHistoryAndCloudCredentials() = runBlocking {
        val context = IsolatedContext(ApplicationProvider.getApplicationContext())
        val expected = (1..115).map { SharedCard(id = "synthetic-$it", bank = "SyntheticBank", alias = "Card $it") }
        try {
            SecurityLockManager.clearSecurityData(context)
            SyncCoordinator.setSuspended(context, true)
            DatabaseHelper(context).use { it.saveCards(expected) }
            val prefs = context.getSharedPreferences("credit_card_sync_prefs", Context.MODE_PRIVATE)
            val unreadable = "local-secret-v1:not-valid-base64"
            prefs.edit().putString("sync_history", unreadable)
                .putString("webdav_pass", unreadable).commit()
            assertTrue(SecurityLockManager.setPassword(context, "135790").success)
            SecurityLockManager.lock(context)
            SyncCoordinator.setSuspended(context, true)
            assertTrue(SyncCoordinator.cardsFlow.value.isEmpty())
            assertEquals(LocalCardLoadState.NOT_LOADED, SyncCoordinator.localDataState.value)
            assertTrue(SecurityLockManager.verifyPassword(context, "135790").success)
            SyncCoordinator.setSuspended(context, false)
            withTimeout(30_000) {
                SyncCoordinator.localDataState.first { it == LocalCardLoadState.READY }
                SyncCoordinator.syncStatus.first { it.message == context.getString(R.string.local_cards_sync_config_unavailable) }
            }
            assertEquals(expected.map { it.id }.toSet(), SyncCoordinator.cardsFlow.value.map { it.id }.toSet())
            assertEquals(LocalCardLoadState.READY, SyncCoordinator.localDataState.value)
            assertEquals(unreadable, prefs.getString("webdav_pass", null))
            assertEquals(unreadable, prefs.getString("sync_history", null))

            // Same process, second lock/unlock: no cloud account is available to refill the cards.
            SecurityLockManager.lock(context)
            SyncCoordinator.setSuspended(context, true)
            assertTrue(SyncCoordinator.cardsFlow.value.isEmpty())
            assertTrue(SecurityLockManager.verifyPassword(context, "135790").success)
            SyncCoordinator.setSuspended(context, false)
            withTimeout(30_000) { SyncCoordinator.localDataState.first { it == LocalCardLoadState.READY } }
            assertEquals(115, SyncCoordinator.cardsFlow.value.size)
        } finally {
            SyncCoordinator.setSuspended(context, true)
            SecurityLockManager.clearSecurityData(context)
            context.deleteDatabase("card_wallet.db")
            context.filesDir.deleteRecursively()
        }
    }
}
