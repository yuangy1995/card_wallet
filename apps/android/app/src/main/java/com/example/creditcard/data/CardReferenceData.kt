package com.example.creditcard.data

/**
 * 与 Web、macOS 和 iOS 端保持一致的卡片录入参考数据。
 * 这些值会以原始字符串跨端同步，因此不要随意修改已有值。
 */
object CardReferenceData {
    data class CardLevelGroup(val brand: String, val levels: List<String>)

    data class CardLevelSelection(val brand: String, val level: String)

    val countries = listOf(
        "中国", "香港特别行政区", "澳门特别行政区", "台湾", "美国", "英国", "新加坡",
        "德国", "日本", "韩国", "澳大利亚", "加拿大", "法国", "意大利", "西班牙",
        "荷兰", "瑞士", "泰国", "马来西亚", "印度尼西亚", "菲律宾", "越南", "印度",
        "巴西", "阿根廷", "墨西哥", "俄罗斯", "南非", "土耳其", "沙特阿拉伯", "阿联酋",
        "以色列", "埃及", "新西兰"
    )

    val banks = listOf(
        "工商银行", "建设银行", "农业银行", "中国银行", "交通银行", "邮储银行",
        "招商银行", "中信银行", "光大银行", "华夏银行", "民生银行", "平安银行",
        "兴业银行", "浦发银行", "广发银行", "北京银行", "上海银行", "江苏银行",
        "宁波银行", "南京银行", "杭州银行", "成都银行", "重庆银行", "徽商银行",
        "浙商银行", "渤海银行", "上海农商银行", "重庆农商银行", "微众银行", "网商银行",
        "汇丰银行", "恒生银行", "中银香港", "渣打银行", "东亚银行", "花旗银行",
        "星展银行", "华侨银行", "众安银行", "招商永隆银行", "Mox Bank", "大西洋银行",
        "澳门商业银行", "大丰银行", "澳门国际银行", "中国信托银行", "国泰世华银行", "兆丰国际商业银行",
        "台北富邦银行", "玉山银行", "台新银行", "台湾银行", "第一银行", "华南银行",
        "合作金库银行", "摩根大通银行", "美国银行", "富国银行", "U.S. Bank", "Capital One",
        "PNC Bank", "Truist Bank", "美国运通", "Discover Bank", "加拿大皇家银行", "TD Bank",
        "加拿大丰业银行", "蒙特利尔银行", "加拿大帝国商业银行", "加拿大国民银行", "Desjardins", "巴克莱银行",
        "Lloyds Bank", "NatWest", "Santander UK", "Nationwide Building Society", "Halifax", "Monzo Bank",
        "Starling Bank", "德意志银行", "德国商业银行", "Sparkasse", "ING Germany", "Deutsche Kreditbank",
        "HypoVereinsbank", "N26 Bank", "法国巴黎银行", "法国农业信贷银行", "法国兴业银行", "Groupe BPCE",
        "Crédit Mutuel", "La Banque Postale", "裕信银行", "联合圣保罗银行", "Banco BPM", "Banca Monte dei Paschi di Siena",
        "桑坦德银行", "西班牙对外银行", "CaixaBank", "Banco Sabadell", "Bankinter", "ING Bank",
        "荷兰合作银行", "荷兰银行", "bunq", "瑞银", "Raiffeisen Switzerland", "Zürcher Kantonalbank",
        "PostFinance", "瑞士宝盛银行", "三菱日联银行", "三井住友银行", "瑞穗银行", "日本邮政银行",
        "Resona Bank", "Rakuten Bank", "SBI Sumishin Net Bank", "Sony Bank", "KB国民银行", "新韩银行",
        "韩亚银行", "友利银行", "NH NongHyup Bank", "IBK Industrial Bank of Korea", "KakaoBank", "Toss Bank",
        "澳大利亚联邦银行", "西太平洋银行", "澳大利亚国民银行", "澳新银行", "麦格理银行", "Bendigo and Adelaide Bank",
        "Bank of New Zealand", "Kiwibank", "ASB Bank", "TSB New Zealand", "大华银行", "马来亚银行",
        "联昌国际银行", "大众银行", "兴业银行（马来西亚）", "丰隆银行", "Alliance Bank Malaysia", "盘谷银行",
        "开泰银行", "Siam Commercial Bank", "Krungthai Bank", "Krungsri", "ttb bank", "Bank Mandiri",
        "Bank Rakyat Indonesia", "Bank Central Asia", "Bank Negara Indonesia", "Bank Syariah Indonesia", "Bank Tabungan Negara", "BDO Unibank",
        "Bank of the Philippine Islands", "Metrobank", "Land Bank of the Philippines", "Philippine National Bank", "UnionBank of the Philippines", "Security Bank",
        "Vietcombank", "BIDV", "VietinBank", "Agribank", "Techcombank", "MB Bank",
        "VPBank", "Asia Commercial Bank", "State Bank of India", "HDFC Bank", "ICICI Bank", "Axis Bank",
        "Kotak Mahindra Bank", "Punjab National Bank", "Bank of Baroda", "Canara Bank", "Itaú Unibanco", "Banco do Brasil",
        "Bradesco", "Caixa Econômica Federal", "Santander Brasil", "Nubank", "BTG Pactual", "Banco Nación",
        "Banco Galicia", "Santander Argentina", "BBVA Argentina", "Banco Macro", "BBVA México", "Banorte",
        "Santander México", "Banamex", "HSBC México", "Scotiabank México", "Banco Inbursa", "Sberbank",
        "VTB Bank", "Gazprombank", "Alfa-Bank", "Rosselkhozbank", "T-Bank", "Sovcombank",
        "Standard Bank", "FirstRand Bank", "Absa Bank", "Nedbank", "Capitec Bank", "Investec Bank",
        "Ziraat Bank", "Türkiye İş Bankası", "Garanti BBVA", "Akbank", "Halkbank", "VakıfBank",
        "Yapı Kredi", "Saudi National Bank", "Al Rajhi Bank", "Riyad Bank", "Saudi Awwal Bank", "Saudi Investment Bank",
        "Banque Saudi Fransi", "First Abu Dhabi Bank", "Emirates NBD", "Abu Dhabi Commercial Bank", "Mashreq", "Dubai Islamic Bank",
        "Abu Dhabi Islamic Bank", "RAKBANK", "Bank Hapoalim", "Bank Leumi", "Mizrahi-Tefahot Bank", "Israel Discount Bank",
        "First International Bank of Israel", "National Bank of Egypt", "Banque Misr", "Commercial International Bank", "QNB Alahli", "Banque du Caire",
        "Arab African International Bank"
    )

    val levelGroups = listOf(
        CardLevelGroup("银联", listOf("普卡", "金卡", "白金卡", "钻石卡", "黑钻卡")),
        CardLevelGroup("Visa", listOf("普卡", "金卡", "白金卡", "御玺卡", "无限卡")),
        CardLevelGroup("万事达", listOf("普卡", "金卡", "白金卡", "钛金卡", "世界卡", "世界之极卡")),
        CardLevelGroup("JCB", listOf("普卡", "金卡", "白金卡", "御尊卡")),
        CardLevelGroup("美国运通", listOf("绿卡", "金卡", "白金卡", "黑金卡"))
    )

    val levels = levelGroups.flatMap { group ->
        group.levels.map { "${group.brand}-$it" }
    }

    val currencies = listOf(
        "CNY", "CNH", "USD", "EUR", "GBP", "JPY", "HKD", "MOP", "TWD", "SGD",
        "AUD", "CAD", "CHF", "SEK", "DKK", "NOK", "NZD", "KRW", "THB", "MYR",
        "IDR", "VND", "PHP", "INR"
    )

    val qualificationStatuses = listOf(
        "2" to "未达标",
        "1" to "已达标",
        "3" to "终免年费"
    )

    fun normalizeLevel(value: String?): String? {
        val cleaned = value?.trim().orEmpty()
        if (cleaned.isEmpty()) return null
        if (cleaned in levels) return cleaned
        if (cleaned.startsWith("MasterCard-") || cleaned.startsWith("Mastercard-")) {
            return cleaned.replace(Regex("^Master[Cc]ard-"), "万事达-")
        }
        if (cleaned.startsWith("VISA-")) {
            return cleaned.replaceFirst("VISA-", "Visa-")
        }
        return when (cleaned) {
            "普卡" -> "银联-普卡"
            "金卡" -> "银联-金卡"
            "白金卡" -> "银联-白金卡"
            "钻石卡" -> "银联-钻石卡"
            "AE-经典-绿卡" -> "美国运通-绿卡"
            "AE-经典-金卡" -> "美国运通-金卡"
            "AE-经典-新贵白金卡", "AE-经典-百夫长白金卡" -> "美国运通-白金卡"
            "AE-经典-百夫长黑金卡" -> "美国运通-黑金卡"
            else -> cleaned
        }
    }

    fun levelSelection(value: String?): CardLevelSelection? {
        val normalized = normalizeLevel(value) ?: return null
        levelGroups.forEach { group ->
            val prefix = "${group.brand}-"
            if (normalized.startsWith(prefix)) {
                val level = normalized.removePrefix(prefix)
                if (level in group.levels) {
                    return CardLevelSelection(group.brand, level)
                }
            }
        }
        return null
    }

    fun selectLevelBrand(brand: String, currentValue: String?): String {
        val group = levelGroups.firstOrNull { it.brand == brand } ?: return ""
        val currentLevel = levelSelection(currentValue)?.level
        val nextLevel = currentLevel?.takeIf { it in group.levels } ?: group.levels.first()
        return "$brand-$nextLevel"
    }

    fun selectLevel(brand: String, level: String): String {
        val group = levelGroups.firstOrNull { it.brand == brand } ?: return ""
        return if (level in group.levels) "$brand-$level" else ""
    }
}
