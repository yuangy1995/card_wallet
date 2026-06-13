package com.example.creditcard.utils

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * NFC 银行卡感应与读卡数据全局事件分发器
 */
object NfcScannerManager {
    private val activeReaderSessions = mutableSetOf<String>()
    private val _readerEnabled = MutableStateFlow(false)
    val readerEnabled: StateFlow<Boolean> = _readerEnabled.asStateFlow()
    val isReaderEnabled: Boolean
        get() = _readerEnabled.value

    @Synchronized
    fun beginReaderSession(owner: String) {
        activeReaderSessions.add(owner)
        _readerEnabled.value = activeReaderSessions.isNotEmpty()
    }

    @Synchronized
    fun endReaderSession(owner: String) {
        activeReaderSessions.remove(owner)
        _readerEnabled.value = activeReaderSessions.isNotEmpty()
    }

    // 使用缓存容量为 1 的 SharedFlow，确保 Compose UI 刚加载时也能顺畅响应
    private val _nfcCardData = MutableSharedFlow<Pair<String, String>>(extraBufferCapacity = 1)
    val nfcCardData: SharedFlow<Pair<String, String>> = _nfcCardData

    // 全局 NFC 读卡状态流："READING" 或 "FINISHED"
    private val _nfcReadingState = MutableSharedFlow<String>(extraBufferCapacity = 1)
    val nfcReadingState: SharedFlow<String> = _nfcReadingState

    /**
     * 当物理 NFC 模块感应或解析卡片成功时回调
     * @param number 识别出的银行卡卡号
     * @param valid 识别出的有效期，格式：MM/YY
     */
    fun onCardScanned(number: String, valid: String) {
        _nfcCardData.tryEmit(Pair(number, valid))
    }

    /**
     * NFC 读卡开始
     */
    fun onReadingStarted() {
        _nfcReadingState.tryEmit("READING")
    }

    /**
     * NFC 读卡结束
     */
    fun onReadingFinished(success: Boolean) {
        _nfcReadingState.tryEmit("FINISHED")
    }

    // 全局未支持卡片事件流，当检测到物理卡片但无法读取明文卡号时分发
    private val _nfcUnsupportedCard = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val nfcUnsupportedCard: SharedFlow<Unit> = _nfcUnsupportedCard

    /**
     * 当物理 NFC 模块捕获到卡片但由于加密或物理限制无法提取卡号时回调
     */
    fun onUnsupportedCardDetected() {
        _nfcUnsupportedCard.tryEmit(Unit)
    }
}
