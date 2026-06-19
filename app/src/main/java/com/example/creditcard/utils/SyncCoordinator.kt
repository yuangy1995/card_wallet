package com.example.creditcard.utils

import android.content.Context
import com.example.creditcard.data.CardChangeDetail
import com.example.creditcard.data.CardSyncRecord
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.FieldChangeDetail
import com.example.creditcard.data.SharedCard
import com.example.creditcard.data.SyncHistoryEntry
import com.example.creditcard.data.SyncSnapshot
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * WebDAV 配置信息实体
 */
data class WebDAVConfig(
    val url: String = "",
    val user: String = "",
    val pass: String = "",
    val syncPassword: String = "",
    val isEnabled: Boolean = false
)

/**
 * 同步状态信息
 */
data class SyncStatus(
    val message: String = "未配置云同步，卡片数据将保存在本地",
    val type: String = "info", // "info", "success", "warning", "error"
    val isSyncing: Boolean = false,
    val pending: Boolean = false,
    val elapsedMs: Long = 0L,
    val lastDurationMs: Long = 0L
)

data class SyncProgress(
    val phase: String = "空闲",
    val step: Int = 0,
    val total: Int = 0,
    val detail: String = "",
    val totalBytes: Long = 0L,
    val transferredBytes: Long = 0L
)

private data class SnapshotReadResult(
    val filename: String,
    val snapshot: SyncSnapshot? = null,
    val failureStage: String? = null,
    val failureMessage: String? = null
) {
    val failed: Boolean get() = snapshot == null
}

/**
 * 云端同步协调器
 * 负责本地 SQLite 与云端 WebDAV 的 CRDT 合流同步核心业务调度
 */
object SyncCoordinator {

    private const val PREFS_NAME = "credit_card_sync_prefs"
    private const val KEY_URL = "webdav_url"
    private const val KEY_USER = "webdav_user"
    private const val KEY_PASS = "webdav_pass"
    private const val KEY_SYNC_PASSWORD = "webdav_sync_password_v4"
    private const val KEY_ENABLED = "webdav_enabled"
    private const val KEY_PENDING = "sync_pending"
    private const val KEY_SYNC_HISTORY = "sync_history"
    private const val KEY_PENDING_MUTATIONS = "pending_mutation_details"
    private const val KEY_MUTATION_REVISION = "local_mutation_revision"
    private const val KEY_LAST_WEBDAV_SNAPSHOT = "last_webdav_snapshot_filename"
    private const val PROGRESS_UI_INTERVAL_MS = 250L
    private const val MAX_SNAPSHOTS_TO_MERGE = 5

    // 用 MutableStateFlow 进行全局同步状态发布，Compose 侧可极其优雅地消费它
    private val _syncStatus = MutableStateFlow(SyncStatus())
    val syncStatus: StateFlow<SyncStatus> = _syncStatus

    private val _syncProgress = MutableStateFlow(SyncProgress())
    val syncProgress: StateFlow<SyncProgress> = _syncProgress

    private val _syncHistory = MutableStateFlow<List<SyncHistoryEntry>>(emptyList())
    val syncHistory: StateFlow<List<SyncHistoryEntry>> = _syncHistory

    // 本地缓存的卡片列表流，供主页监听
    private val _cardsFlow = MutableStateFlow<List<SharedCard>>(emptyList())
    val cardsFlow: StateFlow<List<SharedCard>> = _cardsFlow

    private val syncScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val syncMutex = Mutex()
    private val dbWriteLock = Any()
    private val backgroundSyncLock = Any()
    @Volatile private var cancelRequested = false
    @Volatile private var activeSyncJob: Job? = null
    @Volatile private var backgroundSyncScheduled = false
    @Volatile private var backgroundSyncPublishLocalChanges = false
    @Volatile private var syncStartedAtMillis = 0L
    @Volatile private var syncElapsedJob: Job? = null

    /**
     * 加载本地缓存好的卡包数据，作为应用启动的主入口数据源
     */
    fun initLocalData(context: Context) {
        val appContext = context.applicationContext
        _cardsFlow.value = DatabaseHelper(appContext).use { db ->
            db.getAllCards()
        }
        _syncHistory.value = loadSyncHistory(context)
        
        val config = loadConfig(context)
        if (!config.isEnabled) {
            updateStatus("未配置云同步，卡片数据将保存在本地", "info", isPending(context))
        } else {
            updateStatus("已启用云同步，正在检查云端数据", "info", isPending(context))
            requestBackgroundSync(context, publishLocalChanges = false)
        }
    }

    /**
     * 保存 WebDAV 云同步配置
     */
    fun saveConfig(context: Context, config: WebDAVConfig) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString(KEY_URL, config.url)
            putString(KEY_USER, config.user)
            if (config.pass.isNotEmpty()) {
                // 如果传入了新密码，则保存加密密文或普通存储（此处为了兼容多端使用默认加密网关）
                putString(KEY_PASS, CryptoManager.encrypt(config.pass))
            }
            if (config.syncPassword.isNotEmpty()) {
                putString(KEY_SYNC_PASSWORD, CryptoManager.encrypt(config.syncPassword))
            }
            putBoolean(KEY_ENABLED, config.isEnabled)
            apply()
        }
        
        if (config.isEnabled) {
            updateStatus("云同步配置已保存，正在尝试建立首期同步...", "info", isPending(context))
        } else {
            updateStatus("云同步已关闭，本机改动将仅保留于本地", "info", isPending(context))
        }
    }

    /**
     * 加载 WebDAV 云同步配置
     */
    fun loadConfig(context: Context): WebDAVConfig {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val url = prefs.getString(KEY_URL, "") ?: ""
        val user = prefs.getString(KEY_USER, "") ?: ""
        val encryptedPass = prefs.getString(KEY_PASS, "") ?: ""
        val encryptedSyncPassword = prefs.getString(KEY_SYNC_PASSWORD, "") ?: ""
        
        // 自动还原保存的密码
        val pass = if (encryptedPass.isNotEmpty()) {
            try {
                CryptoManager.decrypt(encryptedPass)
            } catch (e: Exception) {
                ""
            }
        } else ""

        val syncPassword = if (encryptedSyncPassword.isNotEmpty()) {
            try {
                CryptoManager.decrypt(encryptedSyncPassword)
            } catch (e: Exception) {
                ""
            }
        } else ""

        val isEnabled = prefs.getBoolean(KEY_ENABLED, false)
        return WebDAVConfig(url, user, pass, syncPassword, isEnabled)
    }

    /**
     * 标记本地有改动需要待同步
     */
    fun markPending(context: Context, pending: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_PENDING, pending).apply()
        
        // 同时更新状态
        val cur = _syncStatus.value
        _syncStatus.value = cur.copy(pending = pending)
    }

    private fun isPending(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_PENDING, false)
    }

    private fun mutationRevision(context: Context): Long {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getLong(KEY_MUTATION_REVISION, 0L)
    }

    private fun lastWebDAVSnapshotFilename(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_LAST_WEBDAV_SNAPSHOT, "") ?: ""
    }

    private fun saveLastWebDAVSnapshotFilename(context: Context, filename: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LAST_WEBDAV_SNAPSHOT, filename)
            .apply()
    }

    private fun bumpMutationRevision(context: Context): Long {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val next = prefs.getLong(KEY_MUTATION_REVISION, 0L) + 1L
        prefs.edit().putLong(KEY_MUTATION_REVISION, next).apply()
        return next
    }

    private fun ensureSyncNotCancelled() {
        if (cancelRequested) {
            throw CancellationException("同步已被手动终止")
        }
    }

    private fun updateStatus(
        msg: String,
        type: String,
        pending: Boolean,
        isSyncing: Boolean = false,
        elapsedMs: Long = if (isSyncing) _syncStatus.value.elapsedMs else 0L,
        lastDurationMs: Long = _syncStatus.value.lastDurationMs
    ) {
        _syncStatus.value = SyncStatus(msg, type, isSyncing, pending, elapsedMs.coerceAtLeast(0L), lastDurationMs.coerceAtLeast(0L))
    }

    private fun updateProgress(
        phase: String,
        step: Int,
        total: Int,
        detail: String = "",
        totalBytes: Long = 0L,
        transferredBytes: Long = 0L
    ) {
        _syncProgress.value = SyncProgress(
            phase = phase,
            step = step,
            total = total,
            detail = detail,
            totalBytes = totalBytes.coerceAtLeast(0L),
            transferredBytes = transferredBytes.coerceAtLeast(0L)
        )
    }

    private fun startSyncElapsedTicker(startedAtMillis: Long) {
        syncStartedAtMillis = startedAtMillis
        syncElapsedJob?.cancel()
        syncElapsedJob = syncScope.launch {
            while (true) {
                delay(1000)
                val elapsed = (SyncTime.nowMillis() - syncStartedAtMillis).coerceAtLeast(0L)
                _syncStatus.value = _syncStatus.value.copy(
                    isSyncing = true,
                    elapsedMs = elapsed
                )
            }
        }
    }

    private fun syncDurationSince(startedAtMillis: Long): Long {
        return if (startedAtMillis > 0L) {
            (SyncTime.nowMillis() - startedAtMillis).coerceAtLeast(0L)
        } else {
            _syncStatus.value.elapsedMs.coerceAtLeast(0L)
        }
    }

    private fun stopSyncElapsedTicker(durationMs: Long = syncDurationSince(syncStartedAtMillis)): Long {
        val normalizedDuration = durationMs.coerceAtLeast(0L)
        syncElapsedJob?.cancel()
        syncElapsedJob = null
        syncStartedAtMillis = 0L
        _syncStatus.value = _syncStatus.value.copy(
            isSyncing = false,
            elapsedMs = 0L,
            lastDurationMs = normalizedDuration
        )
        return normalizedDuration
    }

    private fun loadSyncHistory(context: Context): List<SyncHistoryEntry> {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SYNC_HISTORY, "") ?: ""
        if (raw.isBlank()) return emptyList()
        return try {
            AppJson.json.decodeFromString(
                ListSerializer(SyncHistoryEntry.serializer()),
                raw
            )
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun saveSyncHistory(context: Context, entries: List<SyncHistoryEntry>) {
        val trimmed = entries.take(30)
        val json = AppJson.json.encodeToString(
            ListSerializer(SyncHistoryEntry.serializer()),
            trimmed
        )
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SYNC_HISTORY, json)
            .apply()
        _syncHistory.value = trimmed
    }

    private fun appendSyncHistory(context: Context, entry: SyncHistoryEntry) {
        saveSyncHistory(context, listOf(entry) + loadSyncHistory(context))
    }

    private fun loadPendingMutations(context: Context): List<CardChangeDetail> {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_PENDING_MUTATIONS, "") ?: ""
        if (raw.isBlank()) return emptyList()
        return try {
            AppJson.json.decodeFromString(
                ListSerializer(CardChangeDetail.serializer()),
                raw
            )
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun savePendingMutations(context: Context, entries: List<CardChangeDetail>) {
        val collapsed = entries
            .groupBy { it.cardId }
            .map { (_, items) -> collapseCardChanges(items) }
            .sortedBy { it.cardName }
        val json = AppJson.json.encodeToString(
            ListSerializer(CardChangeDetail.serializer()),
            collapsed
        )
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_MUTATIONS, json)
            .apply()
    }

    private fun clearPendingMutations(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_PENDING_MUTATIONS)
            .apply()
    }

    private fun recordPendingMutation(context: Context, detail: CardChangeDetail?) {
        if (detail == null) return
        savePendingMutations(context, loadPendingMutations(context) + detail)
    }

    private fun collapseCardChanges(items: List<CardChangeDetail>): CardChangeDetail {
        if (items.any { it.kind == "deleted" }) {
            return items.last { it.kind == "deleted" }
        }
        val first = items.first()
        val last = items.last()
        if (first.kind == "added") {
            return last.copy(kind = "added")
        }
        return last
    }

    private fun diffCards(before: List<SharedCard>, after: List<SharedCard>): List<CardChangeDetail> {
        val beforeById = before.associateBy { it.id }
        val afterById = after.associateBy { it.id }
        val cardIds = (beforeById.keys + afterById.keys).sorted()
        return cardIds.mapNotNull { id ->
            val oldCard = beforeById[id]
            val newCard = afterById[id]
            when {
                oldCard == null && newCard != null -> buildCardChange("added", null, newCard)
                oldCard != null && newCard == null -> buildCardChange("deleted", oldCard, null)
                oldCard != null && newCard != null -> buildCardChange("modified", oldCard, newCard)
                else -> null
            }
        }
    }

    private fun buildCardChange(kind: String, before: SharedCard?, after: SharedCard?): CardChangeDetail? {
        val card = after ?: before ?: return null
        val fields = when (kind) {
            "added" -> snapshotFields(card, isNew = true)
            "deleted" -> snapshotFields(card, isNew = false)
            else -> compareFields(before ?: return null, after ?: return null)
        }
        if (kind == "modified" && fields.isEmpty()) return null
        return CardChangeDetail(
            kind = kind,
            cardId = card.id,
            cardName = cardDisplayName(card),
            fields = fields
        )
    }

    private fun snapshotFields(card: SharedCard, isNew: Boolean): List<FieldChangeDetail> {
        return listOf(
            "卡类别" to cardCategoryText(card),
            "国家 / 地区" to card.country,
            "发卡银行" to card.bank,
            "卡片别名" to card.alias,
            "卡片等级" to card.level,
            "卡号" to maskCardNumber(card.cardNumber),
            "有效期" to card.valid,
            "额度" to "${card.type} ${formatAmount(card.limit)}",
            "结算币种" to card.type,
            "共享额度" to if (card.isSharedLimit) "是" else "否",
            "账单日" to card.accountBillDate,
            "还款日" to card.dueDate,
            "账单日消费计入" to if (card.billingDaySpendingToNextBill) "下期账单" else "当期账单",
            "年费金额" to "${card.type} ${formatAmount(card.annualFee)}",
            "年费状态" to qualificationText(card.isQualified),
            "下次年费收取日" to formatDate(card.nextAnnualFeeCollectionTime),
            "上次提额时间" to formatDate(card.lastTime),
            "权益" to card.equity,
            "备注" to card.remark,
            "卡片图片" to imageCountText(card.cardImages.size)
        ).mapNotNull { (label, value) ->
            if (value.isBlank() || value == "未设置") return@mapNotNull null
            FieldChangeDetail(
                label = label,
                oldValue = if (isNew) "" else formatValue(value),
                newValue = if (isNew) formatValue(value) else ""
            )
        }
    }

    private fun compareFields(before: SharedCard, after: SharedCard): List<FieldChangeDetail> {
        val fields = listOf(
            Triple("卡类别", cardCategoryText(before), cardCategoryText(after)),
            Triple("国家 / 地区", before.country, after.country),
            Triple("发卡银行", before.bank, after.bank),
            Triple("卡片别名", before.alias, after.alias),
            Triple("卡片等级", before.level, after.level),
            Triple("卡号", maskCardNumber(before.cardNumber), maskCardNumber(after.cardNumber)),
            Triple("有效期", before.valid, after.valid),
            Triple("额度", "${before.type} ${formatAmount(before.limit)}", "${after.type} ${formatAmount(after.limit)}"),
            Triple("结算币种", before.type, after.type),
            Triple("共享额度", if (before.isSharedLimit) "是" else "否", if (after.isSharedLimit) "是" else "否"),
            Triple("账单日", before.accountBillDate, after.accountBillDate),
            Triple("还款日", before.dueDate, after.dueDate),
            Triple(
                "账单日消费计入",
                if (before.billingDaySpendingToNextBill) "下期账单" else "当期账单",
                if (after.billingDaySpendingToNextBill) "下期账单" else "当期账单"
            ),
            Triple("年费金额", "${before.type} ${formatAmount(before.annualFee)}", "${after.type} ${formatAmount(after.annualFee)}"),
            Triple("年费状态", qualificationText(before.isQualified), qualificationText(after.isQualified)),
            Triple("下次年费收取日", formatDate(before.nextAnnualFeeCollectionTime), formatDate(after.nextAnnualFeeCollectionTime)),
            Triple("上次提额时间", formatDate(before.lastTime), formatDate(after.lastTime)),
            Triple("权益", before.equity, after.equity),
            Triple("备注", before.remark, after.remark),
            Triple("卡片图片", imageCountText(before.cardImages.size), imageCountText(after.cardImages.size))
        )
        return fields.mapNotNull { (label, oldValue, newValue) ->
            val oldText = formatValue(oldValue)
            val newText = formatValue(newValue)
            if (oldText == newText) null else FieldChangeDetail(label, oldText, newText)
        }
    }

    private fun cardDisplayName(card: SharedCard): String {
        val alias = card.alias.trim()
        val bank = card.bank.trim().ifEmpty { "未知银行" }
        val suffix = maskCardNumber(card.cardNumber)
        return listOf(bank, alias, suffix).filter { it.isNotBlank() && it != "未设置" }.joinToString(" / ")
    }

    private fun cardCategoryText(card: SharedCard): String {
        return if (card.cardCategory == "debit") "储蓄卡" else "信用卡"
    }

    private fun maskCardNumber(value: String): String {
        val digits = value.filter { it.isDigit() }
        if (digits.isBlank()) return "未设置"
        return "**** **** **** ${digits.takeLast(4)}"
    }

    private fun formatAmount(value: Double): String = String.format(Locale.US, "%,.0f", value)

    private fun formatValue(value: String): String = value.trim().ifEmpty { "未设置" }

    private fun formatDurationText(durationMs: Long): String {
        val totalSeconds = ((durationMs.coerceAtLeast(0L) + 999L) / 1000L).coerceAtLeast(0L)
        val minutes = totalSeconds / 60L
        val seconds = totalSeconds % 60L
        val hours = minutes / 60L
        val remainingMinutes = minutes % 60L
        return when {
            hours > 0L -> "${hours}小时${remainingMinutes}分${seconds}秒"
            minutes > 0L -> "${minutes}分${seconds}秒"
            else -> "${seconds}秒"
        }
    }

    private fun qualificationText(value: String): String = when (value) {
        "1" -> "已达标"
        "2" -> "未达标"
        "3" -> "终免年费"
        else -> "未达标"
    }

    private fun formatDate(epochMs: Long?): String {
        if (epochMs == null || epochMs <= 0L) return "未设置"
        return SimpleDateFormat("yyyy-MM-dd", Locale.CHINA).format(Date(epochMs))
    }

    private fun imageCountText(count: Int): String {
        return if (count <= 0) "未设置" else "$count 张"
    }

    private fun loadMergedLocalRecords(db: DatabaseHelper): List<CardSyncRecord> {
        var localRecords = db.getAllSyncRecords()
        if (localRecords.isEmpty()) {
            val existingCards = db.getAllCards()
            if (existingCards.isNotEmpty()) {
                val legacyRecords = existingCards.map { card ->
                    CardSyncRecord(
                        cardId = card.id,
                        changedAt = SyncTime.isoFromMillis(card.lastModifyTime),
                        state = "active",
                        card = card
                    )
                }
                db.saveSyncRecords(legacyRecords)
                localRecords = legacyRecords
            }
        }
        return SyncMergeEngine.merge(localRecords)
    }

    /**
     * 产生一条新增或修改的本地变动，写入本地账本
     */
    fun commitCardChange(context: Context, card: SharedCard) {
        val appContext = context.applicationContext
        val latestCards = synchronized(dbWriteLock) {
            DatabaseHelper(appContext).use { db ->
                val beforeCard = if (card.id.isBlank()) null else db.getCardById(card.id)

                val nowMillis = SyncTime.nowMillis()
                val isoNow = SyncTime.isoFromMillis(nowMillis)
                if (card.id.isBlank()) {
                    card.id = UUID.randomUUID().toString()
                }
                card.cardCategory = if (card.cardCategory == "debit") "debit" else "credit"
                // Web/Mac 端会把 active record 的 lastModifyTime 规范为 changedAt 对应毫秒值。
                card.lastModifyTime = nowMillis

                // 1. 生成并保存本地 active 账本记录
                val record = CardSyncRecord(
                    cardId = card.id,
                    changedAt = isoNow,
                    state = "active",
                    card = card
                )

                db.saveCard(card)
                db.saveSyncRecord(record)
                recordPendingMutation(
                    appContext,
                    buildCardChange(if (beforeCard == null) "added" else "modified", beforeCard, card)
                )
                bumpMutationRevision(appContext)
                markPending(appContext, true)
                db.getAllCards()
            }
        }

        // 刷新主页卡片流
        _cardsFlow.value = latestCards
        requestBackgroundSync(context, publishLocalChanges = true)
    }

    /**
     * 产生一条删除的本地变动，写入本地账本
     */
    fun commitCardDelete(context: Context, cardId: String) {
        val appContext = context.applicationContext
        val latestCards = synchronized(dbWriteLock) {
            DatabaseHelper(appContext).use { db ->
                val beforeCard = db.getCardById(cardId)

                // 1. 生成并保存本地 deleted 账本记录
                val isoNow = SyncTime.nowIso()
                val record = CardSyncRecord(
                    cardId = cardId,
                    changedAt = isoNow,
                    state = "deleted",
                    card = null
                )

                db.deleteCardById(cardId)
                db.saveSyncRecord(record)
                recordPendingMutation(appContext, buildCardChange("deleted", beforeCard, null))
                bumpMutationRevision(appContext)
                markPending(appContext, true)
                db.getAllCards()
            }
        }

        // 刷新主页卡片流
        _cardsFlow.value = latestCards
        requestBackgroundSync(context, publishLocalChanges = true)
    }

    /**
     * 核心双向同步机制（协程挂起函数）
     * @param publishLocalChanges 如果为 true，代表用户手动点击“立即同步”，将强制发布当前数据
     */
    suspend fun synchronize(context: Context, publishLocalChanges: Boolean = false) = withContext(Dispatchers.IO) {
        syncMutex.withLock {
            val appContext = context.applicationContext
            val config = loadConfig(appContext)
            if (!config.isEnabled || config.url.isEmpty()) {
                withContext(Dispatchers.Main) {
                    updateStatus("未开启云同步，已将所有本机改动保存在本地", "info", isPending(appContext))
                    updateProgress("空闲", 0, 0)
                }
                return@withLock
            }
            if (config.syncPassword.isBlank()) {
                withContext(Dispatchers.Main) {
                    updateStatus("请先在 WebDAV 设置中填写同步密钥", "warning", isPending(appContext))
                    updateProgress("等待配置", 0, 0, "缺少同步加密密码")
                }
                return@withLock
            }

            cancelRequested = false
            val startedAtMillis = SyncTime.nowMillis()
            val startedAt = SyncTime.isoFromMillis(startedAtMillis)
            startSyncElapsedTicker(startedAtMillis)
            val pendingLocalChangesAtStart = loadPendingMutations(appContext)
            var localChangesForHistory = pendingLocalChangesAtStart
            var downloadedFilenames = emptyList<String>()
            var uploadedFilename = ""
            var remoteChangeDetails = emptyList<CardChangeDetail>()
            var needsFollowUpSync = false

            withContext(Dispatchers.Main) {
                updateStatus("正在同步云端数据...", "info", isPending(appContext), isSyncing = true, elapsedMs = 0L, lastDurationMs = 0L)
                updateProgress("准备同步", 1, 6, "正在整理本机修改")
            }

            val db = DatabaseHelper(appContext)
            try {
                val localRecordsAtStart = synchronized(dbWriteLock) {
                    loadMergedLocalRecords(db)
                }
                ensureSyncNotCancelled()

                withContext(Dispatchers.Main) {
                    updateProgress("读取云端", 2, 6, "正在查找云同步文件")
                }

                // 2. 从云端拉取备份列表并筛选自动同步文件
                val rawFiles = WebDAVClient.getBackupList(config.url, config.user, config.pass)
                ensureSyncNotCancelled()
                val automaticFiles = rawFiles.filter { file ->
                    file.filename.contains("[SyncV4]") && file.filename.contains("[自]")
                }.sortedWith(compareByDescending<BackupFile> { it.lastModified }.thenByDescending { it.filename })
                // 每份 SyncV4 文件都是完整快照。全新/空本地恢复时先读取最新一份，
                // 避免在移动网络上同时拉取 5 份大文件；已有本地数据时仍合并最近 5 份。
                val snapshotReadLimit = if (
                    localRecordsAtStart.isEmpty() && pendingLocalChangesAtStart.isEmpty()
                ) 1 else MAX_SNAPSHOTS_TO_MERGE
                val filesToRead = automaticFiles.take(snapshotReadLimit)
                val isFreshSingleSnapshotRestore = localRecordsAtStart.isEmpty() &&
                    pendingLocalChangesAtStart.isEmpty() &&
                    filesToRead.size == 1
                downloadedFilenames = filesToRead.map { it.filename }
                val newestFilename = automaticFiles.firstOrNull()?.filename.orEmpty()
                val canSkipSnapshotDownload = !isPending(appContext) &&
                    newestFilename.isNotBlank() &&
                    newestFilename == lastWebDAVSnapshotFilename(appContext)

                val totalFilesText = if (automaticFiles.size > filesToRead.size) {
                    "，云端共有 ${automaticFiles.size} 份，仅读取最近 ${filesToRead.size} 份"
                } else {
                    ""
                }

                if (!publishLocalChanges && automaticFiles.isEmpty()) {
                    appendSyncHistory(
                        appContext,
                        SyncHistoryEntry(
                            id = UUID.randomUUID().toString(),
                            startedAt = startedAt,
                            finishedAt = SyncTime.nowIso(),
                            status = "warning",
                            message = "云端还没有同步文件",
                            durationMs = syncDurationSince(startedAtMillis),
                            downloadedFiles = rawFiles.map { it.filename },
                            localChanges = pendingLocalChangesAtStart
                        )
                    )
                    withContext(Dispatchers.Main) {
                        val durationMs = stopSyncElapsedTicker(syncDurationSince(startedAtMillis))
                        updateStatus("云端还没有新版同步文件，可点击“立即同步”用当前本机数据初始化云同步", "warning", true, lastDurationMs = durationMs)
                        updateProgress("等待初始化", 0, 0, "耗时 ${formatDurationText(durationMs)}；旧版同步文件不会参与本次同步")
                    }
                    return@withLock
                }

                if (canSkipSnapshotDownload) {
                    appendSyncHistory(
                        appContext,
                        SyncHistoryEntry(
                            id = UUID.randomUUID().toString(),
                            startedAt = startedAt,
                            finishedAt = SyncTime.nowIso(),
                            status = "success",
                            message = "云端文件未变化，已跳过下载解析",
                            durationMs = syncDurationSince(startedAtMillis),
                            downloadedFiles = emptyList(),
                            localChanges = emptyList(),
                            remoteChanges = emptyList()
                        )
                    )
                    withContext(Dispatchers.Main) {
                        val durationMs = stopSyncElapsedTicker(syncDurationSince(startedAtMillis))
                        updateStatus("云端文件未变化，已跳过下载解析", "success", false, lastDurationMs = durationMs)
                        updateProgress("同步完成", 6, 6, "耗时 ${formatDurationText(durationMs)}；云端最新文件未变化")
                    }
                    return@withLock
                }

                val totalDownloadBytes = filesToRead.sumOf { it.size.coerceAtLeast(0L) }
                val downloadDetail = if (filesToRead.size == 1) {
                    "正在下载最新云同步快照$totalFilesText，网络慢时会自动续传"
                } else {
                    "正在并发下载 ${filesToRead.size} 份云同步文件$totalFilesText，网络慢时会自动续传"
                }
                val downloadProgressLock = Any()
                var downloadedBytes = 0L
                var lastDownloadProgressReportAt = 0L
                fun reportDownloadDelta(delta: Long, force: Boolean = false) {
                    if (delta == 0L || totalDownloadBytes <= 0L) return
                    val now = SyncTime.nowMillis()
                    val (currentBytes, shouldReport) = synchronized(downloadProgressLock) {
                        downloadedBytes = (downloadedBytes + delta).coerceIn(0L, totalDownloadBytes)
                        val canReport = force ||
                            downloadedBytes >= totalDownloadBytes ||
                            now - lastDownloadProgressReportAt >= PROGRESS_UI_INTERVAL_MS
                        if (canReport) {
                            lastDownloadProgressReportAt = now
                        }
                        downloadedBytes to canReport
                    }
                    if (!shouldReport) return
                    updateProgress(
                        "读取文件",
                        3,
                        6,
                        downloadDetail,
                        totalBytes = totalDownloadBytes,
                        transferredBytes = currentBytes
                    )
                }

                withContext(Dispatchers.Main) {
                    updateProgress(
                        "读取文件",
                        3,
                        6,
                        downloadDetail,
                        totalBytes = totalDownloadBytes,
                        transferredBytes = 0L
                    )
                }

                // 3. 下载并解密选中的自动同步文件。每个文件的下载请求都支持慢网重试
                // 和 Range 续传，避免大文件还在传输时被总时长限制误判失败。
                val readResults = coroutineScope {
                    filesToRead.mapIndexed { index, file ->
                        async(Dispatchers.IO) {
                            ensureSyncNotCancelled()
                            withContext(Dispatchers.Main) {
                                updateProgress(
                                    "读取文件",
                                    3,
                                    6,
                                    if (filesToRead.size == 1) {
                                        "正在读取最新快照：${file.filename}"
                                    } else {
                                        "正在并发读取 ${index + 1}/${filesToRead.size}：${file.filename}"
                                    },
                                    totalBytes = totalDownloadBytes,
                                    transferredBytes = downloadedBytes
                                )
                            }
                            var fileDownloadedBytes = 0L
                            val fileContent = try {
                                WebDAVClient.restoreBackupOrThrow(
                                    config.url,
                                    config.user,
                                    config.pass,
                                    file.filename,
                                    onProgress = { bytesRead ->
                                        val delta = bytesRead - fileDownloadedBytes
                                        fileDownloadedBytes = bytesRead
                                        if (delta != 0L) {
                                            reportDownloadDelta(delta)
                                        }
                                    }
                                )
                            } catch (e: IOException) {
                                if (cancelRequested) throw CancellationException("同步已被手动终止")
                                e.printStackTrace()
                                return@async SnapshotReadResult(
                                    filename = file.filename,
                                    failureStage = "download",
                                    failureMessage = "同步文件下载失败：${e.message ?: "网络超时或连接中断"}"
                                )
                            }
                            ensureSyncNotCancelled()
                            if (fileContent.isEmpty()) {
                                return@async SnapshotReadResult(
                                    filename = file.filename,
                                    failureStage = "download",
                                    failureMessage = "同步文件下载失败：响应为空"
                                )
                            }
                            val remainingBytes = file.size - fileDownloadedBytes
                            if (remainingBytes > 0L) {
                                reportDownloadDelta(remainingBytes, force = true)
                            }
                            val decryptedJson = try {
                                CryptoManager.decryptSyncEnvelopeV4(fileContent, config.syncPassword)
                            } catch (e: Exception) {
                                e.printStackTrace()
                                return@async SnapshotReadResult(
                                    filename = file.filename,
                                    failureStage = "decrypt",
                                    failureMessage = "同步文件无法解密，请检查同步密钥：${file.filename}"
                                )
                            }
                            val snapshot = try {
                                AppJson.json.decodeFromString<SyncSnapshot>(decryptedJson)
                            } catch (e: Exception) {
                                e.printStackTrace()
                                return@async SnapshotReadResult(
                                    filename = file.filename,
                                    failureStage = "parse",
                                    failureMessage = "同步文件已解密但快照格式无法解析：${file.filename}"
                                )
                            }
                            if (snapshot.schemaVersion == "4.0.0") {
                                SnapshotReadResult(filename = file.filename, snapshot = snapshot)
                            } else {
                                SnapshotReadResult(
                                    filename = file.filename,
                                    failureStage = "parse",
                                    failureMessage = "同步文件版本不支持：${file.filename}"
                                )
                            }
                        }
                    }.awaitAll()
                }
                val snapshots = readResults.mapNotNull { it.snapshot }
                val firstResult = readResults.firstOrNull()
                if (filesToRead.isNotEmpty() && firstResult?.failed == true) {
                    throw IllegalArgumentException(firstResult.failureMessage ?: "最新云同步文件读取失败，请稍后重试")
                }
                if (filesToRead.isNotEmpty() && snapshots.isEmpty()) {
                    val failures = readResults.filter { it.failed }
                    val downloadFailures = failures.count { it.failureStage == "download" }
                    val decryptFailures = failures.count { it.failureStage == "decrypt" }
                    val message = when {
                        downloadFailures > 0 -> "云同步文件下载失败，请检查网络或稍后重试"
                        decryptFailures > 0 -> "无法解密云端同步文件，请检查同步密钥"
                        else -> failures.firstOrNull()?.failureMessage ?: "云同步文件格式无法解析"
                    }
                    throw IllegalArgumentException(message)
                }
                val remoteRecords = snapshots.flatMap { it.records }

                withContext(Dispatchers.Main) {
                    updateProgress("合并数据", 4, 6, "正在合并本机和云端修改")
                }

                lateinit var mergedRecords: List<CardSyncRecord>
                lateinit var activeCards: List<SharedCard>
                var changedByRemote = false
                var snapshotRevision = 0L

                // 4/5. 落库前重新读取最新本地账本，防止同步期间新编辑被旧快照覆盖。
                synchronized(dbWriteLock) {
                    val beforeActiveCards = db.getAllCards()
                    val latestLocalRecords = loadMergedLocalRecords(db)
                    mergedRecords = SyncMergeEngine.merge(latestLocalRecords, remoteRecords)
                    changedByRemote = latestLocalRecords != mergedRecords

                    activeCards = SyncMergeEngine.extractActiveCards(mergedRecords)
                    db.replaceSyncedData(mergedRecords, activeCards)
                    remoteChangeDetails = diffCards(beforeActiveCards, activeCards)
                    snapshotRevision = mutationRevision(appContext)
                    localChangesForHistory = loadPendingMutations(appContext)
                }
                ensureSyncNotCancelled()

                withContext(Dispatchers.Main) {
                    updateProgress("保存云端", 5, 6, "检查是否需要把最新内容保存到云端")
                }

                // 6. 是否需要把最新合流数据发布回云端？
                // 空本地首次恢复单个最新快照时只落库，不重复上传同一份完整快照。
                val hasPending = isPending(appContext)
                val shouldUploadMergedSnapshot =
                    hasPending ||
                        (changedByRemote && !isFreshSingleSnapshotRestore) ||
                        (automaticFiles.isEmpty() && mergedRecords.isNotEmpty())
                if (shouldUploadMergedSnapshot) {
                    val isoNow = SyncTime.nowIso()
                    val snapshot = SyncSnapshot(
                        generatedAt = isoNow,
                        records = mergedRecords
                    )
                    val snapshotJson = AppJson.json.encodeToString(SyncSnapshot.serializer(), snapshot)
                    val encryptedSnapshot = CryptoManager.encryptSyncEnvelopeV4(snapshotJson, config.syncPassword)

                    // 将文件名中的冒号与点替换为短横线，确保 WebDAV 磁盘极致兼容
                    val timeFilename = isoNow.replace(":", "-").replace(".", "-")
                    val activeCount = activeCards.size
                    val filename = "${timeFilename}---($activeCount)[SyncV4][Android][自].json"
                    val uploadBytes = encryptedSnapshot.toByteArray(Charsets.UTF_8).size.toLong()

                    ensureSyncNotCancelled()
                    updateProgress(
                        "保存云端",
                        5,
                        6,
                        "正在写入 WebDAV 加密快照",
                        totalBytes = uploadBytes,
                        transferredBytes = 0L
                    )
                    var lastUploadProgressReportAt = 0L
                    val uploadSuccess = WebDAVClient.uploadSyncSnapshot(
                        config.url,
                        config.user,
                        config.pass,
                        filename,
                        encryptedSnapshot,
                        onProgress = { bytesSent ->
                            val currentBytes = bytesSent.coerceIn(0L, uploadBytes)
                            val now = SyncTime.nowMillis()
                            if (currentBytes < uploadBytes && now - lastUploadProgressReportAt < PROGRESS_UI_INTERVAL_MS) {
                                return@uploadSyncSnapshot
                            }
                            lastUploadProgressReportAt = now
                            updateProgress(
                                "保存云端",
                                5,
                                6,
                                "正在写入 WebDAV 加密快照",
                                totalBytes = uploadBytes,
                                transferredBytes = currentBytes
                            )
                        }
                    )
                    ensureSyncNotCancelled()
                    if (uploadSuccess) {
                        uploadedFilename = filename
                        saveLastWebDAVSnapshotFilename(appContext, filename)
                        if (mutationRevision(appContext) == snapshotRevision) {
                            markPending(appContext, false)
                            clearPendingMutations(appContext)
                        } else {
                            needsFollowUpSync = true
                            markPending(appContext, true)
                        }

                        // 7. 冗余文件清理：删除超过 5 个的老自动同步文件
                        val updatedFiles = WebDAVClient.getBackupList(config.url, config.user, config.pass)
                        ensureSyncNotCancelled()
                        val oldAutoFiles = updatedFiles.filter { file ->
                            file.filename.contains("[SyncV4]") && file.filename.contains("[自]")
                        }.sortedWith(compareByDescending<BackupFile> { it.lastModified }.thenByDescending { it.filename })
                        if (oldAutoFiles.size > 5) {
                            val filesToDelete = oldAutoFiles.subList(5, oldAutoFiles.size)
                            coroutineScope {
                                filesToDelete.map { fileDel ->
                                    async(Dispatchers.IO) {
                                        ensureSyncNotCancelled()
                                        WebDAVClient.deleteBackup(config.url, config.user, config.pass, fileDel.filename)
                                    }
                                }.awaitAll()
                            }
                        }
                    } else {
                        throw IOException("云端上传同步文件失败")
                    }
                } else if (mutationRevision(appContext) != snapshotRevision) {
                    needsFollowUpSync = true
                } else if (newestFilename.isNotBlank()) {
                    saveLastWebDAVSnapshotFilename(appContext, newestFilename)
                }

                appendSyncHistory(
                    appContext,
                    SyncHistoryEntry(
                        id = UUID.randomUUID().toString(),
                        startedAt = startedAt,
                        finishedAt = SyncTime.nowIso(),
                        status = "success",
                        message = when {
                            needsFollowUpSync -> "同步成功：同步期间有新修改，正在继续同步"
                            uploadedFilename.isEmpty() && changedByRemote -> "同步成功：云端数据已恢复到本机"
                            else -> "同步成功：本机与云端已更新"
                        },
                        durationMs = syncDurationSince(startedAtMillis),
                        uploadedFile = uploadedFilename,
                        downloadedFiles = downloadedFilenames,
                        localChanges = localChangesForHistory,
                        remoteChanges = remoteChangeDetails
                    )
                )

                // 8. 刷新主页卡片列表流
                val currentCards = synchronized(dbWriteLock) {
                    db.getAllCards()
                }
                withContext(Dispatchers.Main) {
                    val durationMs = stopSyncElapsedTicker(syncDurationSince(startedAtMillis))
                    _cardsFlow.value = currentCards
                    if (needsFollowUpSync) {
                        updateStatus("本次同步完成，检测到期间又有新修改，正在继续同步", "info", true, lastDurationMs = durationMs)
                        updateProgress("继续同步", 6, 6, "本轮耗时 ${formatDurationText(durationMs)}，新修改已保留，将继续发布到云端")
                    } else {
                        updateStatus("云端同步成功，本机已是最新状态", "success", isPending(appContext), lastDurationMs = durationMs)
                        val detail = if (uploadedFilename.isEmpty() && changedByRemote) {
                            "耗时 ${formatDurationText(durationMs)}；已下载云端最新快照"
                        } else {
                            "耗时 ${formatDurationText(durationMs)}；新增 ${remoteChangeDetails.count { it.kind == "added" }}，修改 ${remoteChangeDetails.count { it.kind == "modified" }}，删除 ${remoteChangeDetails.count { it.kind == "deleted" }}"
                        }
                        updateProgress("同步完成", 6, 6, detail)
                    }
                }
                if (needsFollowUpSync) {
                    requestBackgroundSync(appContext, publishLocalChanges = true)
                }

            } catch (e: CancellationException) {
                appendSyncHistory(
                    appContext,
                    SyncHistoryEntry(
                        id = UUID.randomUUID().toString(),
                        startedAt = startedAt,
                        finishedAt = SyncTime.nowIso(),
                        status = "warning",
                        message = "同步已终止：本机未同步修改已保留",
                        durationMs = syncDurationSince(startedAtMillis),
                        uploadedFile = uploadedFilename,
                        downloadedFiles = downloadedFilenames,
                        localChanges = loadPendingMutations(appContext),
                        remoteChanges = remoteChangeDetails
                    )
                )
                withContext(Dispatchers.Main) {
                    val durationMs = stopSyncElapsedTicker(syncDurationSince(startedAtMillis))
                    updateStatus("同步已终止，本机未同步修改已保留", "warning", isPending(appContext), lastDurationMs = durationMs)
                    updateProgress("已终止", 0, 0, "本次已运行 ${formatDurationText(durationMs)}，可重新点击立即同步")
                }
            } catch (e: Exception) {
                if (cancelRequested) {
                    appendSyncHistory(
                        appContext,
                        SyncHistoryEntry(
                            id = UUID.randomUUID().toString(),
                            startedAt = startedAt,
                            finishedAt = SyncTime.nowIso(),
                            status = "warning",
                            message = "同步已终止：本机未同步修改已保留",
                            durationMs = syncDurationSince(startedAtMillis),
                            uploadedFile = uploadedFilename,
                            downloadedFiles = downloadedFilenames,
                            localChanges = loadPendingMutations(appContext),
                            remoteChanges = remoteChangeDetails
                        )
                    )
                    withContext(Dispatchers.Main) {
                        val durationMs = stopSyncElapsedTicker(syncDurationSince(startedAtMillis))
                        updateStatus("同步已终止，本机未同步修改已保留", "warning", isPending(appContext), lastDurationMs = durationMs)
                        updateProgress("已终止", 0, 0, "本次已运行 ${formatDurationText(durationMs)}，可重新点击立即同步")
                    }
                    return@withLock
                }
                e.printStackTrace()
                appendSyncHistory(
                    appContext,
                    SyncHistoryEntry(
                        id = UUID.randomUUID().toString(),
                        startedAt = startedAt,
                        finishedAt = SyncTime.nowIso(),
                        status = "error",
                        message = "同步失败：${e.message ?: "未知错误"}",
                        durationMs = syncDurationSince(startedAtMillis),
                        uploadedFile = uploadedFilename,
                        downloadedFiles = downloadedFilenames,
                        localChanges = loadPendingMutations(appContext).ifEmpty { pendingLocalChangesAtStart },
                        remoteChanges = remoteChangeDetails
                    )
                )
                // 同步失败，保留本地挂起标志，提示用户
                withContext(Dispatchers.Main) {
                    val durationMs = stopSyncElapsedTicker(syncDurationSince(startedAtMillis))
                    updateStatus("同步失败，本机改动已妥善保留，稍后可重试: ${e.message}", "warning", isPending(appContext), lastDurationMs = durationMs)
                    updateProgress("同步失败", 0, 0, "耗时 ${formatDurationText(durationMs)}；${e.message ?: "未知错误"}")
                }
            } finally {
                db.close()
            }
        }
    }

    // ==========================================
    // 内部时间戳格式化辅助方法
    // ==========================================

    fun getIsoTimestamp(): String {
        return SyncTime.nowIso()
    }

    private fun requestBackgroundSync(context: Context, publishLocalChanges: Boolean) {
        val appContext = context.applicationContext
        val config = loadConfig(appContext)
        if (!config.isEnabled || config.url.isBlank()) return
        val shouldLaunch = synchronized(backgroundSyncLock) {
            backgroundSyncPublishLocalChanges = backgroundSyncPublishLocalChanges || publishLocalChanges
            if (backgroundSyncScheduled) {
                false
            } else {
                backgroundSyncScheduled = true
                true
            }
        }
        if (!shouldLaunch) return
        activeSyncJob = syncScope.launch {
            while (true) {
                val shouldPublishLocalChanges = synchronized(backgroundSyncLock) {
                    val current = backgroundSyncPublishLocalChanges
                    backgroundSyncPublishLocalChanges = false
                    current
                }
                synchronize(appContext, publishLocalChanges = shouldPublishLocalChanges)
                val shouldContinue = synchronized(backgroundSyncLock) {
                    if (backgroundSyncPublishLocalChanges) {
                        true
                    } else {
                        backgroundSyncScheduled = false
                        false
                    }
                }
                if (!shouldContinue) break
            }
        }
    }

    fun cancelCurrentSync(context: Context) {
        val appContext = context.applicationContext
        cancelRequested = true
        synchronized(backgroundSyncLock) {
            backgroundSyncPublishLocalChanges = false
            backgroundSyncScheduled = false
        }
        WebDAVClient.cancelAll()
        activeSyncJob?.cancel(CancellationException("用户手动终止同步"))
        val durationMs = stopSyncElapsedTicker()
        updateStatus("同步已终止，本机未同步修改已保留", "warning", isPending(appContext), lastDurationMs = durationMs)
        updateProgress("已终止", 0, 0, "本次已运行 ${formatDurationText(durationMs)}，可重新点击立即同步")
    }

    /**
     * 清空本地所有变动流水记录 (排障运维态)
     */
    suspend fun clearSyncRecords(context: Context) {
        withContext(Dispatchers.IO) {
            val appContext = context.applicationContext
            synchronized(dbWriteLock) {
                DatabaseHelper(appContext).use { db ->
                    db.clearAllSyncRecords()
                }
                clearPendingMutations(appContext)
                markPending(appContext, false)
                bumpMutationRevision(appContext)
            }
            withContext(Dispatchers.Main) {
                updateStatus("本机同步记录已重置", "info", false)
            }
        }
    }

    /**
     * 物理重置本地数据库，将卡片表与流水表清空
     */
    suspend fun resetLocalDatabase(context: Context) {
        withContext(Dispatchers.IO) {
            val appContext = context.applicationContext
            synchronized(dbWriteLock) {
                DatabaseHelper(appContext).use { db ->
                    db.resetDatabase()
                }
                clearPendingMutations(appContext)
                markPending(appContext, false)
                bumpMutationRevision(appContext)
            }
            withContext(Dispatchers.Main) {
                _cardsFlow.value = emptyList()
                updateStatus("已完全重置本地所有卡片数据为白板状态", "info", false)
            }
        }
    }
}
