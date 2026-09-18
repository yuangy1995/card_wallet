package com.example.creditcard.utils

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.test.core.app.ApplicationProvider
import com.example.creditcard.data.*
import java.io.File
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[34])
class LocalStorageSafetyTest {
    private val context get() = ApplicationProvider.getApplicationContext<Context>()
    private val dbName = "card_wallet.db"
    @Before fun clean() { context.deleteDatabase(dbName) }
    @Test fun cardsAndLedgerAreSealedAndTransactionRollsBack() {
        DatabaseHelper(context).use { db ->
            val card = SharedCard(id="a", bank="SECRET_BANK",cardImages=listOf(CardImageAsset(id="img",data="PRIVATE_IMAGE")))
            db.transaction {
                db.saveCard(card); db.saveSyncRecord(CardSyncRecord(cardId="a",changedAt=SyncTime.nowIso(),state="active",card=card)); db.markLocalMutation()
            }
            assertEquals(card,db.getAllCards().single())
            assertEquals(card,db.getAllSyncRecords().single().card)
            val revision=db.mutationRevision()
            assertTrue(db.pending())
            try { db.transaction { db.deleteCardById("a"); db.markLocalMutation(); throw IllegalStateException("rollback") } } catch(_:IllegalStateException) {}
            assertEquals(card,db.getAllCards().single()); assertEquals(revision,db.mutationRevision())
            db.acknowledge(revision-1); assertTrue(db.pending())
            db.acknowledge(revision); assertFalse(db.pending())
            db.readableDatabase.rawQuery("SELECT bank, cardImages, encrypted_payload FROM cards",null).use {
                assertTrue(it.moveToFirst()); assertTrue(it.isNull(0)); assertTrue(it.isNull(1))
                assertFalse(it.getString(2).contains("SECRET_BANK")); assertFalse(it.getString(2).contains("PRIVATE_IMAGE"))
            }
        }
    }
    @Test fun tamperingAndWrongRowPurposeAreRejected() {
        val text=LocalDataCipher.seal("SECRET","card:a")
        assertEquals("SECRET",LocalDataCipher.open(text,"card:a"))
        assertNotEquals(text,LocalDataCipher.seal("SECRET","card:a"))
        try { LocalDataCipher.open(text,"card:b"); fail("Swapped row must fail") } catch(_:Exception) {}
        DatabaseHelper(context).use { db ->
            db.saveCard(SharedCard(id="a",bank="retained"))
            db.writableDatabase.execSQL("UPDATE cards SET encrypted_payload='broken' WHERE id='a'")
            try { db.getAllCards(); fail("Broken row must fail") } catch(_:Exception) {}
            assertEquals(1,android.database.DatabaseUtils.queryNumEntries(db.readableDatabase,"cards"))
        }
    }
    @Test fun oldDatabaseMigrationPreservesImagesAndRollsBackOnMalformedAttachment() {
        // Create a v4 fixture using the original column layout (no encrypted payload).
        val path=context.getDatabasePath(dbName); path.parentFile!!.mkdirs()
        val columns=listOf("id TEXT PRIMARY KEY", "cardCategory TEXT", "country TEXT", "bank TEXT", "alias TEXT", "level TEXT", "cardNumber TEXT", "cvv TEXT", "valid TEXT", "limit_val REAL", "type TEXT", "isSharedLimit INTEGER", "accountBillDate TEXT", "dueDate TEXT", "billingDaySpendingToNextBill INTEGER", "annualFee REAL", "isQualified TEXT", "nextAnnualFeeCollectionTime INTEGER", "lastTime INTEGER", "lastModifyTime INTEGER", "equity TEXT", "remark TEXT", "cardImages TEXT", "extraFields TEXT NOT NULL DEFAULT '{}'")
        SQLiteDatabase.openOrCreateDatabase(path,null).use { db ->
            db.execSQL("CREATE TABLE cards ("+columns.joinToString(",")+")")
            db.execSQL("CREATE TABLE sync_records (cardId TEXT PRIMARY KEY,mutationId TEXT,changedAt TEXT,state TEXT,card_json TEXT)")
            db.execSQL("INSERT INTO cards(id,bank,cardImages) VALUES('a','legacy','not-json')")
            db.version=4
        }
        try { DatabaseHelper(context).use { it.getAllCards() }; fail("Malformed image must abort migration") } catch(_:Exception) {}
        SQLiteDatabase.openDatabase(path.path,null,SQLiteDatabase.OPEN_READWRITE).use { db ->
            assertEquals(4,db.version)
            db.rawQuery("SELECT bank,cardImages FROM cards",null).use { it.moveToFirst(); assertEquals("legacy",it.getString(0)); assertEquals("not-json",it.getString(1)) }
            db.execSQL("UPDATE cards SET cardImages='[]'")
        }
        DatabaseHelper(context).use { db ->
            assertEquals("legacy",db.getAllCards().single().bank)
            assertEquals(5,db.readableDatabase.version)
            db.readableDatabase.rawQuery("SELECT bank FROM cards",null).use { it.moveToFirst(); assertTrue(it.isNull(0)) }
        }
    }
    @Test fun preferencesAndFavoritesKeepSeparateSemantics() {
        val prefs=context.getSharedPreferences("test-sensitive",Context.MODE_PRIVATE)
        prefs.edit().clear().putString("secret","LEGACY_SECRET").commit()
        assertEquals("LEGACY_SECRET",SensitivePreferences.read(prefs,"secret"))
        assertTrue(prefs.getString("secret","")!!.startsWith(LocalDataCipher.PREFIX))
        val favorites=context.getSharedPreferences("card_list_preferences",Context.MODE_PRIVATE)
        favorites.edit().putStringSet("wallet_favorite_card_ids",setOf("a","b")).commit()
        LocalCardPreferences.removeDeleted(context,emptySet())
        assertEquals(setOf("a","b"),favorites.getStringSet("wallet_favorite_card_ids",emptySet()))
        LocalCardPreferences.removeDeleted(context,setOf("a"))
        assertEquals(setOf("b"),favorites.getStringSet("wallet_favorite_card_ids",emptySet()))
    }
}
