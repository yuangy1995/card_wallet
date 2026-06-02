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
    val preferenceBytes: Long,
    val cacheBytes: Long,
    val privateFileBytes: Long,
    val otherBytes: Long,
    val cardCount: Int,
    val imageCount: Int
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
        val filesBytes = appContext.filesDir.safeSize()
        val privateFileBytes = max(0L, filesBytes - legacyImageBytes)
        val preferenceBytes = File(dataDir, "shared_prefs").safeSize()
        val cacheBytes = appContext.cacheDir.safeSize()
        val totalBytes = dataDir.safeSize()
        val knownDiskBytes = databaseBytes + filesBytes + preferenceBytes + cacheBytes
        val otherBytes = max(0L, totalBytes - knownDiskBytes)

        return AppStorageSnapshot(
            totalBytes = totalBytes,
            databaseBytes = databaseBytes,
            inlineImageBytes = inlineImageBytes,
            legacyImageBytes = legacyImageBytes,
            preferenceBytes = preferenceBytes,
            cacheBytes = cacheBytes,
            privateFileBytes = privateFileBytes,
            otherBytes = otherBytes,
            cardCount = cards.size,
            imageCount = imageCount
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

    private fun File.safeDeleteRecursively() {
        if (!exists()) return
        try {
            deleteRecursively()
        } catch (e: Exception) {
            // Best-effort cleanup; callers refresh state after completion.
        }
    }
}
