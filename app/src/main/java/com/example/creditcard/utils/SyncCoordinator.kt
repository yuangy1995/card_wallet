package com.example.creditcard.utils

import android.content.Context
import com.example.creditcard.data.CardSyncRecord
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.data.SyncSnapshot
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

    // 用 MutableStateFlow 进行全局同步状态发布，Compose 侧可极其优雅地消费它
    private val _syncStatus = MutableStateFlow(SyncStatus())
    val syncStatus: StateFlow<SyncStatus> = _syncStatus

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

    /**
     * 产生一条新增或修改的本地变动，写入本地账本
     */
    fun commitCardChange(context: Context, card: SharedCard) {
        val db = DatabaseHelper(context)
        
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
            }
            return@withLock
        }

        // 防止并发同步冲突
        if (_syncStatus.value.isSyncing) return@withLock
        
        withContext(Dispatchers.Main) {
            updateStatus("正在同步云端数据...", "info", isPending(context), isSyncing = true)
        }

        try {
            val db = DatabaseHelper(context)
            
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

            // 2. 从云端拉取备份列表并筛选自动同步文件
            val rawFiles = WebDAVClient.getBackupList(config.url, config.user, config.pass)
            val automaticFiles = rawFiles.filter { file ->
                file.filename.contains("[SyncV3]") && file.filename.contains("[自]")
            }

            // 特殊防丢数据警告：如果用户开启同步但云端是第一次设置且没有任何自动备份，但有非自动的其他历史备份
            if (!publishLocalChanges && automaticFiles.isEmpty() && rawFiles.isNotEmpty()) {
                withContext(Dispatchers.Main) {
                    updateStatus("检测到历史备份：请在设置里先完成恢复，或点击“立即同步”覆盖发布当前数据", "warning", true)
                }
                return@withLock
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
                    markPending(context, false)
                    
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

            // 8. 刷新主页卡片列表流
            withContext(Dispatchers.Main) {
                _cardsFlow.value = db.getAllCards()
                updateStatus("云端数据同步成功，本地已是最新状态", "success", isPending(context))
            }

        } catch (e: Exception) {
            e.printStackTrace()
            // 同步失败，保留本地挂起标志，提示用户
            withContext(Dispatchers.Main) {
                updateStatus("同步失败，本机改动已妥善保留，稍后可重试: ${e.message}", "warning", true)
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
            withContext(Dispatchers.Main) {
                _cardsFlow.value = emptyList()
                updateStatus("已完全重置本地所有卡片数据为白板状态", "info", false)
            }
        }
    }
}
