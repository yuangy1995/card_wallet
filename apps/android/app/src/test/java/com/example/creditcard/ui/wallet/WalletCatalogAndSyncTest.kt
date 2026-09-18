package com.example.creditcard.ui.wallet

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.creditcard.utils.CryptoManager
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.SyncNetworkPreference
import com.example.creditcard.utils.WebDAVConfig
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class WalletCatalogAndSyncTest {
    private val context get() = ApplicationProvider.getApplicationContext<Context>()

    @Test fun recognizesReportedIssuersAndTraditionalAliases() {
        listOf("北京银行", "Bank of Beijing", "Capital One", "AMEX", "American Express", "招商銀行",
            "中國銀行", "HSBC", "Revolut", "Chase").forEach {
            assertNotNull("Missing supported issuer: $it", WalletLogoCatalog.match(it))
        }
        assertEquals(WalletLogoCatalog.match("北京银行"), WalletLogoCatalog.match("北京銀行股份有限公司"))
        assertEquals(WalletLogoCatalog.match("Capital One"), WalletLogoCatalog.match("capital one"))
    }

    @Test fun similarNamesNeverSilentlyBorrowAnotherLogo() {
        assertNull(WalletLogoCatalog.match("Unknown Regional Test Bank"))
        assertNull(WalletLogoCatalog.match("ABCXYZ"))
        assertNotEquals(WalletLogoCatalog.match("中国银行"), WalletLogoCatalog.match("中国工商银行"))
        assertNotEquals(WalletLogoCatalog.match("兴业银行", "中国"), WalletLogoCatalog.match("兴业银行", "马来西亚"))
        assertEquals(WalletLogoCatalog.match("ICBC"), WalletLogoCatalog.match("Industrial and Commercial Bank of China"))
    }

    @Test fun legacyDisabledConfigurationMigratesWithoutChangingSecretsOrNetworkPolicy() {
        val prefs = context.getSharedPreferences("credit_card_sync_prefs", Context.MODE_PRIVATE)
        val encrypted = CryptoManager.encrypt("private-test-password")
        val key = CryptoManager.encrypt("existing-encryption-key")
        prefs.edit().clear().putString("webdav_url", "https://example.invalid/dav")
            .putString("webdav_user", "demo").putString("webdav_pass", encrypted)
            .putString("webdav_sync_password_v4", key).putBoolean("webdav_enabled", false)
            .putString("webdav_sync_network_preference", "wifi_only").commit()
        val migrated = SyncCoordinator.loadConfig(context)
        assertTrue(migrated.isEnabled)
        assertTrue(migrated.isReadyForSync)
        assertEquals("private-test-password", migrated.pass)
        assertEquals("existing-encryption-key", migrated.syncPassword)
        assertEquals(SyncNetworkPreference.WIFI_ONLY, migrated.networkPreference)
        assertTrue(prefs.getString("webdav_pass", "")!!.startsWith("local-secret-v1:"))
        assertTrue(prefs.getString("webdav_sync_password_v4", "")!!.startsWith("local-secret-v1:"))
        assertTrue(prefs.getBoolean("webdav_enabled", false))
    }

    @Test fun savingCannotDisableConfiguredSyncButEmptyConfigNeverStartsSync() {
        val configured = WebDAVConfig("https://example.invalid/dav", "demo", "test-password", "test-key-12345", false,
            SyncNetworkPreference.WIFI_AND_CELLULAR)
        SyncCoordinator.saveConfig(context, configured)
        val restored = SyncCoordinator.loadConfig(context)
        assertTrue(restored.isEnabled)
        assertTrue(restored.isReadyForSync)
        assertEquals(SyncNetworkPreference.WIFI_AND_CELLULAR, restored.networkPreference)
        assertFalse(WebDAVConfig().isReadyForSync)
        assertNotNull(WebDAVConfig().syncUnavailableMessage())
    }
}
