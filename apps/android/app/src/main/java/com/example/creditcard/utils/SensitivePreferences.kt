package com.example.creditcard.utils

import android.content.SharedPreferences

object SensitivePreferences {
    fun read(prefs: SharedPreferences, key: String, legacy: (String) -> String = { it }): String {
        val raw = prefs.getString(key, "").orEmpty()
        if(raw.isEmpty()) return ""
        if(raw.startsWith(LocalDataCipher.PREFIX)) return LocalDataCipher.open(raw, "preference:$key")
        // Migration is completed before replacing the old value; failure leaves the old record intact.
        val plain = legacy(raw)
        val sealed = LocalDataCipher.seal(plain, "preference:$key")
        check(LocalDataCipher.open(sealed, "preference:$key") == plain)
        check(prefs.edit().putString(key,sealed).commit()) { "本地配置未能保存，请重试" }
        return plain
    }
    fun sealed(key: String, value: String): String = LocalDataCipher.seal(value, "preference:$key")
}
