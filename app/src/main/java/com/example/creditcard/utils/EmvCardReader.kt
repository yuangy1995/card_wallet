package com.example.creditcard.utils

import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.util.Log
import java.io.IOException

/**
 * 银联 / Visa / MasterCard 等 EMV 规范银行卡极简 NFC 读卡器
 */
object EmvCardReader {
    private const val TAG = "EmvCardReader"

    // 常见支付应用 Application Identifier (AID)
    private val AIDS = arrayOf(
        "A000000333010101", // 银联借记卡 (UnionPay Debit)
        "A000000333010102", // 银联贷记/信用卡 (UnionPay Credit)
        "A0000000031010",   // Visa
        "A0000000041010",   // MasterCard
        "A0000000071010",   // JCB
        "A000000333010103"  // 银联电子现金 (UnionPay Electronic Cash)
    )

    /**
     * 尝试读取物理银行卡，并提取卡号与有效期
     * @param tag 刷卡捕获到的 NFC Tag
     * @return 返回 Pair(卡号, 有效期MM/YY)；若读取失败则返回 null
     */
    fun readCard(tag: Tag): Pair<String, String>? {
        val isoDep = IsoDep.get(tag) ?: return null
        try {
            isoDep.connect()
            isoDep.timeout = 1500

            // 1. 尝试选择 PPSE (Proximity Payment System Environment) 探测支持的应用 AIDs
            var aidsToTry = AIDS.toList()
            val ppseResp = transceive(isoDep, "00A404000E325041592E5359532E444446303100")
            if (isSuccess(ppseResp)) {
                val detectedAids = parseAidsFromPpse(ppseResp)
                if (detectedAids.isNotEmpty()) {
                    // 优先尝试探测到的 AID，再备用默认 AID 列表
                    aidsToTry = detectedAids + AIDS.toList()
                }
            }

            // 2. 依次选择 AID 应用并遍历 Records 读取卡片数据
            for (aid in aidsToTry.distinct()) {
                val lenHex = String.format("%02X", aid.length / 2)
                val selectCmd = "00A40400${lenHex}${aid}00"
                val selectResp = transceive(isoDep, selectCmd)
                
                if (isSuccess(selectResp)) {
                    // 找到有效应用！尝试发送 GPO (Get Processing Options) 兼容指令激活卡片状态
                    val gpoResp = transceive(isoDep, "80A8000002830000")
                    
                    // 搜集所有的响应数据，不少卡片在 Select AID 成功后就会在返回中自带 Track2 等信息
                    val responseDataList = mutableListOf<ByteArray>()
                    responseDataList.add(selectResp)
                    if (isSuccess(gpoResp)) {
                        responseDataList.add(gpoResp)
                    }

                    // 银联/Visa等常用 SFI (Short File Identifier) 通常在 1..4，每个文件记录行数 Record 通常在 1..10
                    // 遍历发送 READ RECORD 命令收集卡号数据
                    for (sfi in 1..4) {
                        // 依照 ISO 7816 规范，READ RECORD 的 P2 字段为 (SFI << 3) | 4
                        val p2 = (sfi shl 3) or 4
                        val p2Hex = String.format("%02X", p2)
                        
                        for (record in 1..10) {
                            val recordHex = String.format("%02X", record)
                            val readRecordCmd = "00B2${recordHex}${p2Hex}00"
                            val recordResp = transceive(isoDep, readRecordCmd)
                            if (isSuccess(recordResp)) {
                                responseDataList.add(recordResp)
                            }
                        }
                    }

                    // 3. 在所有获取成功的响应字节包中，智能全盘搜索卡号与有效期
                    val result = parseCardInfo(responseDataList)
                    if (result != null) {
                        return result
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "NFC 卡片数据交互异常", e)
        } finally {
            try {
                isoDep.close()
            } catch (e: IOException) {
                // 忽略关闭异常
            }
        }
        return null
    }

    private fun transceive(isoDep: IsoDep, hexCmd: String): ByteArray {
        val cmd = hexStringToByteArray(hexCmd)
        return try {
            isoDep.transceive(cmd)
        } catch (e: Exception) {
            ByteArray(0)
        }
    }

    private fun isSuccess(resp: ByteArray): Boolean {
        if (resp.size < 2) return false
        // 标准状态字 90 00 表示指令执行成功
        val sw1 = resp[resp.size - 2].toInt() and 0xFF
        val sw2 = resp[resp.size - 1].toInt() and 0xFF
        return sw1 == 0x90 && sw2 == 0x00
    }

    /**
     * 从 PPSE 响应中解析出 AID 标识
     */
    private fun parseAidsFromPpse(ppseResp: ByteArray): List<String> {
        val aids = mutableListOf<String>()
        val hex = byteArrayToHexString(ppseResp)
        
        var index = 0
        while (true) {
            // 查找 AID Tag (4F)
            val idx = hex.indexOf("4F", index, ignoreCase = true)
            if (idx == -1) break
            
            // 确保匹配在整字节的偶数起始边界上，以避免半字节混淆
            if (idx % 2 == 0) {
                try {
                    val lenHex = hex.substring(idx + 2, idx + 4)
                    val len = lenHex.toInt(16)
                    // AID 长度通常为 5 至 16 字节
                    if (len in 5..16) {
                        val aid = hex.substring(idx + 4, idx + 4 + len * 2)
                        aids.add(aid.uppercase())
                    }
                } catch (e: Exception) {
                    // 忽略异常
                }
                index = idx + 2
            } else {
                index = idx + 1
            }
        }
        return aids
    }

    /**
     * 在所有响应段数据中智能检索卡号 (PAN) 与有效期
     */
    private fun parseCardInfo(dataList: List<ByteArray>): Pair<String, String>? {
        for (data in dataList) {
            val hex = byteArrayToHexString(data)
            
            // A. 优先检索磁道二等效数据 (Track 2 Equivalent Data - Tag 57)
            // 该数据极其通用，且几乎在所有银联及外卡中均包含完整的卡号与有效期
            var index = 0
            while (true) {
                val idx = hex.indexOf("57", index, ignoreCase = true)
                if (idx == -1) break
                if (idx % 2 == 0) {
                    try {
                        val lenHex = hex.substring(idx + 2, idx + 4)
                        val len = lenHex.toInt(16)
                        if (len in 11..19) {
                            val track2 = hex.substring(idx + 4, idx + 4 + len * 2)
                            // 查找 Track2 中 BCD 分隔符 'D' (半字节值为 D)
                            val dIdx = track2.indexOf("D", ignoreCase = true)
                            if (dIdx != -1) {
                                val cardNumber = track2.substring(0, dIdx)
                                val expiryYYMM = track2.substring(dIdx + 1, dIdx + 5)
                                
                                if (cardNumber.all { it.isDigit() } && cardNumber.length in 13..19) {
                                    val formattedExpiry = if (expiryYYMM.all { it.isDigit() }) {
                                        "${expiryYYMM.substring(2, 4)}/${expiryYYMM.substring(0, 2)}" // YYMM -> MM/YY
                                    } else {
                                        ""
                                    }
                                    return Pair(cardNumber, formattedExpiry)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        // 忽略
                    }
                    index = idx + 2
                } else {
                    index = idx + 1
                }
            }

            // B. 备用检索应用卡号标段 (Application PAN - Tag 5A)
            index = 0
            while (true) {
                val idx = hex.indexOf("5A", index, ignoreCase = true)
                if (idx == -1) break
                if (idx % 2 == 0) {
                    try {
                        val lenHex = hex.substring(idx + 2, idx + 4)
                        val len = lenHex.toInt(16)
                        if (len in 7..10) {
                            var pan = hex.substring(idx + 4, idx + 4 + len * 2).uppercase()
                            // BCD 编码尾部补 'F'
                            if (pan.endsWith("F")) {
                                pan = pan.substring(0, pan.length - 1)
                            }
                            if (pan.all { it.isDigit() } && pan.length in 13..19) {
                                // 若找到了主卡号，进一步全局扫描有效期 (Tag 5F24)
                                val expiry = findExpiry(hex)
                                return Pair(pan, expiry)
                            }
                        }
                    } catch (e: Exception) {
                        // 忽略
                    }
                    index = idx + 2
                } else {
                    index = idx + 1
                }
            }
        }
        return null
    }

    /**
     * 辅助在字节流中扫描有效期字段 (Application Expiration Date - Tag 5F24)
     */
    private fun findExpiry(hex: String): String {
        val idx = hex.indexOf("5F24", ignoreCase = true)
        if (idx != -1 && idx % 2 == 0) {
            try {
                val lenHex = hex.substring(idx + 4, idx + 6)
                val len = lenHex.toInt(16)
                // 有效期格式通常为 BCD 格式的 YYMMDD (共 3 字节)
                if (len == 3) {
                    val expiryYYMMDD = hex.substring(idx + 6, idx + 12)
                    if (expiryYYMMDD.all { it.isDigit() }) {
                        return "${expiryYYMMDD.substring(2, 4)}/${expiryYYMMDD.substring(0, 2)}" // YYMMDD -> MM/YY
                    }
                }
            } catch (e: Exception) {
                // 忽略
            }
        }
        return ""
    }

    private fun hexStringToByteArray(s: String): ByteArray {
        val len = s.length
        val data = ByteArray(len / 2)
        var i = 0
        while (i < len) {
            data[i / 2] = ((Character.digit(s[i], 16) shl 4) + Character.digit(s[i + 1], 16)).toByte()
            i += 2
        }
        return data
    }

    private fun byteArrayToHexString(bytes: ByteArray): String {
        val sb = StringBuilder()
        for (b in bytes) {
            sb.append(String.format("%02X", b))
        }
        return sb.toString()
    }
}
