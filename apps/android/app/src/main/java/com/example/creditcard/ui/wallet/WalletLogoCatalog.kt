package com.example.creditcard.ui.wallet

import androidx.compose.runtime.Immutable
import java.text.Normalizer
import java.util.Locale

@Immutable
internal data class WalletIssuerLogo(
    val id: String,
    val name: String,
    val drawable: Int,
    val cardDrawable: Int,
    val accent: Long,
    val aliases: List<String>
)

/** Only issuer names are inspected: card numbers and account data never leave the device. */
internal object WalletLogoCatalog {
    private val traditional = "銀國業興華農發門灣臺廣東滙豐慶陽儲郵長蘇龍寧漢廈恆華僑滬浙齊魯晉遼瀋陝鄭濰烏義壽營濟贛贊聯眾雲貴黔陸"
    private val simplified = "银国业兴华农发门湾台广东汇丰庆阳储邮长苏龙宁汉厦恒华侨沪浙齐鲁晋辽沈陕郑潍乌义寿营济赣赞联众云贵黔陆"
    private val translations = traditional.zip(simplified).toMap()
    private val marks = Regex("\\p{M}+")
    private val wordPattern = Regex("[a-z0-9]+")
    private val corporateSuffix = Regex("(?:股份有限公司|有限责任公司|有限公司|corporation|limited|ltd|inc)$")

    internal fun normalized(value: String): String {
        val latin = marks.replace(Normalizer.normalize(value, Normalizer.Form.NFKD), "").lowercase(Locale.ROOT)
        return corporateSuffix.replace(latin.map { translations[it] ?: it }.filter(Char::isLetterOrDigit).joinToString(""), "")
    }

    val entries: List<WalletIssuerLogo> get() = WalletLogoCatalogData.entries
    private data class Alias(val value: String, val issuer: WalletIssuerLogo)
    private val index by lazy {
        entries.flatMap { issuer -> (issuer.aliases + issuer.name).map { Alias(normalized(it), issuer) } }
            .filter { it.value.isNotEmpty() }.distinctBy { it.issuer.id to it.value }
    }
    private val exact by lazy { index.groupBy { it.value } }
    private val cache = object : LinkedHashMap<String, WalletIssuerLogo?>(128, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, WalletIssuerLogo?>?) = size > 256
    }

    @Synchronized
    fun match(name: String, country: String = ""): WalletIssuerLogo? {
        val key = "$name\u0000$country"
        if (cache.containsKey(key)) return cache[key]
        val n = normalized(name)
        if (n.isEmpty()) return null
        // The Malaysian RHB name is not the Chinese Industrial Bank.
        val malaysian = normalized(country) in setOf("malaysia", "my", "马来西亚") || n.contains("马来西亚")
        val candidates = if (malaysian && n.contains("兴业银行")) index.filter { it.issuer.id.contains("rhb") }
            else index
        val words = wordPattern.findAll(name.lowercase(Locale.ROOT)).map { it.value }.toSet()
        val precise = if (malaysian && n.contains("兴业银行")) emptyList() else exact[n].orEmpty()
        val exactIssuers = precise.map { it.issuer }.distinctBy { it.id }
        val result = if (exactIssuers.size == 1) exactIssuers.single() else {
            val hits = candidates.mapNotNull { alias ->
                val a = alias.value
                val chinese = a.any { it.code > 127 }
                val matches = a == n || a in words ||
                    (chinese && a.length >= 3 && n.contains(a)) ||
                    (!chinese && a.length >= 8 && (n.startsWith(a) || n.endsWith(a)))
                if (matches) alias.issuer to (a.length + if (a == n) 10000 else 0) else null
            }
            val score = hits.maxOfOrNull { it.second }
            hits.filter { it.second == score }.map { it.first }.distinctBy { it.id }.singleOrNull()
        }
        cache[key] = result
        return result
    }
}
