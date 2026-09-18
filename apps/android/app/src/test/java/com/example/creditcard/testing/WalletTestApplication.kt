package com.example.creditcard.testing

import android.app.Application
import android.security.keystore.KeyGenParameterSpec
import java.io.InputStream
import java.io.OutputStream
import java.security.*
import java.security.cert.Certificate
import java.security.spec.AlgorithmParameterSpec
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import javax.crypto.KeyGenerator
import javax.crypto.KeyGeneratorSpi
import javax.crypto.SecretKey

/** Test-only AndroidKeyStore provider: real JCE AES/GCM, in-memory keys; never packaged in the app. */
class WalletTestApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if(Security.getProvider("AndroidKeyStore") == null) Security.addProvider(TestKeyStoreProvider())
    }
}
class TestKeyStoreProvider : Provider("AndroidKeyStore", 1.0, "Unit-test device-key provider") {
    init { put("KeyStore.AndroidKeyStore", TestKeyStore::class.java.name); put("KeyGenerator.AES", TestKeyGenerator::class.java.name) }
    companion object { val keys = ConcurrentHashMap<String, Key>() }
}
class TestKeyGenerator : KeyGeneratorSpi() {
    private var alias = ""; private var bits = 256
    override fun engineInit(random: SecureRandom?) { error("Key alias required") }
    override fun engineInit(keysize: Int, random: SecureRandom?) { error("Key alias required") }
    override fun engineInit(params: AlgorithmParameterSpec?, random: SecureRandom?) {
        val spec = params as KeyGenParameterSpec; alias=spec.keystoreAlias; bits=spec.keySize
    }
    override fun engineGenerateKey(): SecretKey {
        val generator = KeyGenerator.getInstance("AES", "SunJCE"); generator.init(bits)
        return generator.generateKey().also { TestKeyStoreProvider.keys[alias] = it }
    }
}
class TestKeyStore : KeyStoreSpi() {
    override fun engineGetKey(alias: String, password: CharArray?): Key? = TestKeyStoreProvider.keys[alias]
    override fun engineGetCertificateChain(alias: String): Array<Certificate>? = null
    override fun engineGetCertificate(alias: String): Certificate? = null
    override fun engineGetCreationDate(alias: String): Date? = if(engineContainsAlias(alias)) Date(0) else null
    override fun engineSetKeyEntry(alias: String, key: Key, password: CharArray?, chain: Array<Certificate>?) { TestKeyStoreProvider.keys[alias]=key }
    override fun engineSetKeyEntry(alias: String, key: ByteArray, chain: Array<Certificate>?) { error("Unsupported") }
    override fun engineSetCertificateEntry(alias: String, cert: Certificate) { error("Unsupported") }
    override fun engineDeleteEntry(alias: String) { TestKeyStoreProvider.keys.remove(alias) }
    override fun engineAliases(): Enumeration<String> = Collections.enumeration(TestKeyStoreProvider.keys.keys)
    override fun engineContainsAlias(alias: String): Boolean = TestKeyStoreProvider.keys.containsKey(alias)
    override fun engineSize(): Int = TestKeyStoreProvider.keys.size
    override fun engineIsKeyEntry(alias: String): Boolean = engineContainsAlias(alias)
    override fun engineIsCertificateEntry(alias: String): Boolean = false
    override fun engineGetCertificateAlias(cert: Certificate): String? = null
    override fun engineStore(stream: OutputStream?, password: CharArray?) {}
    override fun engineLoad(stream: InputStream?, password: CharArray?) {}
}
