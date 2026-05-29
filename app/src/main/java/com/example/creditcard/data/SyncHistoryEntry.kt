package com.example.creditcard.data

import kotlinx.serialization.Serializable

@Serializable
data class FieldChangeDetail(
    val label: String,
    val oldValue: String,
    val newValue: String
)

@Serializable
data class CardChangeDetail(
    val kind: String,
    val cardId: String,
    val cardName: String,
    val fields: List<FieldChangeDetail> = emptyList()
)

@Serializable
data class SyncHistoryEntry(
    val id: String,
    val startedAt: String,
    val finishedAt: String,
    val status: String,
    val message: String,
    val uploadedFile: String = "",
    val downloadedFiles: List<String> = emptyList(),
    val localChanges: List<CardChangeDetail> = emptyList(),
    val remoteChanges: List<CardChangeDetail> = emptyList()
)
