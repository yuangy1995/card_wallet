package com.example.creditcard.utils

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow

/**
 * NFC 银行卡感应与读卡数据全局事件分发器
 */
object NfcScannerManager {
    // 使用缓存容量为 1 的 SharedFlow，确保 Compose UI 刚加载时也能顺畅响应
    private val _nfcCardData = MutableSharedFlow<Pair<String, String>>(extraBufferCapacity = 1)
    val nfcCardData: SharedFlow<Pair<String, String>> = _nfcCardData

    /**
     * 当物理 NFC 模块感应或解析卡片成功时回调
     * @param number 识别出的信用卡卡号
     * @param valid 识别出的有效期，格式：MM/YY
     */
    fun onCardScanned(number: String, valid: String) {
        _nfcCardData.tryEmit(Pair(number, valid))
    }
}
