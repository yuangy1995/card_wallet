package com.example.creditcard.ui.wallet

import java.util.Locale

/** Only known issuer names are matched. Unknown issuers keep a neutral monogram. */
internal enum class WalletBank(val code: String, val accent: Long, vararg val aliases: String) {
    CMB("cmb", 0xFFA93643, "招商银行", "招商銀行", "招行", "chinamerchantsbank", "cmb"),
    BOC("boc", 0xFF394453, "中国银行", "中國銀行", "中银香港", "中銀香港", "bankofchina", "boc", "bochk"),
    ICBC("icbc", 0xFF9F343D, "工商银行", "工商銀行", "industrialandcommercialbank", "icbc"),
    ABC("abc", 0xFF23745F, "农业银行", "農業銀行", "agriculturalbank", "abc"),
    CCB("ccb", 0xFF315E98, "建设银行", "建設銀行", "chinaconstructionbank", "ccb"),
    BOCOM("bocom", 0xFF3B70AA, "交通银行", "交通銀行", "bankofcommunications", "bocom", "bcm"),
    CITIC("citic", 0xFF923A47, "中信银行", "中信銀行", "citic"),
    CGB("cgb", 0xFF923642, "广发银行", "廣發銀行", "chinaguangfa", "cgb"),
    PINGAN("pingan", 0xFF975D2E, "平安银行", "平安銀行", "pinganbank"),
    SPDB("spdb", 0xFF375987, "浦发银行", "浦發銀行", "shanghaipudongdevelopment", "spdb"),
    CIB("cib", 0xFF374D83, "兴业银行", "興業銀行", "industrialbank", "cib"),
    CEB("ceb", 0xFF69517D, "光大银行", "光大銀行", "chinaeverbright", "ceb"),
    CMBC("cmbc", 0xFF357163, "民生银行", "民生銀行", "chinaminsheng", "cmbc"),
    PSBC("psbc", 0xFF416C50, "邮政储蓄", "郵政儲蓄", "postalsavingsbank", "psbc"),
    HXB("hxb", 0xFF984944, "华夏银行", "華夏銀行", "huaxiabank", "hxb"),
    HSBC("hsbc", 0xFF444B53, "汇丰", "滙豐", "匯豐", "hsbc"),
    BOA("boa", 0xFF385789, "美国银行", "美國銀行", "bankofamerica", "boa", "bofa"),
    CITI("citi", 0xFF345C8D, "花旗", "citibank", "citi"),
    CHASE("chase", 0xFF30598D, "大通银行", "大通銀行", "chase"),
    SC("sc", 0xFF3C6B68, "渣打", "standardchartered"),
    HANGSENG("hangseng", 0xFF356A50, "恒生", "恆生", "hangseng"),
    DBS("dbs", 0xFF943E44, "星展", "dbs"),
    AMEX("amex", 0xFF356A88, "美国运通", "美國運通", "americanexpress", "amex"),
    UNKNOWN("unknown", 0xFF465768);

    companion object {
        private val wordPattern = Regex("[a-z0-9]+")

        fun fromName(name: String): WalletBank {
            val lower = name.lowercase(Locale.ROOT)
            val normalized = lower.filter(Char::isLetterOrDigit)
            if (normalized.isEmpty()) return UNKNOWN
            val words = wordPattern.findAll(lower).map { it.value }.toSet()
            // A longer issuer name beats a shared suffix: "Agricultural Bank of China"
            // must not resolve to BOC. Short English aliases require whole-word matching
            // so "Citizens Bank" never borrows the Citi mark.
            val matches = entries.mapNotNull { bank ->
                val score = bank.aliases.filter { alias ->
                    normalized == alias || alias in words ||
                        ((alias.length >= 8 || alias.any { it.code > 127 }) && normalized.contains(alias))
                }.maxOfOrNull { alias -> alias.length + if (normalized == alias) 1000 else 0 }
                score?.let { bank to it }
            }
            val bestScore = matches.maxOfOrNull { it.second } ?: return UNKNOWN
            return matches.filter { it.second == bestScore }.singleOrNull()?.first ?: UNKNOWN
        }
    }
}

internal enum class WalletNetwork(val code: String, val label: String) {
    VISA("visa", "Visa"), MASTERCARD("mastercard", "Mastercard"),
    AMEX("amex", "American Express"), UNIONPAY("unionpay", "UnionPay"),
    JCB("jcb", "JCB"), DISCOVER("discover", "Discover"), DINERS("diners", "Diners Club"),
    UNKNOWN("unknown", "");

    companion object {
        /** Local display hint, not a BIN lookup or a validation of card ownership. */
        fun fromNumber(number: String): WalletNetwork {
            val digits = number.filter { it in '0'..'9' }
            val two = digits.take(2).toIntOrNull() ?: return UNKNOWN
            val three = digits.take(3).toIntOrNull() ?: return UNKNOWN
            val four = digits.take(4).toIntOrNull() ?: return UNKNOWN
            return when {
                digits.length == 15 && two in setOf(34, 37) -> AMEX
                digits.length == 16 && (two in 51..55 || four in 2221..2720) -> MASTERCARD
                digits.length in 16..19 && four in 3528..3589 -> JCB
                digits.length in 16..19 && (four == 6011 || two == 65 || three in 644..649) -> DISCOVER
                digits.length in setOf(13, 16, 19) && digits.startsWith('4') -> VISA
                // Keep the app's UnionPay display convention for 62/81. A shared
                // acceptance range alone cannot establish Discover co-branding.
                digits.length in 16..19 && two in setOf(62, 81) -> UNIONPAY
                digits.length == 14 && (three in 300..305 || two in setOf(36, 38, 39)) -> DINERS
                else -> UNKNOWN
            }
        }
    }
}

internal fun walletLastFour(number: String): String {
    val digits = number.filter { it in '0'..'9' }
    return if (digits.length >= 4) digits.takeLast(4) else "----"
}
