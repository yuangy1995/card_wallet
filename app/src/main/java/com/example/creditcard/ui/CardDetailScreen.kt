package com.example.creditcard.ui

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import java.text.SimpleDateFormat
import java.util.Date
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.Nfc
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import android.graphics.BitmapFactory
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.*
import com.example.creditcard.ui.main.CreditCardTile
import com.example.creditcard.ui.main.formatMaskedCardNumber
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager
import com.example.creditcard.utils.CardScanProgressManager
import kotlinx.coroutines.delay
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CardDetailScreen(
    cardId: String,
    onBack: () -> Unit,
    onEdit: (String) -> Unit
) {
    val context = LocalContext.current
    val isDark by ThemeManager.isDarkTheme.collectAsState()
    
    // 加载卡片信息
    val db = DatabaseHelper(context)
    val card = remember(cardId) { db.getCardById(cardId) }
    
    if (card == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("卡片不存在或已被删除", color = MaterialTheme.colorScheme.onBackground)
        }
        return
    }

    // 1. 本地安全沙盒图片路径引用及加载
    val cardImageFile = remember(cardId) {
        File(File(context.filesDir, "scanned_cards"), "${cardId}.jpg")
    }
    val hasCardImage = remember(cardImageFile) { cardImageFile.exists() }
    var showFullscreenImage by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize()) {

    // 敏感信息防窥防窥状态控制
    var isNumberVisible by remember { mutableStateOf(false) }
    var isCvvVisible by remember { mutableStateOf(false) }
    var countdownProgress by remember { mutableStateOf(1f) }

    // 5秒自动重新遮罩定时器
    LaunchedEffect(isNumberVisible, isCvvVisible) {
        if (isNumberVisible || isCvvVisible) {
            val totalMs = 5000L
            val stepMs = 50L
            var elapsed = 0L
            countdownProgress = 1f
            
            while (elapsed < totalMs) {
                delay(stepMs)
                elapsed += stepMs
                countdownProgress = 1f - (elapsed.toFloat() / totalMs)
            }
            // 倒计时结束，重置遮罩状态
            isNumberVisible = false
            isCvvVisible = false
        }
    }

    // 删除卡片弹窗控制
    var showDeleteDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("卡片详情", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(imageVector = Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    // 编辑按钮
                    IconButton(onClick = { onEdit(cardId) }) {
                        Icon(
                            imageVector = Icons.Filled.Edit,
                            contentDescription = "编辑卡片",
                            tint = if (isDark) NeonCyan else GoldPrimary
                        )
                    }
                    // 删除按钮
                    IconButton(onClick = { showDeleteDialog = true }) {
                        Icon(
                            imageVector = Icons.Filled.Delete,
                            contentDescription = "删除卡片",
                            tint = MaterialTheme.colorScheme.error
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(12.dp))

            // 1. 黄金比例卡片磁贴展示
            CreditCardTile(card = card, isDark = isDark, onClick = {})

            // 新增：如果本地沙盒中有该卡对应的扫描图片，动态呈现其扫描件预览磁贴
            if (hasCardImage) {
                Spacer(modifier = Modifier.height(16.dp))
                DetailSection(title = "卡片扫描原件") {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(180.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (isDark) DarkCardBg else LightCardBg)
                            .clickable { showFullscreenImage = true },
                        contentAlignment = Alignment.Center
                    ) {
                        val bitmap = remember(cardImageFile) {
                            try {
                                BitmapFactory.decodeFile(cardImageFile.absolutePath)
                            } catch (e: Exception) {
                                null
                            }
                        }
                        if (bitmap != null) {
                            Image(
                                bitmap = bitmap.asImageBitmap(),
                                contentDescription = "卡片扫描原件",
                                modifier = Modifier.fillMaxSize().padding(4.dp).clip(RoundedCornerShape(10.dp)),
                                contentScale = androidx.compose.ui.layout.ContentScale.Fit
                            )
                        } else {
                            Text("⚠️ 扫描原文件加载失败", color = MaterialTheme.colorScheme.error, fontSize = 12.sp)
                        }
                        
                        // 底部浮动查看提示徽章
                        Box(
                            modifier = Modifier
                                .align(Alignment.BottomEnd)
                                .padding(8.dp)
                                .background(Color.Black.copy(alpha = 0.6f), shape = RoundedCornerShape(8.dp))
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Text("点击全屏大图预览", color = Color.White, fontSize = 10.sp)
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // 2. 年费收取到期橙色警示栏
            val annualFeeWarning = getAnnualFeeWarningMessage(card)
            if (annualFeeWarning != null) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (isDark) Color(0xFFFF9100).copy(alpha = 0.15f) else WarmOrange.copy(alpha = 0.1f))
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                ) {
                    Text(
                        text = annualFeeWarning,
                        color = if (isDark) Color(0xFFFF9100) else WarmOrange,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
                Spacer(modifier = Modifier.height(16.dp))
            }

            // 3. 基础字段区块
            DetailSection(title = "基础信息") {
                InfoRow(label = "国家 / 地区", value = card.country.ifEmpty { "未配置" })
                InfoRow(label = "银行名称", value = card.bank.ifEmpty { "未配置" })
                InfoRow(label = "卡片别名", value = card.alias.ifEmpty { "未配置" })
                InfoRow(label = "卡片等级", value = card.level.ifEmpty { "未配置" })
                InfoRow(label = "结算币种", value = card.type.ifEmpty { "CNY" })
                InfoRow(label = "有效期", value = card.valid.ifEmpty { "未配置" })
                InfoRow(label = "最后修改时间", value = formatDateTime(card.lastModifyTime))
            }

            Spacer(modifier = Modifier.height(16.dp))

            // 4. 详细信息区块 (包含防窥机制)
            DetailSection(title = "卡片安全防窥") {
                // 卡号行
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("信用卡卡号", color = if (isDark) TextGray else TextMuted, fontSize = 12.sp)
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = if (isNumberVisible) formatSpacingCardNumber(card.cardNumber) else formatMaskedCardNumber(card.cardNumber),
                            color = MaterialTheme.colorScheme.onBackground,
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold,
                            fontFamily = FontFamily.Monospace,
                            letterSpacing = 1.sp
                        )
                    }

                    // 5s 环形倒计时进度条与眼睛切换图标
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (isNumberVisible || isCvvVisible) {
                            Box(modifier = Modifier.size(24.dp), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator(
                                    progress = { countdownProgress },
                                    modifier = Modifier.fillMaxSize(),
                                    color = if (isDark) NeonCyan else GoldPrimary,
                                    strokeWidth = 3.dp
                                )
                                Text(
                                    text = "${(countdownProgress * 5).toInt() + 1}s",
                                    fontSize = 8.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isDark) NeonCyan else GoldPrimary
                                )
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                        }

                        IconButton(onClick = { isNumberVisible = !isNumberVisible }) {
                            Icon(
                                imageVector = if (isNumberVisible) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                                contentDescription = "卡号可见性",
                                tint = if (isDark) NeonCyan else GoldPrimary
                            )
                        }
                    }
                }

                HorizontalDivider(color = if (isDark) Color.White.copy(alpha = 0.05f) else Color.Black.copy(alpha = 0.05f))

                // CVV 与有效期行
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("CVV 安全码", color = if (isDark) TextGray else TextMuted, fontSize = 12.sp)
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = if (isCvvVisible) card.cvv.ifEmpty { "•••" } else "•••",
                            color = MaterialTheme.colorScheme.onBackground,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                            fontFamily = FontFamily.Monospace
                        )
                    }

                    IconButton(onClick = { isCvvVisible = !isCvvVisible }) {
                        Icon(
                            imageVector = if (isCvvVisible) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                            contentDescription = "CVV可见性",
                            tint = if (isDark) NeonCyan else GoldPrimary
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // 5. 额度年费区块
            DetailSection(title = "额度与年费") {
                InfoRow(label = "信用额度", value = "${card.type} ${String.format("%,.2f", card.limit)}")
                InfoRow(label = "账单日", value = if (card.accountBillDate.isNotEmpty()) "每月 ${card.accountBillDate} 日" else "未配置")
                InfoRow(label = "还款日", value = if (card.dueDate.isNotEmpty()) "每月 ${card.dueDate} 日" else "未配置")
                InfoRow(
                    label = "账单日消费计入下期", 
                    value = if (card.billingDaySpendingToNextBill) "是，延长免息期" else "否，计入本期"
                )
                InfoRow(
                    label = "额度共享状态", 
                    value = if (card.isSharedLimit) "是 (与同银行共享额度)" else "否 (独立额度)"
                )
                
                val statusText = when (card.isQualified) {
                    "1" -> "已达标"
                    "2" -> "未达标"
                    "3" -> "免年费 / 终身免年费"
                    else -> "未知"
                }
                val statusColor = when (card.isQualified) {
                    "1" -> if (isDark) NeonGreen else ForestGreen
                    "2" -> if (isDark) NeonRed else WarmOrange
                    else -> if (isDark) NeonCyan else GoldPrimary
                }
                
                InfoRow(label = "年费达标状态", value = statusText, valueColor = statusColor)
                InfoRow(label = "年费金额", value = "${card.type} $${String.format("%,.2f", card.annualFee)}")
                
                if (card.nextAnnualFeeCollectionTime != null && card.isQualified != "3") {
                    InfoRow(label = "下次年费扣除日", value = formatDate(card.nextAnnualFeeCollectionTime!!))
                }

                if (card.lastTime != null) {
                    InfoRow(label = "上次提额日期", value = formatDate(card.lastTime!!))
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // 6. 附加权益与备注区块
            DetailSection(title = "权益与备注") {
                Column(modifier = Modifier.padding(vertical = 6.dp)) {
                    Text("核心年费权益", color = if (isDark) TextGray else TextMuted, fontSize = 12.sp)
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = card.equity.ifEmpty { "暂无登记核心权益" },
                        color = MaterialTheme.colorScheme.onBackground,
                        fontSize = 14.sp
                    )
                }
                
                HorizontalDivider(
                    color = if (isDark) Color.White.copy(alpha = 0.05f) else Color.Black.copy(alpha = 0.05f),
                    modifier = Modifier.padding(vertical = 4.dp)
                )

                Column(modifier = Modifier.padding(vertical = 6.dp)) {
                    Text("卡片备注", color = if (isDark) TextGray else TextMuted, fontSize = 12.sp)
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = card.remark.ifEmpty { "暂无备注" },
                        color = MaterialTheme.colorScheme.onBackground,
                        fontSize = 14.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(40.dp))
        }
    }

    // 确认删除警告弹窗
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("确认删除卡片吗？") },
            text = { Text("此操作将物理删除卡片，并会通过变动账本自动同步删除云端对应的本张卡片。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        
                        // 1. 级联删除本地沙盒存储的扫描件图片文件，防积攒冗余存储垃圾
                        if (cardImageFile.exists()) {
                            cardImageFile.delete()
                        }
                        
                        SyncCoordinator.commitCardDelete(context, cardId)
                        Toast.makeText(context, "卡片已删除并存入本地账本", Toast.LENGTH_SHORT).show()
                        onBack()
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("确认删除")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("取消")
                }
            }
        )
    }

    // 2. 全屏大图预览模态 Dialog
    if (showFullscreenImage && hasCardImage) {
        Dialog(onDismissRequest = { showFullscreenImage = false }) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clickable { showFullscreenImage = false },
                contentAlignment = Alignment.Center
            ) {
                val bitmap = remember(cardImageFile) {
                    try {
                        BitmapFactory.decodeFile(cardImageFile.absolutePath)
                    } catch (e: Exception) {
                        null
                    }
                }
                if (bitmap != null) {
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = "全屏大图",
                        modifier = Modifier
                            .fillMaxWidth(0.95f)
                            .aspectRatio(1.586f)
                            .clip(RoundedCornerShape(16.dp))
                            .border(2.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(16.dp))
                    )
                }
            }
        }
    }

    // 3. Glassmorphism 冲突录入流转决策引导悬浮条
    if (CardScanProgressManager.isPendingScan) {
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(
                    if (isDark) Color(0xF21E293B) else Color(0xF9F1F5F9),
                    shape = RoundedCornerShape(18.dp)
                )
                .border(
                    width = 1.dp,
                    color = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.3f),
                    shape = RoundedCornerShape(18.dp)
                )
                .padding(16.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Nfc,
                        contentDescription = "录入",
                        tint = if (isDark) NeonCyan else GoldPrimary,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "检测到您正在录入新卡",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp,
                        color = if (isDark) NeonCyan else GoldPrimary
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "是否继续使用刚才扫描的数据录入该新卡表单？",
                    fontSize = 12.sp,
                    color = if (isDark) TextGray else TextMuted,
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(14.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Button(
                        onClick = {
                            // 同意继续录入，直接返回表单页，表单 Resume 时会自动代入数据
                            onBack()
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isDark) NeonCyan else GoldPrimary
                        ),
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("是，继续录入", fontWeight = FontWeight.Bold)
                    }

                    OutlinedButton(
                        onClick = {
                            // 拒绝继续录入，置 rejected 标志为 true，并返回表单页使其 Resume 自动回到之前扫描页
                            CardScanProgressManager.isRejectedFromDetail = true
                            onBack()
                        },
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = if (isDark) NeonCyan else GoldPrimary
                        ),
                        border = androidx.compose.foundation.BorderStroke(
                            1.dp, (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.4f)
                        ),
                        modifier = Modifier.weight(1.3f),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("否，拒绝并重扫")
                    }
                }
            }
        }
    }
}
}

/**
 * 卡片详细信息分块 UI
 */
@Composable
fun DetailSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    val isDark by ThemeManager.isDarkTheme.collectAsState()
    
    val bgModifier = if (isDark) {
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(DarkCardBg)
            .padding(16.dp)
    } else {
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(LightCardBg)
            .shadow(1.dp, shape = RoundedCornerShape(12.dp))
            .padding(16.dp)
    }

    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = title,
            fontWeight = FontWeight.Bold,
            fontSize = 14.sp,
            color = if (isDark) NeonCyan else GoldPrimary,
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp)
        )
        Column(modifier = bgModifier, content = content)
    }
}

@Composable
fun InfoRow(
    label: String,
    value: String,
    valueColor: Color = MaterialTheme.colorScheme.onBackground
) {
    val isDark by ThemeManager.isDarkTheme.collectAsState()
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            color = if (isDark) TextGray else TextMuted,
            fontSize = 13.sp,
            modifier = Modifier.weight(0.42f)
        )
        Text(
            text = value,
            color = valueColor,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.End,
            modifier = Modifier.weight(0.58f)
        )
    }
}

private fun formatDate(epochMillis: Long): String {
    return SimpleDateFormat("yyyy年MM月dd日", java.util.Locale.CHINA).format(Date(epochMillis))
}

private fun formatDateTime(epochMillis: Long): String {
    return SimpleDateFormat("yyyy年MM月dd日 HH:mm", java.util.Locale.CHINA).format(Date(epochMillis))
}

/**
 * 实时卡号格式化（加上 4 位空格）
 */
fun formatSpacingCardNumber(rawNum: String): String {
    val clean = rawNum.replace(" ", "")
    return clean.chunked(4).joinToString("  ")
}

/**
 * 获取年费收取提示
 */
fun getAnnualFeeWarningMessage(card: SharedCard): String? {
    if (card.isQualified == "3" || card.nextAnnualFeeCollectionTime == null || card.isQualified == "1") {
        return null
    }
    
    val diffMs = card.nextAnnualFeeCollectionTime!! - System.currentTimeMillis()
    val diffDays = (diffMs / (1000 * 60 * 60 * 24)).toInt()
    
    return if (diffDays in 0..60) {
        "⚠️ 年费收取警告：本张卡片年费目前【未达标】，距离扣年费时间还剩 $diffDays 天，请尽快刷满笔数或额度进行减免！"
    } else null
}
