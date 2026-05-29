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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
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
    val isEnabled: Boolean = false
)

/**
 * 同步状态信息
 */
data class SyncStatus(
    val message: String = "未配置云同步，卡片数据将保存在本地",
    val type: String = "info", // "info", "success", "warning", "error"
    val isSyncing: Boolean = false,
    val pending: Boolean = false
)

data class SyncProgress(
    val phase: String = "空闲",
    val step: Int = 0,
    val total: Int = 0,
    val detail: String = ""
)

/**
 * 云端同步协调器
 * 负责本地 SQLite 与云端 WebDAV 的 CRDT 合流同步核心业务调度
 */
object SyncCoordinator {

    private const val PREFS_NAME = "credit_card_sync_prefs"
    private const val KEY_URL = "webdav_url"
    private const val KEY_USER = "webdav_user"
    private const val KEY_PASS = "webdav_pass"
    private const val KEY_ENABLED = "webdav_enabled"
    private const val KEY_PENDING = "sync_pending"
    private const val KEY_SYNC_HISTORY = "sync_history"
    private const val KEY_PENDING_MUTATIONS = "pending_mutation_details"

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

    /**
     * 加载本地缓存好的卡包数据，作为应用启动的主入口数据源
     */
    fun initLocalData(context: Context) {
        val db = DatabaseHelper(context)
        _cardsFlow.value = db.getAllCards()
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
        
        // 自动还原保存的密码
        val pass = if (encryptedPass.isNotEmpty()) {
            try {
                CryptoManager.decrypt(encryptedPass)
            } catch (e: Exception) {
                ""
            }
        } else ""

        val isEnabled = prefs.getBoolean(KEY_ENABLED, false)
        return WebDAVConfig(url, user, pass, isEnabled)
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

    private fun updateStatus(msg: String, type: String, pending: Boolean, isSyncing: Boolean = false) {
        _syncStatus.value = SyncStatus(msg, type, isSyncing, pending)
    }

    private fun updateProgress(phase: String, step: Int, total: Int, detail: String = "") {
        _syncProgress.value = SyncProgress(phase, step, total, detail)
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

    private fun maskCardNumber(value: String): String {
        val digits = value.filter { it.isDigit() }
        if (digits.isBlank()) return "未设置"
        return "**** **** **** ${digits.takeLast(4)}"
    }

    private fun formatAmount(value: Double): String = String.format(Locale.US, "%,.0f", value)

    private fun formatValue(value: String): String = value.trim().ifEmpty { "未设置" }

    private fun qualificationText(value: String): String = when (value) {
        "1" -> "已达标"
        "2" -> "未达标"
        "3" -> "终身免年费"
        else -> "未达标"
    }

    private fun formatDate(epochMs: Long?): String {
        if (epochMs == null || epochMs <= 0L) return "未设置"
        return SimpleDateFormat("yyyy-MM-dd", Locale.CHINA).format(Date(epochMs))
    }

    private fun imageCountText(count: Int): String {
        return if (count <= 0) "未设置" else "$count 张"
    }

    /**
     * 产生一条新增或修改的本地变动，写入本地账本
     */
    fun commitCardChange(context: Context, card: SharedCard) {
        val db = DatabaseHelper(context)
        val beforeCard = if (card.id.isBlank()) null else db.getCardById(card.id)
        
        val nowMillis = SyncTime.nowMillis()
        val isoNow = SyncTime.isoFromMillis(nowMillis)
        if (card.id.isBlank()) {
            card.id = UUID.randomUUID().toString()
        }
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
            context,
            buildCardChange(if (beforeCard == null) "added" else "modified", beforeCard, card)
        )
        markPending(context, true)
        
        // 刷新主页卡片流
        _cardsFlow.value = db.getAllCards()
        requestBackgroundSync(context, publishLocalChanges = true)
    }

    /**
     * 产生一条删除的本地变动，写入本地账本
     */
    fun commitCardDelete(context: Context, cardId: String) {
        val db = DatabaseHelper(context)
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
        recordPendingMutation(context, buildCardChange("deleted", beforeCard, null))
        markPending(context, true)
        
        // 刷新主页卡片流
        _cardsFlow.value = db.getAllCards()
        requestBackgroundSync(context, publishLocalChanges = true)
    }

    /**
     * 核心双向同步机制（协程挂起函数）
     * @param publishLocalChanges 如果为 true，代表用户手动点击“立即同步”，将强制发布当前数据
     */
    suspend fun synchronize(context: Context, publishLocalChanges: Boolean = false) = withContext(Dispatchers.IO) {
        syncMutex.withLock {
            val config = loadConfig(context)
            if (!config.isEnabled || config.url.isEmpty()) {
                withContext(Dispatchers.Main) {
                    updateStatus("未开启云同步，已将所有本机改动保存在本地", "info", isPending(context))
                    updateProgress("空闲", 0, 0)
                }
                return@withLock
            }

            // 防止并发同步冲突
            if (_syncStatus.value.isSyncing) return@withLock

            val startedAt = SyncTime.nowIso()
            val pendingLocalChangesAtStart = loadPendingMutations(context)
            var downloadedFilenames = emptyList<String>()
            var uploadedFilename = ""
            var remoteChangeDetails = emptyList<CardChangeDetail>()

            withContext(Dispatchers.Main) {
                updateStatus("正在同步云端数据...", "info", isPending(context), isSyncing = true)
                updateProgress("准备同步", 1, 6, "读取本地账本与待上传变更")
            }

            try {
                val db = DatabaseHelper(context)
                val beforeActiveCards = db.getAllCards()

                // 1. 读取本地所有变动记录
                var localRecords = db.getAllSyncRecords()

                // 极致容错：如果本地账本为空，但 cards 快照表有历史数据（可能是老版本迁移而来），自动生成 legacyRecords 写入账本
                if (localRecords.isEmpty()) {
                    val existingCards = db.getAllCards()
                    if (existingCards.isNotEmpty()) {
                        val legacyRecs = existingCards.map { card ->
                            val modifiedIso = SyncTime.isoFromMillis(card.lastModifyTime)
                            CardSyncRecord(
                                cardId = card.id,
                                changedAt = modifiedIso,
                                state = "active",
                                card = card
                            )
                        }
                        db.saveSyncRecords(legacyRecs)
                        localRecords = legacyRecs
                    }
                }
                localRecords = SyncMergeEngine.merge(localRecords)

                withContext(Dispatchers.Main) {
                    updateProgress("拉取云端", 2, 6, "正在读取 WebDAV 自动同步快照列表")
                }

                // 2. 从云端拉取备份列表并筛选自动同步文件
                val rawFiles = WebDAVClient.getBackupList(config.url, config.user, config.pass)
                val automaticFiles = rawFiles.filter { file ->
                    file.filename.contains("[SyncV3]") && file.filename.contains("[自]")
                }
                downloadedFilenames = automaticFiles.map { it.filename }

                // 特殊防丢数据警告：如果用户开启同步但云端是第一次设置且没有任何自动备份，但有非自动的其他历史备份
                if (!publishLocalChanges && automaticFiles.isEmpty() && rawFiles.isNotEmpty()) {
                    appendSyncHistory(
                        context,
                        SyncHistoryEntry(
                            id = UUID.randomUUID().toString(),
                            startedAt = startedAt,
                            finishedAt = SyncTime.nowIso(),
                            status = "warning",
                            message = "检测到历史备份，未自动覆盖本地数据",
                            downloadedFiles = rawFiles.map { it.filename },
                            localChanges = pendingLocalChangesAtStart
                        )
                    )
                    withContext(Dispatchers.Main) {
                        updateStatus("检测到历史备份：请在设置里先完成恢复，或点击“立即同步”覆盖发布当前数据", "warning", true)
                        updateProgress("已暂停", 0, 0, "发现非自动历史备份，需要人工确认")
                    }
                    return@withLock
                }

                withContext(Dispatchers.Main) {
                    updateProgress("解密快照", 3, 6, "正在下载并解析 ${automaticFiles.size} 个自动同步快照")
                }

                // 3. 下载并解密所有自动同步备份
                val remoteRecords = ArrayList<CardSyncRecord>()
                for (file in automaticFiles) {
                    val fileContent = WebDAVClient.restoreBackup(config.url, config.user, config.pass, file.filename)
                    if (!fileContent.isNullOrEmpty()) {
                        try {
                            val decryptedJson = CryptoManager.decrypt(fileContent)
                            val snapshot = AppJson.json.decodeFromString<SyncSnapshot>(decryptedJson)
                            if (snapshot.schemaVersion == "3.0.0") {
                                remoteRecords.addAll(snapshot.records)
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }

                withContext(Dispatchers.Main) {
                    updateProgress("合并数据", 4, 6, "正在执行 LWW-CRDT 双向合流")
                }

                // 4. 执行 CRDT 双向无冲突合流
                val mergedRecords = SyncMergeEngine.merge(localRecords, remoteRecords)

                // 比对合并前后的数据是否有更新
                val changedByRemote = localRecords != mergedRecords

                // 5. 写入本地 SQLite 快照和变动账本
                db.clearAllCards()
                db.clearAllSyncRecords()
                db.saveSyncRecords(mergedRecords)
                val activeCards = SyncMergeEngine.extractActiveCards(mergedRecords)
                for (card in activeCards) {
                    db.saveCard(card)
                }
                remoteChangeDetails = diffCards(beforeActiveCards, activeCards)

                withContext(Dispatchers.Main) {
                    updateProgress("发布快照", 5, 6, "检查是否需要上传最新合流结果")
                }

                // 6. 是否需要把最新合流数据发布回云端？
                // 如果本地有 pending、或者有远程合流变动、或者云端没有任何自动快照但本地有卡包
                val hasPending = isPending(context)
                if (publishLocalChanges || changedByRemote || hasPending || (automaticFiles.isEmpty() && mergedRecords.isNotEmpty())) {
                    val isoNow = SyncTime.nowIso()
                    val snapshot = SyncSnapshot(
                        generatedAt = isoNow,
                        records = mergedRecords
                    )
                    val snapshotJson = AppJson.json.encodeToString(SyncSnapshot.serializer(), snapshot)
                    val encryptedSnapshot = CryptoManager.encrypt(snapshotJson)

                    // 将文件名中的冒号与点替换为短横线，确保 WebDAV 磁盘极致兼容
                    val timeFilename = isoNow.replace(":", "-").replace(".", "-")
                    val activeCount = activeCards.size
                    val filename = "${timeFilename}---($activeCount)[SyncV3][Android][自].json"

                    val uploadSuccess = WebDAVClient.uploadSyncSnapshot(config.url, config.user, config.pass, filename, encryptedSnapshot)
                    if (uploadSuccess) {
                        uploadedFilename = filename
                        markPending(context, false)
                        clearPendingMutations(context)

                        // 7. 冗余备份清理：删除超过 5 个的老自动同步备份文件
                        val updatedFiles = WebDAVClient.getBackupList(config.url, config.user, config.pass)
                        val oldAutoFiles = updatedFiles.filter { file ->
                            file.filename.contains("[SyncV3]") && file.filename.contains("[自]")
                        }.sortedWith(compareByDescending<BackupFile> { it.lastModified }.thenByDescending { it.filename })
                        if (oldAutoFiles.size > 5) {
                            val filesToDelete = oldAutoFiles.subList(5, oldAutoFiles.size)
                            for (fileDel in filesToDelete) {
                                WebDAVClient.deleteBackup(config.url, config.user, config.pass, fileDel.filename)
                            }
                        }
                    } else {
                        throw IOException("云端上传备份失败")
                    }
                }

                appendSyncHistory(
                    context,
                    SyncHistoryEntry(
                        id = UUID.randomUUID().toString(),
                        startedAt = startedAt,
                        finishedAt = SyncTime.nowIso(),
                        status = "success",
                        message = "同步成功：本地与云端已合流",
                        uploadedFile = uploadedFilename,
                        downloadedFiles = downloadedFilenames,
                        localChanges = pendingLocalChangesAtStart,
                        remoteChanges = remoteChangeDetails
                    )
                )

                // 8. 刷新主页卡片列表流
                withContext(Dispatchers.Main) {
                    _cardsFlow.value = db.getAllCards()
                    updateStatus("云端数据同步成功，本地已是最新状态", "success", isPending(context))
                    updateProgress("同步完成", 6, 6, "新增 ${remoteChangeDetails.count { it.kind == "added" }}，修改 ${remoteChangeDetails.count { it.kind == "modified" }}，删除 ${remoteChangeDetails.count { it.kind == "deleted" }}")
                }

            } catch (e: Exception) {
                e.printStackTrace()
                appendSyncHistory(
                    context,
                    SyncHistoryEntry(
                        id = UUID.randomUUID().toString(),
                        startedAt = startedAt,
                        finishedAt = SyncTime.nowIso(),
                        status = "error",
                        message = "同步失败：${e.message ?: "未知错误"}",
                        uploadedFile = uploadedFilename,
                        downloadedFiles = downloadedFilenames,
                        localChanges = pendingLocalChangesAtStart,
                        remoteChanges = remoteChangeDetails
                    )
                )
                // 同步失败，保留本地挂起标志，提示用户
                withContext(Dispatchers.Main) {
                    updateStatus("同步失败，本机改动已妥善保留，稍后可重试: ${e.message}", "warning", true)
                    updateProgress("同步失败", 0, 0, e.message ?: "未知错误")
                }
            }
        }
    }

    // ==========================================
    // 内部时间戳格式化辅助方法
    // ==========================================

    fun getIsoTimestamp(): String {
        return SyncTime.nowIso()
    }

    private fun formatEpochToIso(epochMs: Long): String {
        return SyncTime.isoFromMillis(epochMs)
    }

    private fun requestBackgroundSync(context: Context, publishLocalChanges: Boolean) {
        val appContext = context.applicationContext
        val config = loadConfig(appContext)
        if (!config.isEnabled || config.url.isBlank()) return
        syncScope.launch {
            synchronize(appContext, publishLocalChanges = publishLocalChanges)
        }
    }

    /**
     * 清空本地所有变动流水记录 (排障运维态)
     */
    suspend fun clearSyncRecords(context: Context) {
        withContext(Dispatchers.IO) {
            val db = DatabaseHelper(context.applicationContext)
            db.clearAllSyncRecords()
            clearPendingMutations(context.applicationContext)
            markPending(context.applicationContext, false)
            withContext(Dispatchers.Main) {
                updateStatus("本地变动账本流水已全部成功重置为初始态", "info", false)
            }
        }
    }

    /**
     * 物理重置本地数据库，将卡片表与流水表清空
     */
    suspend fun resetLocalDatabase(context: Context) {
        withContext(Dispatchers.IO) {
            val db = DatabaseHelper(context.applicationContext)
            db.resetDatabase()
            clearPendingMutations(context.applicationContext)
            markPending(context.applicationContext, false)
            withContext(Dispatchers.Main) {
                _cardsFlow.value = emptyList()
                updateStatus("已完全重置本地所有卡片数据为白板状态", "info", false)
            }
        }
    }
}
