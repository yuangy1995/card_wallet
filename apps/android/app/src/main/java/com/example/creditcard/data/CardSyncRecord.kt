package com.example.creditcard.data

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * 变动账本记录模型，对应云端同步记录
 */
@Serializable
data class CardSyncRecord(
    val cardId: String,
    val mutationId: String = UUID.randomUUID().toString(),
    val changedAt: String, // ISO 8601 格式时间戳
    val state: String, // "active" 或 "deleted"
    val card: SharedCard? = null
)
