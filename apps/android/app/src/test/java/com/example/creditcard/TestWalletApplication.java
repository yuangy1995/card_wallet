package com.example.creditcard;
import android.app.Application;
import java.security.*;
import java.security.cert.Certificate;
import java.security.spec.AlgorithmParameterSpec;
import java.io.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import javax.crypto.*;

public class TestWalletApplication extends Application {
    @Override public void onCreate() {
        if (Security.getProvider("AndroidKeyStore") == null) Security.addProvider(new TestProvider());
        super.onCreate();
    }
    public static class TestProvider extends Provider {
        public TestProvider() {
            super("AndroidKeyStore", 1.0, "TEST ONLY: ephemeral JVM key store; not hardware validation");
            put("KeyStore.AndroidKeyStore", Store.class.getName());
            put("KeyGenerator.AES", Generator.class.getName());
        }
    }
    private static final Map<String,Key> KEYS = new ConcurrentHashMap<>();
    public static class Generator extends KeyGeneratorSpi {
        private String alias;
        protected void engineInit(SecureRandom random) { }
        protected void engineInit(int size, SecureRandom random) { }
        protected void engineInit(AlgorithmParameterSpec spec, SecureRandom random) throws InvalidAlgorithmParameterException {
            try { alias = (String) spec.getClass().getMethod("getKeystoreAlias").invoke(spec); }
            catch (Exception e) { throw new InvalidAlgorithmParameterException(e); }
        }
        protected SecretKey engineGenerateKey() {
            try {
                KeyGenerator real = KeyGenerator.getInstance("AES", "SunJCE"); real.init(256);
                SecretKey key = real.generateKey(); KEYS.put(alias, key); return key;
            } catch (Exception e) { throw new IllegalStateException(e); }
        }
    }
    public static class Store extends KeyStoreSpi {
        public Key engineGetKey(String alias, char[] password) { return KEYS.get(alias); }
        public Certificate[] engineGetCertificateChain(String alias) { return null; }
        public Certificate engineGetCertificate(String alias) { return null; }
        public Date engineGetCreationDate(String alias) { return new Date(0); }
        public void engineSetKeyEntry(String alias, Key key, char[] password, Certificate[] chain) { KEYS.put(alias,key); }
        public void engineSetKeyEntry(String alias, byte[] key, Certificate[] chain) throws KeyStoreException { throw new KeyStoreException(); }
        public void engineSetCertificateEntry(String alias, Certificate cert) throws KeyStoreException { throw new KeyStoreException(); }
        public void engineDeleteEntry(String alias) { KEYS.remove(alias); }
        public Enumeration<String> engineAliases() { return Collections.enumeration(KEYS.keySet()); }
        public boolean engineContainsAlias(String alias) { return KEYS.containsKey(alias); }
        public int engineSize() { return KEYS.size(); }
        public boolean engineIsKeyEntry(String alias) { return KEYS.containsKey(alias); }
        public boolean engineIsCertificateEntry(String alias) { return false; }
        public String engineGetCertificateAlias(Certificate cert) { return null; }
        public void engineStore(OutputStream out, char[] password) { }
        public void engineLoad(InputStream in, char[] password) { }
    }
}
