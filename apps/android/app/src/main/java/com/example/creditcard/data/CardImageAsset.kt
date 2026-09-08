package com.example.creditcard.data

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class CardImageAsset(
    @Serializable(with = FlexibleStringSerializer::class)
    val id: String = UUID.randomUUID().toString(),
    @Serializable(with = FlexibleStringSerializer::class)
    val mimeType: String = "image/jpeg",
    @Serializable(with = FlexibleStringSerializer::class)
    val data: String = "",
    @Serializable(with = FlexibleLongSerializer::class)
    val createdAt: Long = System.currentTimeMillis(),
    @Serializable(with = FlexibleStringSerializer::class)
    val source: String = "manual",
    @Serializable(with = FlexibleStringSerializer::class)
    val name: String = ""
)
