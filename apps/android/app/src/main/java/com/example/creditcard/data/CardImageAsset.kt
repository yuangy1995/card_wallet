package com.example.creditcard.data

import kotlinx.serialization.*
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.*
import kotlinx.serialization.json.*
import java.util.UUID

@Serializable(with = CardImageAssetSerializer::class)
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
,
    @Transient val extraFields: Map<String, JsonElement> = emptyMap()
)

@Serializable
private data class CardImageAssetFields(
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

object CardImageAssetSerializer : KSerializer<CardImageAsset> {
    override val descriptor: SerialDescriptor = CardImageAssetFields.serializer().descriptor
    private val known = setOf("id", "mimeType", "data", "createdAt", "source", "name")
    override fun deserialize(decoder: Decoder): CardImageAsset {
        val input = decoder as? JsonDecoder ?: throw SerializationException("Card JSON required")
        val all = input.decodeJsonElement().jsonObject
        val fields = input.json.decodeFromJsonElement(CardImageAssetFields.serializer(), JsonObject(all.filterKeys { it in known }))
        return CardImageAsset(
            id = fields.id,
            mimeType = fields.mimeType,
            data = fields.data,
            createdAt = fields.createdAt,
            source = fields.source,
            name = fields.name,
            extraFields = all.filterKeys { it !in known && CardFutureFields.allowed(it) }
        )
    }
    override fun serialize(encoder: Encoder, value: CardImageAsset) {
        val output = encoder as? JsonEncoder ?: throw SerializationException("Card JSON required")
        val fields = CardImageAssetFields(
            id = value.id,
            mimeType = value.mimeType,
            data = value.data,
            createdAt = value.createdAt,
            source = value.source,
            name = value.name
        )
        val serialized = output.json.encodeToJsonElement(CardImageAssetFields.serializer(), fields).jsonObject
        output.encodeJsonElement(JsonObject(value.extraFields.filterKeys { it !in known && CardFutureFields.allowed(it) } + serialized))
    }
}
