package com.example.creditcard.data

/**
 * Card entry reference data mirrored from the Web client referenceData.js and
 * the macOS CardEditView pickers. Keep values stable because they are synced
 * across clients as raw strings.
 */
object CardReferenceData {
    val countries = listOf(
        "中国", "香港特别行政区", "澳门特别行政区", "台湾", "美国", "英国", "新加坡",
        "德国", "日本", "韩国", "澳大利亚", "加拿大", "法国", "意大利", "西班牙",
        "荷兰", "瑞士", "泰国", "马来西亚", "印度尼西亚", "菲律宾", "越南", "印度",
        "巴西", "阿根廷", "墨西哥", "俄罗斯", "南非", "土耳其", "沙特阿拉伯", "阿联酋",
        "以色列", "埃及", "新西兰"
    )

    val banks = listOf(
        "工商银行", "建设银行", "农业银行", "中国银行", "交通银行", "邮储银行", "招商银行",
        "中信银行", "光大银行", "华夏银行", "民生银行", "平安银行", "兴业银行", "浦发银行",
        "广发银行", "北京银行", "宁波银行", "江苏银行", "汇丰银行", "渣打银行", "花旗银行",
        "东亚银行", "恒生银行", "星展银行", "美国银行", "摩根大通银行", "德意志银行",
        "华侨银行", "众安银行", "招商永隆银行"
    )

    val levels = listOf(
        "银联-普卡", "银联-金卡", "银联-白金卡", "银联-钻石卡", "银联-黑钻卡",
        "银联 + VISA", "银联 + MasterCard", "银联 + JCB", "银联 + AE",
        "VISA-普卡", "VISA-金卡", "VISA-白金卡", "VISA-御玺卡", "VISA-无限卡",
        "MasterCard-普卡", "MasterCard-金卡", "MasterCard-白金卡", "MasterCard-钛金卡",
        "MasterCard-世界卡", "MasterCard-世界之极卡",
        "JCB-普卡", "JCB-金卡", "JCB-白金卡", "JCB-御尊卡",
        "AE-经典-绿卡", "AE-经典-红卡", "AE-经典-金卡", "AE-经典-蓝卡",
        "AE-经典-新贵白金卡", "AE-经典-clear卡", "AE-经典-Explorer卡",
        "AE-经典-Cash Magnet卡", "AE-经典-百夫长白金卡", "AE-经典-百夫长黑金卡",
        "AE-蓝盒子-MEMBER卡", "AE-蓝盒子-SELECT卡", "AE-蓝盒子-MAX卡", "AE-蓝盒子-ICON卡"
    )

    val currencies = listOf(
        "CNY", "CNH", "USD", "EUR", "GBP", "JPY", "HKD", "MOP", "TWD", "SGD",
        "AUD", "CAD", "CHF", "SEK", "DKK", "NOK", "NZD", "KRW", "THB", "MYR",
        "IDR", "VND", "PHP", "INR"
    )

    val qualificationStatuses = listOf(
        "2" to "未达标",
        "1" to "已达标",
        "3" to "终身免年费"
    )

    fun normalizeLevel(value: String?): String? {
        val cleaned = value?.trim().orEmpty()
        if (cleaned.isEmpty()) return null
        if (cleaned in levels) return cleaned
        return when (cleaned) {
            "普卡" -> "银联-普卡"
            "金卡" -> "银联-金卡"
            "白金卡" -> "银联-白金卡"
            "钻石卡" -> "银联-钻石卡"
            else -> cleaned
        }
    }
}
