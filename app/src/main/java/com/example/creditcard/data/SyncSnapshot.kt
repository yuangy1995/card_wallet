package com.example.creditcard.data

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * 云端 V3 同步快照数据模型
 */
@Serializable
data class SyncSnapshot(
    val schemaVersion: String = "3.0.0",
    val snapshotId: String = UUID.randomUUID().toString(),
    val generatedAt: String, // ISO 8601 时间戳
    val source: String = "android",
    val records: List<CardSyncRecord>
)
