package com.example.creditcard.data

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * 云端新版同步快照数据模型
 */
@Serializable
data class SyncSnapshot(
    val schemaVersion: String = "4.0.0",
    val snapshotId: String = UUID.randomUUID().toString(),
    val generatedAt: String, // ISO 8601 时间戳
    val source: String = "android",
    val records: List<CardSyncRecord>
)

@Serializable
data class SyncEncryptionMetadata(
    val version: Int = 1,
    val algorithm: String = "AES-256-GCM",
    val kdf: String = "PBKDF2-HMAC-SHA256",
    val iterations: Int = 310000,
    val salt: String,
    val iv: String
)

@Serializable
data class SyncEncryptedEnvelope(
    val schemaVersion: String = "4.0.0",
    val encryption: SyncEncryptionMetadata,
    val ciphertext: String
)
