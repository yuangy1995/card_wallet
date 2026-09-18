package com.example.creditcard.data

import kotlinx.serialization.*
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.*
import kotlinx.serialization.json.*
import java.util.UUID

/**
 * 共享银行卡数据模型（与 Web/Mac 端 DEFAULT_CARD_DATA 100% 对齐）
 */
@Serializable(with = SharedCardSerializer::class)
data class SharedCard(
    @Serializable(with = FlexibleStringSerializer::class)
    var id: String = UUID.randomUUID().toString(),
    @Serializable(with = FlexibleStringSerializer::class)
    var cardCategory: String = "credit", // "credit": 信用卡，"debit": 储蓄卡
    @Serializable(with = FlexibleStringSerializer::class)
    var country: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var bank: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var alias: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var level: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var cardNumber: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var cvv: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var valid: String = "", // MM/YY 格式
    @Serializable(with = FlexibleDoubleSerializer::class)
    var limit: Double = 0.0,
    @Serializable(with = FlexibleStringSerializer::class)
    var type: String = "",
    @Serializable(with = FlexibleBooleanSerializer::class)
    var isSharedLimit: Boolean = true,
    @Serializable(with = FlexibleStringSerializer::class)
    var accountBillDate: String = "", // 1-31 的字符串
    @Serializable(with = FlexibleStringSerializer::class)
    var dueDate: String = "", // 1-31 的字符串
    @Serializable(with = FlexibleBooleanSerializer::class)
    var billingDaySpendingToNextBill: Boolean = true,
    @Serializable(with = FlexibleDoubleSerializer::class)
    var annualFee: Double = 0.0,
    @Serializable(with = FlexibleStringSerializer::class)
    var isQualified: String = "2", // "1": 已达标, "2": 未达标, "3": 免年费
    @Serializable(with = NullableEpochMillisSerializer::class)
    var nextAnnualFeeCollectionTime: Long? = null,
    @Serializable(with = NullableEpochMillisSerializer::class)
    var lastTime: Long? = null,
    @Serializable(with = EpochMillisSerializer::class)
    var lastModifyTime: Long = System.currentTimeMillis(),
    @Serializable(with = FlexibleStringSerializer::class)
    var equity: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var remark: String = "",
    var cardImages: List<CardImageAsset> = emptyList(),
    @Transient var extraFields: Map<String, JsonElement> = emptyMap()
)

@Serializable
private data class SharedCardFields(
    @Serializable(with = FlexibleStringSerializer::class)
    var id: String = UUID.randomUUID().toString(),
    @Serializable(with = FlexibleStringSerializer::class)
    var cardCategory: String = "credit", // "credit": 信用卡，"debit": 储蓄卡
    @Serializable(with = FlexibleStringSerializer::class)
    var country: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var bank: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var alias: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var level: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var cardNumber: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var cvv: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var valid: String = "", // MM/YY 格式
    @Serializable(with = FlexibleDoubleSerializer::class)
    var limit: Double = 0.0,
    @Serializable(with = FlexibleStringSerializer::class)
    var type: String = "",
    @Serializable(with = FlexibleBooleanSerializer::class)
    var isSharedLimit: Boolean = true,
    @Serializable(with = FlexibleStringSerializer::class)
    var accountBillDate: String = "", // 1-31 的字符串
    @Serializable(with = FlexibleStringSerializer::class)
    var dueDate: String = "", // 1-31 的字符串
    @Serializable(with = FlexibleBooleanSerializer::class)
    var billingDaySpendingToNextBill: Boolean = true,
    @Serializable(with = FlexibleDoubleSerializer::class)
    var annualFee: Double = 0.0,
    @Serializable(with = FlexibleStringSerializer::class)
    var isQualified: String = "2", // "1": 已达标, "2": 未达标, "3": 免年费
    @Serializable(with = NullableEpochMillisSerializer::class)
    var nextAnnualFeeCollectionTime: Long? = null,
    @Serializable(with = NullableEpochMillisSerializer::class)
    var lastTime: Long? = null,
    @Serializable(with = EpochMillisSerializer::class)
    var lastModifyTime: Long = System.currentTimeMillis(),
    @Serializable(with = FlexibleStringSerializer::class)
    var equity: String = "",
    @Serializable(with = FlexibleStringSerializer::class)
    var remark: String = "",
    var cardImages: List<CardImageAsset> = emptyList()
)

object SharedCardSerializer : KSerializer<SharedCard> {
    override val descriptor: SerialDescriptor = SharedCardFields.serializer().descriptor
    private val known = setOf("id", "cardCategory", "country", "bank", "alias", "level", "cardNumber", "cvv", "valid", "limit", "type", "isSharedLimit", "accountBillDate", "dueDate", "billingDaySpendingToNextBill", "annualFee", "isQualified", "nextAnnualFeeCollectionTime", "lastTime", "lastModifyTime", "equity", "remark", "cardImages")
    override fun deserialize(decoder: Decoder): SharedCard {
        val input = decoder as? JsonDecoder ?: throw SerializationException("Card JSON required")
        val all = input.decodeJsonElement().jsonObject
        val fields = input.json.decodeFromJsonElement(SharedCardFields.serializer(), JsonObject(all.filterKeys { it in known }))
        return SharedCard(
            id = fields.id,
            cardCategory = fields.cardCategory,
            country = fields.country,
            bank = fields.bank,
            alias = fields.alias,
            level = fields.level,
            cardNumber = fields.cardNumber,
            cvv = fields.cvv,
            valid = fields.valid,
            limit = fields.limit,
            type = fields.type,
            isSharedLimit = fields.isSharedLimit,
            accountBillDate = fields.accountBillDate,
            dueDate = fields.dueDate,
            billingDaySpendingToNextBill = fields.billingDaySpendingToNextBill,
            annualFee = fields.annualFee,
            isQualified = fields.isQualified,
            nextAnnualFeeCollectionTime = fields.nextAnnualFeeCollectionTime,
            lastTime = fields.lastTime,
            lastModifyTime = fields.lastModifyTime,
            equity = fields.equity,
            remark = fields.remark,
            cardImages = fields.cardImages,
            extraFields = all.filterKeys { it !in known && CardFutureFields.allowed(it) }
        )
    }
    override fun serialize(encoder: Encoder, value: SharedCard) {
        val output = encoder as? JsonEncoder ?: throw SerializationException("Card JSON required")
        val fields = SharedCardFields(
            id = value.id,
            cardCategory = value.cardCategory,
            country = value.country,
            bank = value.bank,
            alias = value.alias,
            level = value.level,
            cardNumber = value.cardNumber,
            cvv = value.cvv,
            valid = value.valid,
            limit = value.limit,
            type = value.type,
            isSharedLimit = value.isSharedLimit,
            accountBillDate = value.accountBillDate,
            dueDate = value.dueDate,
            billingDaySpendingToNextBill = value.billingDaySpendingToNextBill,
            annualFee = value.annualFee,
            isQualified = value.isQualified,
            nextAnnualFeeCollectionTime = value.nextAnnualFeeCollectionTime,
            lastTime = value.lastTime,
            lastModifyTime = value.lastModifyTime,
            equity = value.equity,
            remark = value.remark,
            cardImages = value.cardImages
        )
        val serialized = output.json.encodeToJsonElement(SharedCardFields.serializer(), fields).jsonObject
        output.encodeJsonElement(JsonObject(value.extraFields.filterKeys { it !in known && CardFutureFields.allowed(it) } + serialized))
    }
}
