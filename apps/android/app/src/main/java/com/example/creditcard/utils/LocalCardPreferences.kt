package com.example.creditcard.utils

import android.content.Context

object LocalCardPreferences {
    fun removeDeleted(context: Context, deletedIDs: Set<String>) {
        if(deletedIDs.isEmpty()) return
        val prefs = context.applicationContext.getSharedPreferences("card_list_preferences", Context.MODE_PRIVATE)
        val key = "wallet_favorite_card_ids"
        val old = prefs.getStringSet(key, emptySet()).orEmpty().toSet()
        val next = old - deletedIDs
        if(next != old) prefs.edit().putStringSet(key, next).apply()
    }
}
