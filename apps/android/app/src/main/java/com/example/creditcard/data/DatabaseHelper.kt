package com.example.creditcard.data

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.example.creditcard.utils.AppJson
import com.example.creditcard.utils.LocalDataCipher
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject

/**
 * Android 原生 SQLite 数据库辅助类
 * 负责本地 cards 表和 sync_records 账本表的维护
 */
class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "card_wallet.db"
        private const val DATABASE_VERSION = 5

        // 表名
        private const val TABLE_CARDS = "cards"
        private const val TABLE_SYNC_RECORDS = "sync_records"

        // cards 表字段名
        private const val KEY_ID = "id"
        private const val KEY_CARD_CATEGORY = "cardCategory"
        private const val KEY_COUNTRY = "country"
        private const val KEY_BANK = "bank"
        private const val KEY_ALIAS = "alias"
        private const val KEY_LEVEL = "level"
        private const val KEY_CARD_NUMBER = "cardNumber"
        private const val KEY_CVV = "cvv"
        private const val KEY_VALID = "valid"
        private const val KEY_LIMIT = "limit_val"
        private const val KEY_TYPE = "type"
        private const val KEY_IS_SHARED_LIMIT = "isSharedLimit"
        private const val KEY_ACCOUNT_BILL_DATE = "accountBillDate"
        private const val KEY_DUE_DATE = "dueDate"
        private const val KEY_BILLING_SPENDING_NEXT = "billingDaySpendingToNextBill"
        private const val KEY_ANNUAL_FEE = "annualFee"
        private const val KEY_IS_QUALIFIED = "isQualified"
        private const val KEY_NEXT_ANNUAL_FEE_TIME = "nextAnnualFeeCollectionTime"
        private const val KEY_LAST_TIME = "lastTime"
        private const val KEY_LAST_MODIFY_TIME = "lastModifyTime"
        private const val KEY_EQUITY = "equity"
        private const val KEY_REMARK = "remark"
        private const val KEY_CARD_IMAGES = "cardImages"
        private const val KEY_EXTRA_FIELDS = "extraFields"
        private const val KEY_PAYLOAD = "encrypted_payload"
        private const val TABLE_META = "local_sync_metadata"

        // sync_records 表字段名
        private const val KEY_REC_CARD_ID = "cardId"
        private const val KEY_REC_MUTATION_ID = "mutationId"
        private const val KEY_REC_CHANGED_AT = "changedAt"
        private const val KEY_REC_STATE = "state"
        private const val KEY_REC_CARD_JSON = "card_json"
    }

    override fun onCreate(db: SQLiteDatabase) {
        // 创建 cards 表
        val createCardsTable = ("CREATE TABLE " + TABLE_CARDS + "("
                + KEY_ID + " TEXT PRIMARY KEY,"
                + KEY_CARD_CATEGORY + " TEXT DEFAULT 'credit',"
                + KEY_COUNTRY + " TEXT,"
                + KEY_BANK + " TEXT,"
                + KEY_ALIAS + " TEXT,"
                + KEY_LEVEL + " TEXT,"
                + KEY_CARD_NUMBER + " TEXT,"
                + KEY_CVV + " TEXT,"
                + KEY_VALID + " TEXT,"
                + KEY_LIMIT + " REAL,"
                + KEY_TYPE + " TEXT,"
                + KEY_IS_SHARED_LIMIT + " INTEGER,"
                + KEY_ACCOUNT_BILL_DATE + " TEXT,"
                + KEY_DUE_DATE + " TEXT,"
                + KEY_BILLING_SPENDING_NEXT + " INTEGER,"
                + KEY_ANNUAL_FEE + " REAL,"
                + KEY_IS_QUALIFIED + " TEXT,"
                + KEY_NEXT_ANNUAL_FEE_TIME + " INTEGER,"
                + KEY_LAST_TIME + " INTEGER,"
                + KEY_LAST_MODIFY_TIME + " INTEGER,"
                + KEY_EQUITY + " TEXT,"
                + KEY_REMARK + " TEXT,"
                + KEY_CARD_IMAGES + " TEXT DEFAULT '[]',"
                + KEY_EXTRA_FIELDS + " TEXT NOT NULL DEFAULT '{}',"
                + KEY_PAYLOAD + " TEXT" + ")")
        db.execSQL(createCardsTable)

        // 创建 sync_records 表
        val createSyncRecordsTable = ("CREATE TABLE " + TABLE_SYNC_RECORDS + "("
                + KEY_REC_CARD_ID + " TEXT PRIMARY KEY,"
                + KEY_REC_MUTATION_ID + " TEXT,"
                + KEY_REC_CHANGED_AT + " TEXT,"
                + KEY_REC_STATE + " TEXT,"
                + KEY_REC_CARD_JSON + " TEXT" + ")")
        db.execSQL(createSyncRecordsTable)
        createMetadataTable(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            addColumnIfMissing(db, TABLE_CARDS, KEY_CARD_IMAGES, "TEXT DEFAULT '[]'")
        }
        if (oldVersion < 3) {
            addColumnIfMissing(db, TABLE_CARDS, KEY_CARD_CATEGORY, "TEXT DEFAULT 'credit'")
        }
        if (oldVersion < 4) {
            addColumnIfMissing(db, TABLE_CARDS, KEY_EXTRA_FIELDS, "TEXT NOT NULL DEFAULT '{}'")
        }
        if (oldVersion < 5) {
            addColumnIfMissing(db, TABLE_CARDS, KEY_PAYLOAD, "TEXT")
            createMetadataTable(db)
            // SQLiteOpenHelper wraps the upgrade in a single transaction. Any unreadable image,
            // encryption failure or write failure aborts it, preserving the complete old database.
            db.query(TABLE_CARDS, null, null, null, null, null, null).use { cursor ->
                while (cursor.moveToNext()) {
                    val card = cursor.readLegacyCard()
                    val encrypted = cardValues(card)
                    check(db.update(TABLE_CARDS, encrypted, "$KEY_ID = ?", arrayOf(card.id)) == 1)
                }
            }
            db.query(TABLE_SYNC_RECORDS, null, null, null, null, null, null).use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getString(cursor.getColumnIndexOrThrow(KEY_REC_CARD_ID))
                    val raw = cursor.getStringOrEmpty(KEY_REC_CARD_JSON)
                    if(raw.isNotEmpty()) {
                        AppJson.json.decodeFromString<SharedCard>(raw) // validate before migrating
                        val values = ContentValues().apply { put(KEY_REC_CARD_JSON, LocalDataCipher.seal(raw,"record:$id")) }
                        check(db.update(TABLE_SYNC_RECORDS, values, "$KEY_REC_CARD_ID = ?", arrayOf(id)) == 1)
                    }
                }
            }
        }
    }

    private fun createMetadataTable(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS $TABLE_META (id INTEGER PRIMARY KEY CHECK(id=1), pending INTEGER NOT NULL DEFAULT 0, revision INTEGER NOT NULL DEFAULT 0)")
        db.execSQL("INSERT OR IGNORE INTO $TABLE_META(id) VALUES(1)")
    }
    fun <T> transaction(block: () -> T): T {
        val db = writableDatabase
        db.beginTransaction()
        return try { val value = block(); db.setTransactionSuccessful(); value } finally { db.endTransaction() }
    }
    fun markLocalMutation() { writableDatabase.execSQL("UPDATE $TABLE_META SET pending=1, revision=revision+1 WHERE id=1") }
    fun mutationRevision(): Long = readableDatabase.rawQuery("SELECT revision FROM $TABLE_META WHERE id=1", null).use { it.moveToFirst(); it.getLong(0) }
    fun pending(): Boolean = readableDatabase.rawQuery("SELECT pending FROM $TABLE_META WHERE id=1", null).use { it.moveToFirst(); it.getInt(0) == 1 }
    fun acknowledge(revision: Long) { writableDatabase.execSQL("UPDATE $TABLE_META SET pending=0 WHERE id=1 AND revision=?", arrayOf(revision)) }
    fun setPending(value: Boolean) { writableDatabase.execSQL("UPDATE $TABLE_META SET pending=? WHERE id=1", arrayOf(if(value) 1 else 0)) }


    // ==========================================
    // CARDS 表的 CRUD
    // ==========================================

    fun getAllCards(): List<SharedCard> = readableDatabase.query(TABLE_CARDS,null,null,null,null,null,null).use { cursor ->
        buildList { while(cursor.moveToNext()) add(cursor.readCard()) }.sortedWith(compareBy({ it.bank }, { it.alias }, { it.id }))
    }
    fun getCardById(id: String): SharedCard? = readableDatabase.query(TABLE_CARDS,null,"$KEY_ID = ?",arrayOf(id),null,null,null).use { cursor ->
        if(cursor.moveToFirst()) cursor.readCard() else null
    }
    private fun Cursor.readLegacyCard(): SharedCard {
        return SharedCard(
                    id = getString(getColumnIndexOrThrow(KEY_ID)),
                    cardCategory = getStringOrEmpty(KEY_CARD_CATEGORY).normalizeCardCategory(),
                    country = getStringOrEmpty(KEY_COUNTRY),
                    bank = getStringOrEmpty(KEY_BANK),
                    alias = getStringOrEmpty(KEY_ALIAS),
                    level = getStringOrEmpty(KEY_LEVEL),
                    cardNumber = getStringOrEmpty(KEY_CARD_NUMBER),
                    cvv = getStringOrEmpty(KEY_CVV),
                    valid = getStringOrEmpty(KEY_VALID),
                    limit = getDouble(getColumnIndexOrThrow(KEY_LIMIT)),
                    type = getStringOrEmpty(KEY_TYPE),
                    isSharedLimit = getInt(getColumnIndexOrThrow(KEY_IS_SHARED_LIMIT)) == 1,
                    accountBillDate = getStringOrEmpty(KEY_ACCOUNT_BILL_DATE),
                    dueDate = getStringOrEmpty(KEY_DUE_DATE),
                    billingDaySpendingToNextBill = getInt(getColumnIndexOrThrow(KEY_BILLING_SPENDING_NEXT)) == 1,
                    annualFee = getDouble(getColumnIndexOrThrow(KEY_ANNUAL_FEE)),
                    isQualified = getStringOrEmpty(KEY_IS_QUALIFIED).ifEmpty { "2" },
                    nextAnnualFeeCollectionTime = if (isNull(getColumnIndexOrThrow(KEY_NEXT_ANNUAL_FEE_TIME))) null else getLong(getColumnIndexOrThrow(KEY_NEXT_ANNUAL_FEE_TIME)),
                    lastTime = if (isNull(getColumnIndexOrThrow(KEY_LAST_TIME))) null else getLong(getColumnIndexOrThrow(KEY_LAST_TIME)),
                    lastModifyTime = getLong(getColumnIndexOrThrow(KEY_LAST_MODIFY_TIME)),
                    equity = getStringOrEmpty(KEY_EQUITY),
                    remark = getStringOrEmpty(KEY_REMARK),
                    cardImages = getCardImages(),
                    extraFields = AppJson.json.parseToJsonElement(getStringOrEmpty(KEY_EXTRA_FIELDS).ifBlank { "{}" }).jsonObject
                )
    }
    private fun Cursor.readCard(): SharedCard {
        val id = getString(getColumnIndexOrThrow(KEY_ID))
        val raw = getStringOrEmpty(KEY_PAYLOAD)
        check(raw.isNotEmpty()) { "卡片加密数据缺失，原数据已保留" }
        return AppJson.json.decodeFromString<SharedCard>(LocalDataCipher.open(raw,"card:$id")).also { check(it.id == id) }
    }
    fun saveCard(card: SharedCard) {
        val db = this.writableDatabase
        check(db.insertWithOnConflict(TABLE_CARDS, null, cardValues(card), SQLiteDatabase.CONFLICT_REPLACE) != -1L) { "本地数据未能保存" }
    }

    private fun cardValues(card: SharedCard): ContentValues = ContentValues().apply {
        put(KEY_ID,card.id)
        put(KEY_LAST_MODIFY_TIME,card.lastModifyTime)
        put(KEY_EXTRA_FIELDS,"{}")
        putNull(KEY_CARD_CATEGORY)
        putNull(KEY_COUNTRY)
        putNull(KEY_BANK)
        putNull(KEY_ALIAS)
        putNull(KEY_LEVEL)
        putNull(KEY_CARD_NUMBER)
        putNull(KEY_CVV)
        putNull(KEY_VALID)
        putNull(KEY_LIMIT)
        putNull(KEY_TYPE)
        putNull(KEY_IS_SHARED_LIMIT)
        putNull(KEY_ACCOUNT_BILL_DATE)
        putNull(KEY_DUE_DATE)
        putNull(KEY_BILLING_SPENDING_NEXT)
        putNull(KEY_ANNUAL_FEE)
        putNull(KEY_IS_QUALIFIED)
        putNull(KEY_NEXT_ANNUAL_FEE_TIME)
        putNull(KEY_LAST_TIME)
        putNull(KEY_EQUITY)
        putNull(KEY_REMARK)
        putNull(KEY_CARD_IMAGES)
        put(KEY_PAYLOAD,LocalDataCipher.seal(AppJson.json.encodeToString(SharedCard.serializer(),card),"card:${card.id}"))
    }

    fun deleteCardById(id: String) {
        val db = this.writableDatabase
        db.delete(TABLE_CARDS, "$KEY_ID = ?", arrayOf(id))
    }

    fun clearAllCards() {
        val db = this.writableDatabase
        db.delete(TABLE_CARDS, null, null)
    }

    // ==========================================
    // SYNC_RECORDS 表的 CRUD
    // ==========================================

    fun deletedCardIDs(): Set<String> = readableDatabase.query(TABLE_SYNC_RECORDS,
        arrayOf(KEY_REC_CARD_ID), "$KEY_REC_STATE = ?", arrayOf("deleted"), null, null, null).use { cursor ->
        buildSet { while(cursor.moveToNext()) add(cursor.getString(0)) }
    }

    fun lastMutationTime(cardId: String): String? = readableDatabase.query(
        TABLE_SYNC_RECORDS, arrayOf(KEY_REC_CHANGED_AT), "$KEY_REC_CARD_ID = ?", arrayOf(cardId), null, null, null
    ).use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }

    fun getAllSyncRecords(): List<CardSyncRecord> = readableDatabase.query(TABLE_SYNC_RECORDS,null,null,null,null,null,null).use { cursor ->
        buildList {
            while(cursor.moveToNext()) {
                val id = cursor.getString(cursor.getColumnIndexOrThrow(KEY_REC_CARD_ID))
                val state = cursor.getString(cursor.getColumnIndexOrThrow(KEY_REC_STATE))
                val raw = cursor.getStringOrEmpty(KEY_REC_CARD_JSON)
                val card = if(raw.isEmpty()) null else AppJson.json.decodeFromString<SharedCard>(LocalDataCipher.open(raw,"record:$id"))
                check(state == "deleted" || (state == "active" && card != null && card.id == id)) { "同步记录无法读取，原数据已保留" }
                add(CardSyncRecord(cardId=id, mutationId=cursor.getString(cursor.getColumnIndexOrThrow(KEY_REC_MUTATION_ID)),
                    changedAt=cursor.getString(cursor.getColumnIndexOrThrow(KEY_REC_CHANGED_AT)), state=state, card=card))
            }
        }
    }

    fun saveSyncRecord(record: CardSyncRecord) {
        val db = this.writableDatabase
        check(db.insertWithOnConflict(TABLE_SYNC_RECORDS, null, syncRecordValues(record), SQLiteDatabase.CONFLICT_REPLACE) != -1L) { "本地数据未能保存" }
    }

    private fun syncRecordValues(record: CardSyncRecord): ContentValues {
        val cardJson = record.card?.let { LocalDataCipher.seal(AppJson.json.encodeToString(SharedCard.serializer(), it), "record:${record.cardId}") }

        val values = ContentValues().apply {
            put(KEY_REC_CARD_ID, record.cardId)
            put(KEY_REC_MUTATION_ID, record.mutationId)
            put(KEY_REC_CHANGED_AT, record.changedAt)
            put(KEY_REC_STATE, record.state)
            put(KEY_REC_CARD_JSON, cardJson)
        }
        return values
    }

    fun saveSyncRecords(records: List<CardSyncRecord>) {
        val db = this.writableDatabase
        db.beginTransaction()
        try {
            for (record in records) {
                check(db.insertWithOnConflict(TABLE_SYNC_RECORDS, null, syncRecordValues(record), SQLiteDatabase.CONFLICT_REPLACE) != -1L) { "本地数据未能保存" }
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun clearAllSyncRecords() {
        val db = this.writableDatabase
        db.delete(TABLE_SYNC_RECORDS, null, null)
    }

    fun replaceSyncedData(records: List<CardSyncRecord>, cards: List<SharedCard>) {
        val db = this.writableDatabase
        db.beginTransaction()
        try {
            db.delete(TABLE_CARDS, null, null)
            db.delete(TABLE_SYNC_RECORDS, null, null)
            for (record in records) {
                check(db.insertWithOnConflict(TABLE_SYNC_RECORDS, null, syncRecordValues(record), SQLiteDatabase.CONFLICT_REPLACE) != -1L) { "本地数据未能保存" }
            }
            for (card in cards) {
                check(db.insertWithOnConflict(TABLE_CARDS, null, cardValues(card), SQLiteDatabase.CONFLICT_REPLACE) != -1L) { "本地数据未能保存" }
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun resetDatabase() {
        val db = this.writableDatabase
        transaction {
            db.delete(TABLE_CARDS, null, null)
            db.delete(TABLE_SYNC_RECORDS, null, null)
            db.execSQL("UPDATE $TABLE_META SET pending=0, revision=revision+1 WHERE id=1")
        }
    }

    private fun Cursor.getStringOrEmpty(columnName: String): String {
        val index = getColumnIndex(columnName)
        if (index < 0) return ""
        return if (isNull(index)) "" else getString(index).orEmpty()
    }

    private fun String.normalizeCardCategory(): String {
        return if (this == "debit") "debit" else "credit"
    }

    private fun Cursor.getCardImages(): List<CardImageAsset> {
        val index = getColumnIndex(KEY_CARD_IMAGES)
        if (index < 0 || isNull(index)) return emptyList()
        val raw = getString(index).orEmpty()
        if (raw.isBlank()) return emptyList()
        return AppJson.json.decodeFromString(ListSerializer(CardImageAsset.serializer()), raw)
    }

    private fun encodeCardImages(images: List<CardImageAsset>): String {
        return AppJson.json.encodeToString(ListSerializer(CardImageAsset.serializer()), images)
    }

    private fun addColumnIfMissing(db: SQLiteDatabase, tableName: String, columnName: String, definition: String) {
        val cursor = db.rawQuery("PRAGMA table_info($tableName)", null)
        val exists = try {
            var found = false
            while (cursor.moveToNext()) {
                val nameIndex = cursor.getColumnIndex("name")
                if (nameIndex >= 0 && cursor.getString(nameIndex) == columnName) {
                    found = true
                    break
                }
            }
            found
        } finally {
            cursor.close()
        }
        if (!exists) {
            db.execSQL("ALTER TABLE $tableName ADD COLUMN $columnName $definition")
        }
    }
}
