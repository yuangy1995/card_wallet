package com.example.creditcard

import android.app.PendingIntent
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.widget.Toast
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.zIndex
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import com.example.creditcard.theme.CreditCardTheme
import com.example.creditcard.ui.security.SecurityLockScreen
import com.example.creditcard.utils.SecurityLockManager
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager

import com.example.creditcard.utils.EmvCardReader
import com.example.creditcard.utils.NfcScannerManager
import kotlinx.coroutines.launch

/**
 * 主页面 Activity，按页面需求启停 NFC 前台事件捕捉与分发
 */
class MainActivity : FragmentActivity() {

    private var nfcAdapter: NfcAdapter? = null
    private var pendingIntent: PendingIntent? = null
    private var isActivityResumed = false
    private var isNfcDispatchEnabled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. 初始化本地主题偏好及数据仓库
        ThemeManager.init(this)
        SyncCoordinator.initLocalData(this)
        SecurityLockManager.init(this)
        if (savedInstanceState == null) {
            SecurityLockManager.lockIfEnabled(this)
        }

        // 2. 初始化 NFC 适配器及前台调度意图
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        val intent = Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        lifecycleScope.launch {
            NfcScannerManager.readerEnabled.collect {
                updateNfcForegroundDispatch()
            }
        }
        lifecycleScope.launch {
            SecurityLockManager.state.collect {
                updateNfcForegroundDispatch()
            }
        }

        enableEdgeToEdge()
        setContent {
            // 监听全局主题状态，动态响应热切换
            val isDark by ThemeManager.isDarkTheme.collectAsState()
            val securityState by SecurityLockManager.state.collectAsState()
            
            CreditCardTheme(darkTheme = isDark) { 
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) { 
                    Box(modifier = Modifier.fillMaxSize()) {
                        MainNavigation()
                        if (securityState.locked) {
                            SecurityLockScreen(
                                isDark = isDark,
                                modifier = Modifier.zIndex(100f)
                            )
                        }
                    }
                } 
            }
        }
    }

    override fun onResume() {
        super.onResume()
        isActivityResumed = true
        SecurityLockManager.refreshLockState(this)
        updateNfcForegroundDispatch()
    }

    override fun onPause() {
        super.onPause()
        isActivityResumed = false
        SecurityLockManager.markInactive(this)
        disableNfcForegroundDispatch()
    }

    private fun updateNfcForegroundDispatch() {
        val shouldEnable = isActivityResumed &&
            NfcScannerManager.isReaderEnabled &&
            !SecurityLockManager.state.value.locked

        if (shouldEnable) {
            enableNfcForegroundDispatch()
        } else {
            disableNfcForegroundDispatch()
        }
    }

    private fun enableNfcForegroundDispatch() {
        if (isNfcDispatchEnabled) return
        val adapter = nfcAdapter ?: return
        val intent = pendingIntent ?: return
        try {
            adapter.enableForegroundDispatch(this, intent, null, null)
            isNfcDispatchEnabled = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun disableNfcForegroundDispatch() {
        if (!isNfcDispatchEnabled) return
        try {
            nfcAdapter?.disableForegroundDispatch(this)
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            isNfcDispatchEnabled = false
        }
    }

    /**
     * 当在前台拦截到 NFC 感应卡片时的回调
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (!NfcScannerManager.isReaderEnabled) {
            return
        }
        if (SecurityLockManager.state.value.locked) {
            Toast.makeText(this, "请先解锁应用", Toast.LENGTH_SHORT).show()
            return
        }
        val action = intent.action
        if (NfcAdapter.ACTION_NDEF_DISCOVERED == action ||
            NfcAdapter.ACTION_TECH_DISCOVERED == action ||
            NfcAdapter.ACTION_TAG_DISCOVERED == action) {
            
            // 1. 获取物理卡片标识 (UID) 或是 EMV 实体
            val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
            val tagIdBytes = tag?.id
            val tagIdHex = tagIdBytes?.joinToString("") { String.format("%02X", it) } ?: "UNKNOWN"

            if (tag != null) {
                // 启动前分发正在读取状态
                NfcScannerManager.onReadingStarted()
                // 启动后台子线程进行 IsoDep 卡片 APDU 交互
                Thread {
                    val cardInfo = EmvCardReader.readCard(tag)
                    runOnUiThread {
                        NfcScannerManager.onReadingFinished(cardInfo != null)
                        if (cardInfo != null) {
                            val (scannedNo, scannedVal) = cardInfo
                            // 将读取到的卡号与有效期分发至全局 Flow，带入界面中
                            NfcScannerManager.onCardScanned(scannedNo, scannedVal)
                            Toast.makeText(this, "NFC 读卡成功：$scannedNo", Toast.LENGTH_SHORT).show()
                        } else {
                            // 触发未支持卡片全局事件流，使 UI 能展示“暂不支持该卡片”
                            NfcScannerManager.onUnsupportedCardDetected()
                            // 回退展示原有读取失败 Toast
                            Toast.makeText(
                                this,
                                "未读取到银行卡号，请换个角度重新贴近卡片",
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                    }
                }.start()
            } else {
                Toast.makeText(
                    this,
                    "未读取到银行卡号，请换个角度重新贴近卡片",
                    Toast.LENGTH_SHORT
                ).show()
            }
        }
    }
}
