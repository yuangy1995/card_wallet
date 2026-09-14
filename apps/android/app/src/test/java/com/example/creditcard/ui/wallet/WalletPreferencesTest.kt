package com.example.creditcard.ui.wallet

import android.content.Context
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class WalletPreferencesTest {
    private val preferences get() = RuntimeEnvironment.getApplication()
        .getSharedPreferences(WalletPreferences.FILE, Context.MODE_PRIVATE)

    @Before fun reset() { preferences.edit().clear().commit() }

    @Test fun defaultsToCardsWithoutFavorites() {
        val store = WalletPreferences(preferences)
        assertFalse(store.state.isList)
        assertTrue(store.state.favorites.isEmpty())
    }

    @Test fun honorsExistingListModeAndUnrelatedPreferences() {
        preferences.edit().putBoolean("card_is_compact_view", true)
            .putString("card_list_sort", "bank_asc").commit()
        val store = WalletPreferences(preferences)
        assertTrue(store.state.isList)
        store.setListMode(false)
        assertFalse(WalletPreferences(preferences).state.isList)
        assertEquals("bank_asc", preferences.getString("card_list_sort", null))
    }

    @Test fun favoritesSurviveRecreationAndCanBeRemoved() {
        val store = WalletPreferences(preferences)
        store.toggleFavorite("one")
        store.toggleFavorite("two")
        val recreated = WalletPreferences(preferences)
        assertEquals(setOf("one", "two"), recreated.state.favorites)
        recreated.toggleFavorite("one")
        assertEquals(setOf("two"), WalletPreferences(preferences).state.favorites)
    }

    @Test fun separateScreensDoNotOverwriteEachOthersFavorites() {
        val home = WalletPreferences(preferences)
        val detail = WalletPreferences(preferences)
        home.toggleFavorite("one")
        detail.toggleFavorite("two")
        assertEquals(setOf("one", "two"), detail.state.favorites)
        home.toggleFavorite("one")
        assertEquals(setOf("two"), home.state.favorites)
    }

    @Test fun observingScreensRefreshImmediately() {
        val home = WalletPreferences(preferences)
        val detail = WalletPreferences(preferences)
        home.start()
        try {
            detail.toggleFavorite("one")
            org.robolectric.Shadows.shadowOf(android.os.Looper.getMainLooper()).idle()
            assertTrue("one" in home.state.favorites)
        } finally { home.stop() }
    }

    @Test fun blankIdsAreIgnoredAndSnapshotsAreNotMutated() {
        val store = WalletPreferences(preferences)
        store.toggleFavorite("one")
        val oldSnapshot = store.state.favorites
        store.toggleFavorite("two")
        store.toggleFavorite("")
        assertEquals(setOf("one"), oldSnapshot)
        assertEquals(setOf("one", "two"), store.state.favorites)
    }
}
