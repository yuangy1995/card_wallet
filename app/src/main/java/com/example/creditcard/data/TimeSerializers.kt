package com.example.creditcard.data

import com.example.creditcard.utils.SyncTime
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.longOrNull

object EpochMillisSerializer : KSerializer<Long> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("EpochMillis", PrimitiveKind.LONG)

    override fun deserialize(decoder: Decoder): Long {
        val decoded = decodeMillis(decoder)
        return decoded ?: SyncTime.nowMillis()
    }

    override fun serialize(encoder: Encoder, value: Long) {
        encoder.encodeLong(value)
    }
}

object NullableEpochMillisSerializer : KSerializer<Long?> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("NullableEpochMillis", PrimitiveKind.LONG)

    override fun deserialize(decoder: Decoder): Long? {
        return decodeMillis(decoder)
    }

    @OptIn(ExperimentalSerializationApi::class)
    override fun serialize(encoder: Encoder, value: Long?) {
        if (value == null) {
            encoder.encodeNull()
        } else {
            encoder.encodeLong(value)
        }
    }
}

private fun decodeMillis(decoder: Decoder): Long? {
    if (decoder is JsonDecoder) {
        val element = decoder.decodeJsonElement()
        if (element is JsonNull) return null
        val primitive = element as? JsonPrimitive ?: return null
        primitive.longOrNull?.let { return SyncTime.normalizeNumericTimestamp(it.toDouble()) }
        primitive.doubleOrNull?.let { return SyncTime.normalizeNumericTimestamp(it) }
        return SyncTime.parseMillis(primitive.content)
    }
    return SyncTime.normalizeNumericTimestamp(decoder.decodeLong().toDouble())
}
