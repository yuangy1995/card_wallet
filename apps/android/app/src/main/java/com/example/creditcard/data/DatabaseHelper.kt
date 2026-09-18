package com.example.creditcard.data

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.example.creditcard.utils.AppJson
import com.example.creditcard.utils.AndroidLocalDataCipher
import com.example.creditcard.utils.LocalRecordCipher
import kotlinx.serialization.builtins.ListSerializer
import java.io.ByteArrayOutputStream
import java.util.UUID

/** Version 4 keeps the existing file and IDs, migrating plaintext rows in one SQLite transaction. */
class DatabaseHelper(
    context: Context,
    private val cipher: LocalRecordCipher = AndroidLocalDataCipher(context),
    name: String = DATABASE_NAME
) : SQLiteOpenHelper(context, name, null, DATABASE_VERSION) {
    companion object {
        private const val DATABASE_NAME = "card_wallet.db"
        private const val DATABASE_VERSION = 4
        private const val KEY_FORMAT = "payloadFormat"
        private const val TABLE_PAYLOADS = "encrypted_payload_chunks"
        private const val CHUNK_BYTES = 64 * 1024
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

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.execSQL("PRAGMA secure_delete=ON")
    }
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE $TABLE_CARDS ($KEY_ID TEXT PRIMARY KEY, $KEY_FORMAT TEXT NOT NULL)")
        db.execSQL("CREATE TABLE $TABLE_SYNC_RECORDS ($KEY_REC_CARD_ID TEXT PRIMARY KEY, $KEY_FORMAT TEXT NOT NULL)")
        createChunkTable(db)
    }
    private fun createChunkTable(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS $TABLE_PAYLOADS (kind TEXT NOT NULL, recordId TEXT NOT NULL, part INTEGER NOT NULL, sealed BLOB NOT NULL, PRIMARY KEY(kind,recordId,part))")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // SQLiteOpenHelper wraps the entire migration, including version update, in a transaction.
        if (oldVersion < 2) addColumnIfMissing(db, TABLE_CARDS, KEY_CARD_IMAGES, "TEXT DEFAULT '[]'")
        if (oldVersion < 3) addColumnIfMissing(db, TABLE_CARDS, KEY_CARD_CATEGORY, "TEXT DEFAULT 'credit'")
        if (oldVersion < 4) {
            addColumnIfMissing(db, TABLE_CARDS, KEY_FORMAT, "TEXT")
            addColumnIfMissing(db, TABLE_SYNC_RECORDS, KEY_FORMAT, "TEXT")
            createChunkTable(db)
            val cards = readLegacyCards(db)
            val records = readLegacyRecords(db)
            cards.forEach { putCard(db, it, clearLegacy = true) }
            records.forEach { putRecord(db, it, clearLegacy = true) }
        }
    }

    fun getAllCards(): List<SharedCard> = readableDatabase.query(TABLE_CARDS, arrayOf(KEY_ID, KEY_FORMAT), null, null, null, null, null).use { cursor ->
        buildList {
            while (cursor.moveToNext()) {
                val id = cursor.getString(0)
                val data = readPayload(readableDatabase, TABLE_CARDS, id, cursor.getString(1))
                add(AppJson.json.decodeFromString<SharedCard>(data).also { check(it.id == id) })
            }
        }.sortedWith(compareBy<SharedCard> { it.bank }.thenBy { it.alias }.thenBy { it.id })
    }
    fun getCardById(id: String): SharedCard? = readableDatabase.query(TABLE_CARDS, arrayOf(KEY_FORMAT), "$KEY_ID = ?", arrayOf(id), null, null, null).use {
        if (!it.moveToFirst()) null else AppJson.json.decodeFromString<SharedCard>(readPayload(readableDatabase, TABLE_CARDS, id, it.getString(0))).also { card -> check(card.id == id) }
    }
    fun getAllSyncRecords(): List<CardSyncRecord> = readableDatabase.query(TABLE_SYNC_RECORDS, arrayOf(KEY_REC_CARD_ID, KEY_FORMAT), null, null, null, null, null).use { cursor ->
        buildList {
            while (cursor.moveToNext()) {
                val id = cursor.getString(0)
                add(AppJson.json.decodeFromString<CardSyncRecord>(readPayload(readableDatabase, TABLE_SYNC_RECORDS, id, cursor.getString(1))).also { check(it.cardId == id) })
            }
        }
    }
    fun getSyncRecordById(id: String): CardSyncRecord? = readableDatabase.query(TABLE_SYNC_RECORDS, arrayOf(KEY_FORMAT), "$KEY_REC_CARD_ID = ?", arrayOf(id), null, null, null).use {
        if (!it.moveToFirst()) null else AppJson.json.decodeFromString<CardSyncRecord>(readPayload(readableDatabase, TABLE_SYNC_RECORDS, id, it.getString(0)))
    }
    fun commitLocalChanges(records: List<CardSyncRecord>, cards: List<SharedCard>, deletedIds: Set<String>) = transaction { db ->
        deletedIds.forEach { id ->
            db.delete(TABLE_CARDS, "$KEY_ID = ?", arrayOf(id))
            db.delete(TABLE_PAYLOADS, "kind = ? AND recordId = ?", arrayOf(TABLE_CARDS, id))
        }
        cards.forEach { putCard(db, it) }; records.forEach { putRecord(db, it) }
    }
    fun saveCard(card: SharedCard) = transaction { putCard(it, card) }
    fun saveCards(cards: List<SharedCard>) = transaction { db -> cards.forEach { putCard(db, it) } }
    fun saveSyncRecord(record: CardSyncRecord) = transaction { putRecord(it, record) }
    fun saveSyncRecords(records: List<CardSyncRecord>) = transaction { db -> records.forEach { putRecord(db, it) } }
    fun deleteCardById(id: String) = transaction { db ->
        db.delete(TABLE_CARDS, "$KEY_ID = ?", arrayOf(id))
        db.delete(TABLE_PAYLOADS, "kind = ? AND recordId = ?", arrayOf(TABLE_CARDS, id))
    }
    fun clearAllCards() = transaction { db -> clearTable(db, TABLE_CARDS) }
    fun clearAllSyncRecords() = transaction { db -> clearTable(db, TABLE_SYNC_RECORDS) }
    fun resetDatabase() = transaction { db -> clearTable(db, TABLE_CARDS); clearTable(db, TABLE_SYNC_RECORDS) }
    fun replaceSyncedData(records: List<CardSyncRecord>, cards: List<SharedCard>) = transaction { db ->
        clearTable(db, TABLE_CARDS); clearTable(db, TABLE_SYNC_RECORDS)
        records.forEach { putRecord(db, it) }; cards.forEach { putCard(db, it) }
    }
    private fun clearTable(db: SQLiteDatabase, table: String) {
        db.delete(table, null, null)
        db.delete(TABLE_PAYLOADS, "kind = ?", arrayOf(table))
    }
    private fun transaction(block: (SQLiteDatabase) -> Unit) {
        val db = writableDatabase
        db.beginTransaction()
        try { block(db); db.setTransactionSuccessful() } finally { db.endTransaction() }
    }
    private fun putCard(db: SQLiteDatabase, card: SharedCard, clearLegacy: Boolean = false) =
        putPayload(db, TABLE_CARDS, KEY_ID, card.id, AppJson.json.encodeToString(SharedCard.serializer(), card), clearLegacy)
    private fun putRecord(db: SQLiteDatabase, record: CardSyncRecord, clearLegacy: Boolean = false) =
        putPayload(db, TABLE_SYNC_RECORDS, KEY_REC_CARD_ID, record.cardId, AppJson.json.encodeToString(CardSyncRecord.serializer(), record), clearLegacy)

    private fun putPayload(db: SQLiteDatabase, table: String, idColumn: String, id: String, json: String, clearLegacy: Boolean) {
        val bytes = json.toByteArray(Charsets.UTF_8)
        try {
            val parts = (bytes.size + CHUNK_BYTES - 1) / CHUNK_BYTES
            val format = "gcm-chunks-v1:${UUID.randomUUID()}:$parts"
            db.delete(TABLE_PAYLOADS, "kind = ? AND recordId = ?", arrayOf(table, id))
            repeat(parts) { index ->
                val plain = bytes.copyOfRange(index * CHUNK_BYTES, minOf(bytes.size, (index + 1) * CHUNK_BYTES))
                val sealed = try { cipher.seal(plain, "$table/$id/$format/$index") } finally { plain.fill(0) }
                db.insertOrThrow(TABLE_PAYLOADS, null, ContentValues().apply {
                    put("kind", table); put("recordId", id); put("part", index); put("sealed", sealed)
                })
            }
            val values = ContentValues().apply { put(idColumn, id); put(KEY_FORMAT, format) }
            if (clearLegacy) columns(db, table).filter { it != idColumn && it != KEY_FORMAT }.forEach(values::putNull)
            check(db.insertWithOnConflict(table, null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L) { "保存本地数据失败" }
        } finally { bytes.fill(0) }
    }
    private fun readPayload(db: SQLiteDatabase, table: String, id: String, format: String?): String {
        val header = format?.split(':') ?: error("本地加密数据缺少版本；原数据已保留")
        check(header.size == 3 && header[0] == "gcm-chunks-v1") { "本地加密版本不受支持；原数据已保留" }
        val expected = header[2].toIntOrNull() ?: error("本地加密记录不完整")
        check(expected > 0)
        val output = ByteArrayOutputStream()
        db.query(TABLE_PAYLOADS, arrayOf("part", "sealed"), "kind = ? AND recordId = ?", arrayOf(table, id), null, null, "part ASC").use { cursor ->
            check(cursor.count == expected) { "本地加密记录不完整；原数据已保留" }
            var index = 0
            while (cursor.moveToNext()) {
                check(cursor.getInt(0) == index)
                val plain = cipher.open(cursor.getBlob(1), "$table/$id/$format/$index")
                try { output.write(plain) } finally { plain.fill(0) }
                index++
            }
        }
        val bytes = output.toByteArray()
        return try { bytes.toString(Charsets.UTF_8) } finally { bytes.fill(0); output.reset() }
    }
    private fun readLegacyCards(db: SQLiteDatabase): List<SharedCard> {
        val cards = ArrayList<SharedCard>()
        val projection = columns(db, TABLE_CARDS).filter { it != KEY_CARD_IMAGES }.toTypedArray()
        db.query(TABLE_CARDS, projection, null, null, null, null, null).use { cursor ->
            while (cursor.moveToNext()) {
                cards.add(SharedCard(
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
                    type = cursor.getStringOrEmpty(KEY_TYPE),
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
                    cardImages = readLargeText(db, TABLE_CARDS, KEY_CARD_IMAGES, KEY_ID, cursor.getString(cursor.getColumnIndexOrThrow(KEY_ID)))
                        .takeIf { it.isNotBlank() }?.let { AppJson.json.decodeFromString(ListSerializer(CardImageAsset.serializer()), it) } ?: emptyList()
                ))
            }
        }
        return cards
    }
    private fun readLegacyRecords(db: SQLiteDatabase): List<CardSyncRecord> =
        db.query(TABLE_SYNC_RECORDS, arrayOf(KEY_REC_CARD_ID, KEY_REC_MUTATION_ID, KEY_REC_CHANGED_AT, KEY_REC_STATE), null, null, null, null, null).use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    val id = cursor.getString(0)
                    val json = readLargeText(db, TABLE_SYNC_RECORDS, KEY_REC_CARD_JSON, KEY_REC_CARD_ID, id)
                    val card = json.takeIf { it.isNotBlank() }?.let { AppJson.json.decodeFromString<SharedCard>(it) }
                    check(cursor.getString(3) != "active" || card != null) { "旧同步记录不完整；原数据已保留" }
                    add(CardSyncRecord(id, cursor.getString(1), cursor.getString(2), cursor.getString(3), card))
                }
            }
        }
    private fun readLargeText(db: SQLiteDatabase, table: String, column: String, key: String, id: String): String {
        val length = db.rawQuery("SELECT length($column) FROM $table WHERE $key = ?", arrayOf(id)).use { if (it.moveToFirst()) it.getInt(0) else 0 }
        val result = StringBuilder()
        var position = 1
        while (position <= length) {
            db.rawQuery("SELECT substr($column, ?, 60000) FROM $table WHERE $key = ?", arrayOf(position.toString(), id)).use {
                check(it.moveToFirst()); result.append(it.getString(0).orEmpty())
            }
            position += 60000
        }
        return result.toString()
    }
    private fun columns(db: SQLiteDatabase, table: String): List<String> = db.rawQuery("PRAGMA table_info($table)", null).use { cursor ->
        buildList { while (cursor.moveToNext()) add(cursor.getString(cursor.getColumnIndexOrThrow("name"))) }
    }
    private fun addColumnIfMissing(db: SQLiteDatabase, table: String, column: String, definition: String) {
        if (column !in columns(db, table)) db.execSQL("ALTER TABLE $table ADD COLUMN $column $definition")
    }
    private fun Cursor.getStringOrEmpty(column: String): String {
        val index = getColumnIndex(column)
        return if (index < 0 || isNull(index)) "" else getString(index).orEmpty()
    }
    private fun String.normalizeCardCategory() = if (this == "debit") "debit" else "credit"
}
