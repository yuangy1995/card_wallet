package com.example.creditcard.utils

/**
 * 全局银行卡扫描与重名拦截流转进度管理器
 * 用于优雅管理“扫描 -> 重名比对 -> 查看详情 -> 引导继续/返回”全链路状态共享与决策传递
 */
object CardScanProgressManager {
    // 挂起（待录入）的卡片数据
    var pendingScanCardNumber: String? = null
    var pendingScanValid: String? = null
    var pendingScanImagePath: String? = null
    
    // 扫描来源："NFC" 或 "Camera"
    var scanSource: String = "NFC"
    
    // 是否正处于挂起待决策状态
    var isPendingScan: Boolean = false
    
    // 标识是否刚从详情页中点击“拒绝”继续录入返回，用以在 Form 页面中触发回到之前的扫描页面
    var isRejectedFromDetail: Boolean = false

    /**
     * 开始挂起录入进程，准备跳转到详情页进行冲突审查
     */
    fun startPending(number: String, valid: String, imagePath: String?, source: String) {
        pendingScanCardNumber = number
        pendingScanValid = valid
        pendingScanImagePath = imagePath
        scanSource = source
        isPendingScan = true
        isRejectedFromDetail = false
    }

    /**
     * 清理所有挂起的临时扫描状态
     */
    fun clear() {
        pendingScanCardNumber = null
        pendingScanValid = null
        pendingScanImagePath = null
        isPendingScan = false
        isRejectedFromDetail = false
    }
}
