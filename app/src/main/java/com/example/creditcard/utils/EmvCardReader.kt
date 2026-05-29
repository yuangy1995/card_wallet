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
        "A0000000041010",   // MasterCard Credit
        "A0000000042203",   // MasterCard Debit (万事达借记卡)
        "A0000000043060",   // Maestro Debit (万事达国际借记卡)
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
            isoDep.timeout = 3500 // 提升超时到 3500ms，给予外卡慢速芯片充分的交互时间

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
                // 如果在上一个 AID 尝试中导致射频重连断开了，确保此时已重建底层连接
                if (!isoDep.isConnected) {
                    try {
                        isoDep.close()
                        isoDep.connect()
                    } catch (e: Exception) {
                        continue
                    }
                }

                val lenHex = String.format("%02X", aid.length / 2)
                val selectCmd = "00A40400${lenHex}${aid}00"
                var selectResp = transceive(isoDep, selectCmd)
                
                if (isSuccess(selectResp)) {
                    val responseDataList = mutableListOf<ByteArray>()
                    responseDataList.add(selectResp)

                    // 动态决定 GPO 探测模板列表：银联卡仅探测最简 GPO 模板，严防高安芯片因多指令攻击自锁
                    val isUnionPay = aid.startsWith("A000000333", ignoreCase = true)
                    val gpoTemplates = if (isUnionPay) {
                        listOf("80A8000002830000")
                    } else {
                        listOf(
                            "80A8000002830000",                                     // 模板 1 (最简)
                            "80A800000D830B000000000000000000000000",                 // 模板 2 (11字节，万事达极常用)
                            "80A800000683040000000000",                             // 模板 3 (4字节，Visa常用)
                            "80A80000178315000000000000000000000000000000000000000000" // 模板 4 (21字节，EMV通用)
                        )
                    }

                    var gpoSuccess = false
                    for (gpoHex in gpoTemplates) {
                        // 若在上一个模板测试中发生射频断开，确保在测试前已重建底层连接
                        if (!isoDep.isConnected) {
                            try {
                                isoDep.close()
                                Thread.sleep(30)
                                isoDep.connect()
                                selectResp = transceive(isoDep, selectCmd)
                            } catch (e: Exception) {
                                break
                            }
                        }

                        try {
                            val gpoCmd = hexStringToByteArray(gpoHex)
                            val gpoResp = isoDep.transceive(gpoCmd)
                            if (isSuccess(gpoResp)) {
                                responseDataList.add(gpoResp)
                                gpoSuccess = true
                                Log.i(TAG, "GPO 指令执行成功，模板: $gpoHex")
                                break
                            }
                        } catch (e: Exception) {
                            // 金融级射频断线物理重连机制！
                            // 某些 Visa / 万事达外卡在接收到不兼容的 GPO 长度 APDU 指令时，极易触发安全保护并挂起/断开射频连接。
                            // 此时我们立刻 close 底层连接，睡眠 50ms 重新 connect 握手并再次 SELECT，供下一个 GPO 模板测试或后续读取使用
                            Log.w(TAG, "GPO 模板 $gpoHex 执行挂起或失败，开启射频物理重连机制...", e)
                            try {
                                isoDep.close()
                                Thread.sleep(50) // 延迟 50ms 复位硬件射频场
                                isoDep.connect()
                                selectResp = transceive(isoDep, selectCmd)
                            } catch (reconnectEx: Exception) {
                                Log.e(TAG, "射频物理重连重建失败", reconnectEx)
                            }
                        }
                    }

                    // 拓展 SFI 遍历范围至 1..5，Record 遍历范围至 1..12，最大概率检索到磁道数据包
                    for (sfi in 1..5) {
                        // 依照 ISO 7816 规范，READ RECORD 的 P2 字段为 (SFI << 3) | 4
                        val p2 = (sfi shl 3) or 4
                        val p2Hex = String.format("%02X", p2)
                        
                        for (record in 1..12) {
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
            Thread.sleep(15) // 在每次 APDU 指令发送前休眠 15 毫秒，给卡片 CPU 和射频留有稳固缓冲期，极大提升握手率
            isoDep.transceive(cmd)
        } catch (e: Exception) {
            ByteArray(0)
        }
    }

    private fun isSuccess(resp: ByteArray): Boolean {
        if (resp.size < 2) return false
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
        // 将所有响应段数据拼接成一个全局超长 Hex 字符串，实现跨数据包联合解析
        val globalHex = dataList.joinToString("") { byteArrayToHexString(it) }

        // A. 优先检索磁道二等效数据 (Track 2 Equivalent Data - Tag 57)
        var index = 0
        while (true) {
            val idx = globalHex.indexOf("57", index, ignoreCase = true)
            if (idx == -1) break
            if (idx % 2 == 0) {
                try {
                    val lenHex = globalHex.substring(idx + 2, idx + 4)
                    val len = lenHex.toInt(16)
                    if (len in 11..19) {
                        val track2 = globalHex.substring(idx + 4, idx + 4 + len * 2)
                        val dIdx = track2.indexOf("D", ignoreCase = true)
                        if (dIdx != -1) {
                            val cardNumber = track2.substring(0, dIdx)
                            val expiryYYMM = track2.substring(dIdx + 1, dIdx + 5)
                            
                            if (cardNumber.all { it.isDigit() } && cardNumber.length in 13..19) {
                                val formattedExpiry = if (expiryYYMM.all { it.isDigit() }) {
                                    "${expiryYYMM.substring(2, 4)}/${expiryYYMM.substring(0, 2)}"
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
            val idx = globalHex.indexOf("5A", index, ignoreCase = true)
            if (idx == -1) break
            if (idx % 2 == 0) {
                try {
                    val lenHex = globalHex.substring(idx + 2, idx + 4)
                    val len = lenHex.toInt(16)
                    if (len in 7..10) {
                        var pan = globalHex.substring(idx + 4, idx + 4 + len * 2).uppercase()
                        if (pan.endsWith("F")) {
                            pan = pan.substring(0, pan.length - 1)
                        }
                        if (pan.all { it.isDigit() } && pan.length in 13..19) {
                            // 在全局超长 Hex 字符串中扫描有效期 (Tag 5F24)，彻底解决跨包存储导致的有效期丢失问题
                            val expiry = findExpiry(globalHex)
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
        return null
    }

    /**
     * 辅助在全局字节流中扫描有效期字段 (Application Expiration Date - Tag 5F24)
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
