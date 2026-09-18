package com.example.creditcard
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import android.content.Context
import com.example.creditcard.utils.AndroidLocalDataCipher
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.data.CardImageAsset
import java.security.KeyStore
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LocalVaultInstrumentedTest {
    @Test fun realAndroidKeyStoreAndLargeDatabaseRoundTrip() {
        val context=ApplicationProvider.getApplicationContext<Context>()
        val alias="wallet_instrumented_${UUID.randomUUID()}";val name="$alias.db"
        try {
            val cipher=AndroidLocalDataCipher(context,alias)
            val input="synthetic-only".toByteArray();val encrypted=cipher.seal(input,"fixture")
            assertArrayEquals(input,cipher.open(encrypted,"fixture"))
            val key=KeyStore.getInstance("AndroidKeyStore").apply{load(null)}.getKey(alias,null)
            assertNull("Key must not be exportable",key.encoded)
            val card=SharedCard(id="fixture",bank="SyntheticBank",cardImages=listOf(CardImageAsset(id="image",data="A".repeat(2_200_000))))
            DatabaseHelper(context,cipher,name).use { it.saveCard(card);assertEquals(card,it.getAllCards().single()) }
            DatabaseHelper(context,AndroidLocalDataCipher(context,alias),name).use { assertEquals(card,it.getCardById(card.id)) }
        } finally {
            context.deleteDatabase(name)
            KeyStore.getInstance("AndroidKeyStore").apply{load(null)}.deleteEntry(alias)
            java.io.File(context.filesDir,"$alias.marker").delete()
        }
    }
}
