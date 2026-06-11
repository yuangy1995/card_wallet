package com.example.creditcard.data

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.example.creditcard.utils.AppJson
import kotlinx.serialization.builtins.ListSerializer

/**
 * Android 原生 SQLite 数据库辅助类
 * 负责本地 cards 表和 sync_records 账本表的维护
 */
class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "credit_card.db"
        private const val DATABASE_VERSION = 3

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
                + KEY_CARD_IMAGES + " TEXT DEFAULT '[]'" + ")")
        db.execSQL(createCardsTable)

        // 创建 sync_records 表
        val createSyncRecordsTable = ("CREATE TABLE " + TABLE_SYNC_RECORDS + "("
                + KEY_REC_CARD_ID + " TEXT PRIMARY KEY,"
                + KEY_REC_MUTATION_ID + " TEXT,"
                + KEY_REC_CHANGED_AT + " TEXT,"
                + KEY_REC_STATE + " TEXT,"
                + KEY_REC_CARD_JSON + " TEXT" + ")")
        db.execSQL(createSyncRecordsTable)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            addColumnIfMissing(db, TABLE_CARDS, KEY_CARD_IMAGES, "TEXT DEFAULT '[]'")
        }
        if (oldVersion < 3) {
            addColumnIfMissing(db, TABLE_CARDS, KEY_CARD_CATEGORY, "TEXT DEFAULT 'credit'")
        }
    }

    // ==========================================
    // CARDS 表的 CRUD
    // ==========================================

    fun getAllCards(): List<SharedCard> {
        val cardList = ArrayList<SharedCard>()
        val selectQuery = "SELECT * FROM $TABLE_CARDS ORDER BY $KEY_BANK ASC, $KEY_ALIAS ASC"
        val db = this.readableDatabase
        val cursor = db.rawQuery(selectQuery, null)

        if (cursor.moveToFirst()) {
            do {
                val card = SharedCard(
                    id = cursor.getString(cursor.getColumnIndexOrThrow(KEY_ID)),
                    cardCategory = cursor.getStringOrEmpty(KEY_CARD_CATEGORY).normalizeCardCategory(),
                    country = cursor.getStringOrEmpty(KEY_COUNTRY),
                    bank = cursor.getStringOrEmpty(KEY_BANK),
                    alias = cursor.getStringOrEmpty(KEY_ALIAS),
                    level = cursor.getStringOrEmpty(KEY_LEVEL),
                    cardNumber = cursor.getStringOrEmpty(KEY_CARD_NUMBER),
                    cvv = cursor.getStringOrEmpty(KEY_CVV),
                    valid = cursor.getStringOrEmpty(KEY_VALID),
                    limit = cursor.getDouble(cursor.getColumnIndexOrThrow(KEY_LIMIT)),
                    type = cursor.getStringOrEmpty(KEY_TYPE).ifEmpty { "CNY" },
                    isSharedLimit = cursor.getInt(cursor.getColumnIndexOrThrow(KEY_IS_SHARED_LIMIT)) == 1,
                    accountBillDate = cursor.getStringOrEmpty(KEY_ACCOUNT_BILL_DATE),
                    dueDate = cursor.getStringOrEmpty(KEY_DUE_DATE),
                    billingDaySpendingToNextBill = cursor.getInt(cursor.getColumnIndexOrThrow(KEY_BILLING_SPENDING_NEXT)) == 1,
                    annualFee = cursor.getDouble(cursor.getColumnIndexOrThrow(KEY_ANNUAL_FEE)),
                    isQualified = cursor.getStringOrEmpty(KEY_IS_QUALIFIED).ifEmpty { "2" },
                    nextAnnualFeeCollectionTime = if (cursor.isNull(cursor.getColumnIndexOrThrow(KEY_NEXT_ANNUAL_FEE_TIME))) null else cursor.getLong(cursor.getColumnIndexOrThrow(KEY_NEXT_ANNUAL_FEE_TIME)),
                    lastTime = if (cursor.isNull(cursor.getColumnIndexOrThrow(KEY_LAST_TIME))) null else cursor.getLong(cursor.getColumnIndexOrThrow(KEY_LAST_TIME)),
                    lastModifyTime = cursor.getLong(cursor.getColumnIndexOrThrow(KEY_LAST_MODIFY_TIME)),
                    equity = cursor.getStringOrEmpty(KEY_EQUITY),
                    remark = cursor.getStringOrEmpty(KEY_REMARK),
                    cardImages = cursor.getCardImages()
                )
                cardList.add(card)
            } while (cursor.moveToNext())
        }
        cursor.close()
        return cardList
    }

    fun getCardById(id: String): SharedCard? {
        val db = this.readableDatabase
        val cursor = db.query(
            TABLE_CARDS, null, "$KEY_ID = ?", arrayOf(id),
            null, null, null
        )

        var card: SharedCard? = null
        if (cursor.moveToFirst()) {
            card = SharedCard(
                id = cursor.getString(cursor.getColumnIndexOrThrow(KEY_ID)),
                cardCategory = cursor.getStringOrEmpty(KEY_CARD_CATEGORY).normalizeCardCategory(),
                country = cursor.getStringOrEmpty(KEY_COUNTRY),
                bank = cursor.getStringOrEmpty(KEY_BANK),
                alias = cursor.getStringOrEmpty(KEY_ALIAS),
                level = cursor.getStringOrEmpty(KEY_LEVEL),
                cardNumber = cursor.getStringOrEmpty(KEY_CARD_NUMBER),
                cvv = cursor.getStringOrEmpty(KEY_CVV),
                valid = cursor.getStringOrEmpty(KEY_VALID),
                limit = cursor.getDouble(cursor.getColumnIndexOrThrow(KEY_LIMIT)),
                type = cursor.getStringOrEmpty(KEY_TYPE).ifEmpty { "CNY" },
                isSharedLimit = cursor.getInt(cursor.getColumnIndexOrThrow(KEY_IS_SHARED_LIMIT)) == 1,
                accountBillDate = cursor.getStringOrEmpty(KEY_ACCOUNT_BILL_DATE),
                dueDate = cursor.getStringOrEmpty(KEY_DUE_DATE),
                billingDaySpendingToNextBill = cursor.getInt(cursor.getColumnIndexOrThrow(KEY_BILLING_SPENDING_NEXT)) == 1,
                annualFee = cursor.getDouble(cursor.getColumnIndexOrThrow(KEY_ANNUAL_FEE)),
                isQualified = cursor.getStringOrEmpty(KEY_IS_QUALIFIED).ifEmpty { "2" },
                nextAnnualFeeCollectionTime = if (cursor.isNull(cursor.getColumnIndexOrThrow(KEY_NEXT_ANNUAL_FEE_TIME))) null else cursor.getLong(cursor.getColumnIndexOrThrow(KEY_NEXT_ANNUAL_FEE_TIME)),
                lastTime = if (cursor.isNull(cursor.getColumnIndexOrThrow(KEY_LAST_TIME))) null else cursor.getLong(cursor.getColumnIndexOrThrow(KEY_LAST_TIME)),
                lastModifyTime = cursor.getLong(cursor.getColumnIndexOrThrow(KEY_LAST_MODIFY_TIME)),
                equity = cursor.getStringOrEmpty(KEY_EQUITY),
                remark = cursor.getStringOrEmpty(KEY_REMARK),
                cardImages = cursor.getCardImages()
            )
        }
        cursor.close()
        return card
    }

    fun saveCard(card: SharedCard) {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(KEY_ID, card.id)
            put(KEY_CARD_CATEGORY, card.cardCategory.normalizeCardCategory())
            put(KEY_COUNTRY, card.country)
            put(KEY_BANK, card.bank)
            put(KEY_ALIAS, card.alias)
            put(KEY_LEVEL, card.level)
            put(KEY_CARD_NUMBER, card.cardNumber)
            put(KEY_CVV, card.cvv)
            put(KEY_VALID, card.valid)
            put(KEY_LIMIT, card.limit)
            put(KEY_TYPE, card.type)
            put(KEY_IS_SHARED_LIMIT, if (card.isSharedLimit) 1 else 0)
            put(KEY_ACCOUNT_BILL_DATE, card.accountBillDate)
            put(KEY_DUE_DATE, card.dueDate)
            put(KEY_BILLING_SPENDING_NEXT, if (card.billingDaySpendingToNextBill) 1 else 0)
            put(KEY_ANNUAL_FEE, card.annualFee)
            put(KEY_IS_QUALIFIED, card.isQualified)
            put(KEY_NEXT_ANNUAL_FEE_TIME, card.nextAnnualFeeCollectionTime)
            put(KEY_LAST_TIME, card.lastTime)
            put(KEY_LAST_MODIFY_TIME, card.lastModifyTime)
            put(KEY_EQUITY, card.equity)
            put(KEY_REMARK, card.remark)
            put(KEY_CARD_IMAGES, encodeCardImages(card.cardImages))
        }
        db.insertWithOnConflict(TABLE_CARDS, null, values, SQLiteDatabase.CONFLICT_REPLACE)
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

    fun getAllSyncRecords(): List<CardSyncRecord> {
        val recordList = ArrayList<CardSyncRecord>()
        val selectQuery = "SELECT * FROM $TABLE_SYNC_RECORDS"
        val db = this.readableDatabase
        val cursor = db.rawQuery(selectQuery, null)

        if (cursor.moveToFirst()) {
            do {
                val cardJson = cursor.getString(cursor.getColumnIndexOrThrow(KEY_REC_CARD_JSON))
                val cardObj = if (!cardJson.isNullOrEmpty()) {
                    try {
                        AppJson.json.decodeFromString<SharedCard>(cardJson)
                    } catch (e: Exception) {
                        null
                    }
                } else null

                val record = CardSyncRecord(
                    cardId = cursor.getString(cursor.getColumnIndexOrThrow(KEY_REC_CARD_ID)),
                    mutationId = cursor.getString(cursor.getColumnIndexOrThrow(KEY_REC_MUTATION_ID)),
                    changedAt = cursor.getString(cursor.getColumnIndexOrThrow(KEY_REC_CHANGED_AT)),
                    state = cursor.getString(cursor.getColumnIndexOrThrow(KEY_REC_STATE)),
                    card = cardObj
                )
                recordList.add(record)
            } while (cursor.moveToNext())
        }
        cursor.close()
        return recordList
    }

    fun saveSyncRecord(record: CardSyncRecord) {
        val db = this.writableDatabase
        val cardJson = record.card?.let {
            try {
                AppJson.json.encodeToString(SharedCard.serializer(), it)
            } catch (e: Exception) {
                null
            }
        }

        val values = ContentValues().apply {
            put(KEY_REC_CARD_ID, record.cardId)
            put(KEY_REC_MUTATION_ID, record.mutationId)
            put(KEY_REC_CHANGED_AT, record.changedAt)
            put(KEY_REC_STATE, record.state)
            put(KEY_REC_CARD_JSON, cardJson)
        }
        db.insertWithOnConflict(TABLE_SYNC_RECORDS, null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun saveSyncRecords(records: List<CardSyncRecord>) {
        val db = this.writableDatabase
        db.beginTransaction()
        try {
            for (record in records) {
                saveSyncRecord(record)
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

    fun resetDatabase() {
        val db = this.writableDatabase
        db.delete(TABLE_CARDS, null, null)
        db.delete(TABLE_SYNC_RECORDS, null, null)
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
        return try {
            AppJson.json.decodeFromString(
                ListSerializer(CardImageAsset.serializer()),
                raw
            )
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun encodeCardImages(images: List<CardImageAsset>): String {
        return try {
            AppJson.json.encodeToString(
                ListSerializer(CardImageAsset.serializer()),
                images
            )
        } catch (e: Exception) {
            "[]"
        }
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
