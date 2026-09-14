package com.example.creditcard.ui.wallet

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext

/** Presentation preferences only: never changes card timestamps or the shared SyncV4 schema. */
internal data class WalletPreferenceState(
    val isList: Boolean = false,
    val favorites: Set<String> = emptySet()
)

internal class WalletPreferences(private val preferences: SharedPreferences) {
    var state by mutableStateOf(read())
        private set

    private fun read() = WalletPreferenceState(
        isList = preferences.getBoolean(LIST_KEY, false),
        // SharedPreferences owns the returned set; never mutate it.
        favorites = preferences.getStringSet(FAVORITES_KEY, emptySet()).orEmpty().toSet()
    )

    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == null || key == LIST_KEY || key == FAVORITES_KEY) state = read()
    }

    fun start() {
        preferences.registerOnSharedPreferenceChangeListener(listener)
        state = read()
    }

    fun stop() = preferences.unregisterOnSharedPreferenceChangeListener(listener)

    fun setListMode(isList: Boolean) {
        preferences.edit().putBoolean(LIST_KEY, isList).apply()
        state = read()
    }

    fun toggleFavorite(cardId: String) {
        if (cardId.isBlank()) return
        // Read the latest snapshot so changes from the detail screen cannot overwrite another toggle.
        val favorites = read().favorites
        val updated = if (cardId in favorites) favorites - cardId else favorites + cardId
        preferences.edit().putStringSet(FAVORITES_KEY, updated).apply()
        state = read()
    }

    companion object {
        const val FILE = "card_list_preferences"
        const val LIST_KEY = "card_is_compact_view"
        const val FAVORITES_KEY = "wallet_favorite_card_ids"
    }
}

@Composable
internal fun rememberWalletPreferences(): WalletPreferences {
    val context = LocalContext.current.applicationContext
    val preferences = remember(context) {
        WalletPreferences(context.getSharedPreferences(WalletPreferences.FILE, Context.MODE_PRIVATE))
    }
    DisposableEffect(preferences) {
        preferences.start()
        onDispose { preferences.stop() }
    }
    return preferences
}
