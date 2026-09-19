package com.example.creditcard.utils

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.security.MessageDigest

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [23, 34])
class SecurityPinMigrationTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val prefs get() = context.getSharedPreferences("credit_card_security_prefs", Context.MODE_PRIVATE)
    private val oldKey = "app_security_password_hash"
    private val newKey = "app_security_pin_v2"
    private val versionKey = "app_security_pin_version"
    @Before fun before() { prefs.edit().clear().commit(); SecurityLockManager.init(context) }
    @After fun after() { prefs.edit().clear().commit(); SecurityLockManager.init(context) }
    private fun legacy() {
        val hash = MessageDigest.getInstance("SHA-256").digest("123456app_salt_2024".toByteArray()).joinToString("") { "%02x".format(it.toInt() and 255) }
        prefs.edit().putString(oldKey, hash).putBoolean("app_lock_state", true).putBoolean("biometric_unlock_enabled", true).commit()
        SecurityLockManager.init(context)
    }
    @Test fun correctOldPinAtomicallyUpgradesAndReopensWithoutChangingBiometrics() = runBlocking {
        legacy()
        assertTrue(SecurityLockManager.verifyPassword(context, "123456").success)
        assertFalse(prefs.contains(oldKey))
        assertEquals(2, prefs.getInt(versionKey, 0))
        assertTrue(prefs.getString(newKey, "")!!.startsWith("pin-v2$"))
        assertTrue(SecurityLockManager.state.value.biometricEnabled)
        SecurityLockManager.lock(context)
        SecurityLockManager.init(context)
        assertTrue(SecurityLockManager.state.value.locked)
        assertTrue(SecurityLockManager.verifyPassword(context, "123456").success)
    }
    @Test fun incorrectOldPinDoesNotCreateNewRecordAndCooldownResets() = runBlocking {
        legacy()
        repeat(5) { assertFalse(SecurityLockManager.verifyPassword(context, "654321").success) }
        assertFalse(prefs.contains(newKey))
        assertTrue(SecurityLockManager.state.value.locked)
        assertEquals(5, SecurityLockManager.state.value.failedAttempts)
        assertFalse(SecurityLockManager.verifyPassword(context, "123456").success)
        prefs.edit().putLong("password_lockout_until", System.currentTimeMillis() - 1).commit()
        assertFalse(SecurityLockManager.verifyPassword(context, "123a456").success)
        assertEquals(1, SecurityLockManager.state.value.failedAttempts)
    }
    @Test fun modernPresenceAndVersionFloorNeverFallBackToLegacy() = runBlocking {
        legacy()
        for (value in listOf("", "unknown-format")) {
            prefs.edit().putString(newKey, value).putInt(versionKey, 2).commit()
            assertFalse(SecurityLockManager.verifyPassword(context, "123456").success)
            assertTrue(SecurityLockManager.hasPassword(context))
            assertTrue(SecurityLockManager.state.value.locked)
        }
        prefs.edit().remove(newKey).commit()
        assertFalse(SecurityLockManager.verifyPassword(context, "123456").success)
        assertTrue(SecurityLockManager.hasPassword(context))
    }
    @Test fun biometricUnlockDoesNotInventAPinForMigration() {
        legacy(); SecurityLockManager.unlock(context)
        assertFalse(SecurityLockManager.state.value.locked)
        assertFalse(prefs.contains(newKey))
        assertTrue(prefs.contains(oldKey))
    }
    @Test fun lockOrBackgroundInvalidatesPendingPinAndCancellationDoesNotUnlock() = runBlocking {
        legacy()
        val pending = async(start = CoroutineStart.UNDISPATCHED) { SecurityLockManager.verifyPassword(context, "123456") }
        SecurityLockManager.lock(context)
        assertFalse(pending.await().success)
        assertTrue(SecurityLockManager.state.value.locked)
        val background = async(start = CoroutineStart.UNDISPATCHED) { SecurityLockManager.verifyPassword(context, "123456") }
        SecurityLockManager.markInactive(context)
        assertFalse(background.await().success)
        val cancelled = launch(start = CoroutineStart.UNDISPATCHED) { SecurityLockManager.verifyPassword(context, "123456") }
        cancelled.cancelAndJoin()
        assertTrue(SecurityLockManager.state.value.locked)
    }
    @Test fun concurrentWrongAttemptsAreCountedExactlyOnce() = runBlocking {
        legacy()
        val results = List(5) { async { SecurityLockManager.verifyPassword(context, "654321") } }.awaitAll()
        assertTrue(results.none { it.success })
        assertEquals(5, SecurityLockManager.state.value.failedAttempts)
    }
    @Test fun failedUpgradeRestoresOldVerifierAndCanRetry() = runBlocking {
        legacy()
        val old = prefs.getString(oldKey, null)
        var fail = true
        val real = prefs
        val faulty = object : SharedPreferences by real {
            override fun edit(): SharedPreferences.Editor {
                val editor = real.edit()
                return object : SharedPreferences.Editor by editor {
                    // Keep chaining on this proxy so commit() is actually intercepted.
                    override fun putString(key: String?, value: String?) = apply { editor.putString(key, value) }
                    override fun putInt(key: String?, value: Int) = apply { editor.putInt(key, value) }
                    override fun remove(key: String?) = apply { editor.remove(key) }
                    override fun commit(): Boolean {
                        assertNotSame(Looper.getMainLooper().thread, Thread.currentThread())
                        if (fail) { fail = false; editor.apply(); return false }
                        return editor.commit()
                    }
                }
            }
        }
        val wrapped = object : ContextWrapper(context) {
            override fun getApplicationContext(): Context = this
            override fun getSharedPreferences(name: String?, mode: Int) = faulty
        }
        assertFalse(SecurityLockManager.verifyPassword(wrapped, "123456").success)
        assertEquals(old, prefs.getString(oldKey, null))
        assertFalse(prefs.contains(newKey))
        assertTrue(SecurityLockManager.state.value.locked)
        assertTrue(SecurityLockManager.verifyPassword(wrapped, "123456").success)
    }
    @Test fun newPinSetAndAuthenticatedDisableUseNewFormat() = runBlocking {
        assertTrue(SecurityLockManager.setPassword(context, "123456").success)
        assertFalse(prefs.contains(oldKey))
        assertEquals(2, prefs.getInt(versionKey, 0))
        assertFalse(SecurityLockManager.disableWithPassword(context, "654321").success)
        assertTrue(SecurityLockManager.hasPassword(context))
        assertTrue(SecurityLockManager.disableWithPassword(context, "123456").success)
        assertFalse(SecurityLockManager.hasPassword(context))
        assertFalse(SecurityLockManager.state.value.enabled)
    }
}
