package com.example.creditcard.utils

import android.content.Context
import com.example.creditcard.data.DatabaseHelper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.math.max

data class AppStorageSnapshot(
    val totalBytes: Long,
    val databaseBytes: Long,
    val inlineImageBytes: Long,
    val legacyImageBytes: Long,
    val orphanLegacyImageBytes: Long,
    val preferenceBytes: Long,
    val cacheBytes: Long,
    val codeCacheBytes: Long,
    val externalCacheBytes: Long,
    val cleanableBytes: Long,
    val privateFileBytes: Long,
    val otherBytes: Long,
    val cardCount: Int,
    val imageCount: Int
)

data class AppStorageCleanupResult(
    val cleanedBytes: Long,
    val deletedFiles: Int
)

object AppStorageManager {
    private const val DATABASE_NAME = "credit_card.db"

    private val knownPreferenceNames = listOf(
        "credit_card_sync_prefs",
        "credit_card_theme_prefs",
        "tool_menu_preferences",
        "credit_card_security_prefs"
    )

    fun inspect(context: Context): AppStorageSnapshot {
        val appContext = context.applicationContext
        val dataDir = File(appContext.applicationInfo.dataDir)
        val databasePath = appContext.getDatabasePath(DATABASE_NAME)
        val databaseBytes = listOf(
            databasePath,
            File(databasePath.absolutePath + "-wal"),
            File(databasePath.absolutePath + "-shm"),
            File(databasePath.absolutePath + "-journal")
        ).sumOf { it.safeSize() }

        val cards = try {
            DatabaseHelper(appContext).use { db -> db.getAllCards() }
        } catch (e: Exception) {
            emptyList()
        }
        val inlineImageBytes = cards.sumOf { card ->
            card.cardImages.sumOf { image -> estimateDataUrlBytes(image.data) }
        }
        val imageCount = cards.sumOf { it.cardImages.size }

        val legacyImageDir = File(appContext.filesDir, "scanned_cards")
        val legacyImageBytes = legacyImageDir.safeSize()
        val activeCardIds = cards.map { it.id }.toSet()
        val orphanLegacyImageBytes = legacyImageDir.listFiles()
            ?.filter { file ->
                file.isFile &&
                    file.extension.equals("jpg", ignoreCase = true) &&
                    file.nameWithoutExtension !in activeCardIds
            }
            ?.sumOf { it.safeSize() } ?: 0L
        val filesBytes = appContext.filesDir.safeSize()
        val privateFileBytes = max(0L, filesBytes - legacyImageBytes)
        val preferenceBytes = File(dataDir, "shared_prefs").safeSize()
        val cacheBytes = appContext.cacheDir.safeSize()
        val codeCacheBytes = appContext.codeCacheDir.safeSize()
        val externalCacheBytes = appContext.externalCacheDirs.sumOf { it?.safeSize() ?: 0L }
        val cleanableBytes = cacheBytes + codeCacheBytes + externalCacheBytes + orphanLegacyImageBytes
        val totalBytes = dataDir.safeSize()
        val knownDiskBytes = databaseBytes + filesBytes + preferenceBytes + cacheBytes + codeCacheBytes
        val otherBytes = max(0L, totalBytes - knownDiskBytes)

        return AppStorageSnapshot(
            totalBytes = totalBytes,
            databaseBytes = databaseBytes,
            inlineImageBytes = inlineImageBytes,
            legacyImageBytes = legacyImageBytes,
            orphanLegacyImageBytes = orphanLegacyImageBytes,
            preferenceBytes = preferenceBytes,
            cacheBytes = cacheBytes,
            codeCacheBytes = codeCacheBytes,
            externalCacheBytes = externalCacheBytes,
            cleanableBytes = cleanableBytes,
            privateFileBytes = privateFileBytes,
            otherBytes = otherBytes,
            cardCount = cards.size,
            imageCount = imageCount
        )
    }

    suspend fun cleanupNonEssentialData(context: Context): AppStorageCleanupResult = withContext(Dispatchers.IO) {
        val appContext = context.applicationContext
        val beforeBytes = inspect(appContext).totalBytes
        var deletedFiles = 0
        var estimatedCleanedBytes = 0L

        fun addDeleted(result: DeleteResult) {
            deletedFiles += result.files
            estimatedCleanedBytes += result.bytes
        }

        addDeleted(appContext.cacheDir.deleteChildrenWithStats())
        addDeleted(appContext.codeCacheDir.deleteChildrenWithStats())
        appContext.externalCacheDirs.forEach { dir ->
            if (dir != null) addDeleted(dir.deleteChildrenWithStats())
        }

        val activeCardIds = try {
            DatabaseHelper(appContext).use { db -> db.getAllCards().map { it.id }.toSet() }
        } catch (e: Exception) {
            emptySet()
        }
        val legacyImageDir = File(appContext.filesDir, "scanned_cards")
        legacyImageDir.listFiles()
            ?.filter { file ->
                file.isFile &&
                    file.extension.equals("jpg", ignoreCase = true) &&
                    file.nameWithoutExtension !in activeCardIds
            }
            ?.forEach { file ->
                addDeleted(file.safeDeleteWithStats())
            }

        val afterBytes = inspect(appContext).totalBytes
        val measuredCleanedBytes = max(0L, beforeBytes - afterBytes)
        AppStorageCleanupResult(
            cleanedBytes = max(measuredCleanedBytes, estimatedCleanedBytes),
            deletedFiles = deletedFiles
        )
    }

    suspend fun resetApplicationData(context: Context) = withContext(Dispatchers.IO) {
        val appContext = context.applicationContext
        val dataDir = File(appContext.applicationInfo.dataDir)

        try {
            DatabaseHelper(appContext).close()
        } catch (e: Exception) {
            // Continue clearing the remaining sandbox data.
        }
        try {
            appContext.deleteDatabase(DATABASE_NAME)
        } catch (e: Exception) {
            // Sidecar cleanup below handles partially deleted databases.
        }

        val databasePath = appContext.getDatabasePath(DATABASE_NAME)
        listOf(
            databasePath,
            File(databasePath.absolutePath + "-wal"),
            File(databasePath.absolutePath + "-shm"),
            File(databasePath.absolutePath + "-journal")
        ).forEach { it.safeDeleteRecursively() }

        knownPreferenceNames.forEach { name ->
            appContext.getSharedPreferences(name, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .commit()
        }
        File(dataDir, "shared_prefs").deleteChildren()
        appContext.filesDir.deleteChildren()
        appContext.cacheDir.deleteChildren()
        appContext.codeCacheDir.deleteChildren()
        File(dataDir, "no_backup").deleteChildren()
        appContext.externalCacheDirs.forEach { it?.deleteChildren() }
        appContext.getExternalFilesDirs(null).forEach { it?.deleteChildren() }
    }

    private fun estimateDataUrlBytes(data: String): Long {
        val base64 = data.substringAfter("base64,", data).trim()
        if (base64.isBlank()) return 0L
        val padding = base64.takeLastWhile { it == '=' }.length
        return max(0L, (base64.length * 3L / 4L) - padding)
    }

    private fun File.safeSize(): Long {
        if (!exists()) return 0L
        if (isFile) return length()
        return listFiles()?.sumOf { it.safeSize() } ?: 0L
    }

    private fun File.deleteChildren() {
        if (!exists() || !isDirectory) return
        listFiles()?.forEach { it.safeDeleteRecursively() }
    }

    private data class DeleteResult(
        val bytes: Long,
        val files: Int
    )

    private fun File.deleteChildrenWithStats(): DeleteResult {
        if (!exists() || !isDirectory) return DeleteResult(0L, 0)
        var bytes = 0L
        var files = 0
        listFiles()?.forEach { file ->
            val result = file.safeDeleteWithStats()
            bytes += result.bytes
            files += result.files
        }
        return DeleteResult(bytes, files)
    }

    private fun File.safeDeleteWithStats(): DeleteResult {
        if (!exists()) return DeleteResult(0L, 0)
        val bytes = safeSize()
        val files = if (isFile) 1 else (listFiles()?.sumOf { if (it.isFile) 1 else it.countFiles() } ?: 0)
        return try {
            if (deleteRecursively()) DeleteResult(bytes, files) else DeleteResult(0L, 0)
        } catch (e: Exception) {
            DeleteResult(0L, 0)
        }
    }

    private fun File.countFiles(): Int {
        if (!exists()) return 0
        if (isFile) return 1
        return listFiles()?.sumOf { it.countFiles() } ?: 0
    }

    private fun File.safeDeleteRecursively() {
        if (!exists()) return
        try {
            deleteRecursively()
        } catch (e: Exception) {
            // Best-effort cleanup; callers refresh state after completion.
        }
    }
}
