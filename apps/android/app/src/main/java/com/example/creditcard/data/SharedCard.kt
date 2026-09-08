package com.example.creditcard.data

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * 共享银行卡数据模型（与 Web/Mac 端 DEFAULT_CARD_DATA 100% 对齐）
 */
@Serializable
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
    var cardImages: List<CardImageAsset> = emptyList()
)
