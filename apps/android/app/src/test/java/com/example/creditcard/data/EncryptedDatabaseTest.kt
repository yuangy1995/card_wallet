package com.example.creditcard.data
import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.test.core.app.ApplicationProvider
import com.example.creditcard.utils.*
import javax.crypto.KeyGenerator
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class EncryptedDatabaseTest {
    private val context get() = ApplicationProvider.getApplicationContext<Context>()
    private fun cipher(): LocalRecordCipher {
        val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        return AesLocalRecordCipher { key }
    }
    private fun card() = SharedCard(id="fixture", bank="SyntheticPrivateBank", cardNumber="4111000000001234", cvv="876",
        cardImages=listOf(CardImageAsset(id="large", data="A".repeat(2_200_000))))
    private fun record(card: SharedCard) = CardSyncRecord(cardId=card.id, changedAt="2026-09-18T00:00:00.000Z", state="active", card=card)
    private fun legacy(name: String, card: SharedCard) {
        val file = context.getDatabasePath(name); file.parentFile!!.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(file, null).use { db ->
            db.execSQL("CREATE TABLE cards (id TEXT PRIMARY KEY,cardCategory TEXT,country TEXT,bank TEXT,alias TEXT,level TEXT,cardNumber TEXT,cvv TEXT,valid TEXT,limit_val REAL,type TEXT,isSharedLimit INTEGER,accountBillDate TEXT,dueDate TEXT,billingDaySpendingToNextBill INTEGER,annualFee REAL,isQualified TEXT,nextAnnualFeeCollectionTime INTEGER,lastTime INTEGER,lastModifyTime INTEGER,equity TEXT,remark TEXT,cardImages TEXT)")
            db.execSQL("CREATE TABLE sync_records (cardId TEXT PRIMARY KEY,mutationId TEXT,changedAt TEXT,state TEXT,card_json TEXT)")
            db.insertOrThrow("cards",null,ContentValues().apply {
                put("id",card.id);put("bank",card.bank);put("cardNumber",card.cardNumber);put("cvv",card.cvv)
                put("lastModifyTime",card.lastModifyTime)
                put("cardImages",AppJson.json.encodeToString(kotlinx.serialization.builtins.ListSerializer(CardImageAsset.serializer()),card.cardImages))
            })
            val record=record(card)
            db.insertOrThrow("sync_records",null,ContentValues().apply {
                put("cardId",card.id);put("mutationId",record.mutationId);put("changedAt",record.changedAt);put("state","active")
                put("card_json",AppJson.json.encodeToString(SharedCard.serializer(),card))
            })
            db.version=3
        }
    }
    @Test fun upgradesLargeRowsWithoutCursorWindowOverflowAndKeepsImages() {
        val name="migration-${UUID.randomUUID()}.db";val card=card();val cipher=cipher();legacy(name,card)
        DatabaseHelper(context,cipher,name).use { db ->
            assertEquals(card.cardImages,db.getAllCards().single().cardImages)
            assertEquals(card.bank,db.getAllSyncRecords().single().card!!.bank)
            assertEquals(4,db.readableDatabase.version)
            db.readableDatabase.rawQuery("SELECT bank,cardNumber,cvv,cardImages FROM cards",null).use {
                assertTrue(it.moveToFirst());repeat(4) { index -> assertTrue(it.isNull(index)) }
            }
            db.readableDatabase.rawQuery("SELECT max(length(sealed)),count(*) FROM encrypted_payload_chunks",null).use {
                assertTrue(it.moveToFirst());assertTrue(it.getInt(0)<=65_564);assertTrue(it.getInt(1)>40)
            }
        }
        DatabaseHelper(context,cipher,name).use { assertEquals(card.cardImages,it.getCardById(card.id)!!.cardImages) }
        context.deleteDatabase(name)
    }
    @Test fun failedMigrationRollsBackSchemaAndPlaintextSource() {
        val name="rollback-${UUID.randomUUID()}.db";val card=card();legacy(name,card)
        val actual=cipher();var writes=0
        val failing=object: LocalRecordCipher {
            override fun seal(plaintext:ByteArray,purpose:String):ByteArray { if(++writes==2) error("injected failure");return actual.seal(plaintext,purpose) }
            override fun open(envelope:ByteArray,purpose:String)=actual.open(envelope,purpose)
        }
        DatabaseHelper(context,failing,name).use { db -> assertThrows(Exception::class.java) { db.getAllCards() } }
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path,null,SQLiteDatabase.OPEN_READONLY).use { db ->
            assertEquals(3,db.version)
            db.rawQuery("SELECT cardNumber FROM cards",null).use { assertTrue(it.moveToFirst());assertEquals(card.cardNumber,it.getString(0)) }
        }
        DatabaseHelper(context,actual,name).use { assertEquals(card.cardImages,it.getAllCards().single().cardImages) }
        context.deleteDatabase(name)
    }
    @Test fun incompleteOrTamperedCiphertextNeverBecomesAnEmptyWallet() {
        val name="tamper-${UUID.randomUUID()}.db";val cipher=cipher()
        DatabaseHelper(context,cipher,name).use { db ->
            val card=card();db.saveCard(card)
            db.writableDatabase.execSQL("UPDATE encrypted_payload_chunks SET sealed = zeroblob(length(sealed)) WHERE part=0")
            assertThrows(Exception::class.java) { db.getAllCards() }
            assertEquals(1,db.readableDatabase.rawQuery("SELECT count(*) FROM cards",null).use { it.moveToFirst();it.getInt(0) })
        };context.deleteDatabase(name)
    }
    @Test fun cardAndLedgerCommitRollBackTogetherOnEncryptionFailure() {
        val name="commit-${UUID.randomUUID()}.db";val actual=cipher();var fail=false
        val cipher=object: LocalRecordCipher {
            override fun seal(plaintext:ByteArray,purpose:String):ByteArray { if(fail && purpose.startsWith("sync_records/")) error("injected failure");return actual.seal(plaintext,purpose) }
            override fun open(envelope:ByteArray,purpose:String)=actual.open(envelope,purpose)
        }
        val old=SharedCard(id="fixture",alias="before");val originalRecord=record(old)
        DatabaseHelper(context,cipher,name).use { db ->
            db.commitLocalChanges(listOf(originalRecord),listOf(old),emptySet());fail=true
            val changed=old.copy(alias="after")
            assertThrows(Exception::class.java) { db.commitLocalChanges(listOf(record(changed)),listOf(changed),emptySet()) }
            assertEquals(old,db.getAllCards().single());assertEquals(originalRecord,db.getAllSyncRecords().single())
        };context.deleteDatabase(name)
    }
}
