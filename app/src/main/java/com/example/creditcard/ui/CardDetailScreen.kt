package com.example.creditcard.ui

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import java.text.SimpleDateFormat
import java.util.Date
import androidx.compose.foundation.Image
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
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
import androidx.compose.ui.window.DialogProperties
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import com.example.creditcard.data.CardImageAsset
import androidx.activity.OnBackPressedCallback
import androidx.activity.ComponentActivity
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.*
import com.example.creditcard.ui.components.AppBackButton
import com.example.creditcard.ui.main.CreditCardTile
import com.example.creditcard.ui.main.formatMaskedCardNumber
import com.example.creditcard.utils.AnnualFeeDetectionKind
import com.example.creditcard.utils.CardImageCodec
import com.example.creditcard.utils.CardExpiryStatus
import com.example.creditcard.utils.CardReminderRules
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager
import com.example.creditcard.utils.CardScanProgressManager
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CardDetailScreen(
    cardId: String,
    onBack: () -> Unit,
    onEdit: (String) -> Unit
) {
    val context = LocalContext.current
    val activity = context as? ComponentActivity

    // 直接将 OnBackPressedCallback 注册到主 Activity 的 OnBackPressedDispatcher 上，
    // 彻底解决局部 OnBackPressedDispatcher 链接失效导致的全面屏返回闪退问题
    DisposableEffect(activity) {
        val backCallback = object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                onBack()
            }
        }
        activity?.onBackPressedDispatcher?.addCallback(backCallback)
        onDispose {
            backCallback.remove()
        }
    }
    val isDark by ThemeManager.isDarkTheme.collectAsState()
    
    // 加载卡片信息
    val appContext = context.applicationContext
    val db = remember(appContext) { DatabaseHelper(appContext) }
    DisposableEffect(db) {
        onDispose {
            db.close()
        }
    }
    val card = remember(cardId, db) { db.getCardById(cardId) }
    
    if (card == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("卡片不存在或已被删除", color = MaterialTheme.colorScheme.onBackground)
        }
        return
    }
    val isDebitCard = card.cardCategory == "debit"
    val cardCategoryText = if (isDebitCard) "储蓄卡" else "信用卡"

    // 1. 本地安全沙盒图片路径引用及加载
    val cardImageFile = remember(cardId) {
        File(File(context.filesDir, "scanned_cards"), "${cardId}.jpg")
    }
    val legacyImageExists = remember(cardImageFile) { cardImageFile.exists() }
    val hasCardImage = card.cardImages.isNotEmpty() || legacyImageExists
    var showFullscreenImage by remember { mutableStateOf(false) }
    var fullscreenImageIndex by remember { mutableStateOf(0) }

    val previewList = remember(card.cardImages, legacyImageExists) {
        val list = mutableListOf<PreviewImage>()
        card.cardImages.forEach { list.add(PreviewImage.Asset(it)) }
        if (legacyImageExists) {
            list.add(PreviewImage.LocalFile(cardImageFile))
        }
        list
    }

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
    var coreSectionExpanded by remember { mutableStateOf(true) }
    var mediaSectionExpanded by remember { mutableStateOf(false) }
    var limitFeeSectionExpanded by remember { mutableStateOf(false) }
    var benefitSectionExpanded by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(card.alias.ifBlank { "${cardCategoryText}详情" }) },
                navigationIcon = {
                    AppBackButton(
                        onClick = onBack,
                        tint = if (isDark) NeonCyan else GoldPrimary,
                        containerColor = MaterialTheme.colorScheme.surface,
                        borderColor = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.32f)
                    )
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

            Spacer(modifier = Modifier.height(16.dp))

            // 2. 核心信息区：对齐新建/编辑页的字段组织，优先展示卡号和有效期
            CollapsibleDetailSection(
                title = "基本信息",
                expanded = coreSectionExpanded,
                onExpandedChange = { coreSectionExpanded = it }
            ) {
                InfoRow(label = "卡类别", value = cardCategoryText)
                DetailDivider(isDark = isDark)

                CardNumberInfoRow(
                    cardNumber = card.cardNumber,
                    visible = isNumberVisible,
                    countdownProgress = countdownProgress,
                    isDark = isDark,
                    onToggleVisible = { isNumberVisible = !isNumberVisible },
                    onCopy = {
                        copyCardNumberToClipboard(context, card.cardNumber)
                    }
                )

                DetailDivider(isDark = isDark)

                InfoRow(label = "有效期 *", value = displayOrDash(card.valid))
                InfoRow(label = "国家 / 地区 *", value = displayOrDash(card.country))
                InfoRow(label = "发卡银行 *", value = displayOrDash(card.bank))

                if (card.cvv.isBlank()) {
                    InfoRow(label = "CVV 安全码", value = "--")
                } else {
                    SensitiveValueRow(
                        label = "CVV 安全码",
                        value = if (isCvvVisible) card.cvv else "•••",
                        visible = isCvvVisible,
                        isDark = isDark,
                        onToggleVisible = { isCvvVisible = !isCvvVisible }
                    )
                }

                InfoRow(label = "卡片别名", value = displayOrDash(card.alias))
                InfoRow(label = "卡片等级", value = displayOrDash(card.level))
                InfoRow(label = if (isDebitCard) "币种" else "结算币种", value = displayOrDash(card.type))
                InfoRow(label = "最后修改时间", value = formatDateTime(card.lastModifyTime))
            }

            Spacer(modifier = Modifier.height(16.dp))

            val expiryWarning = getExpiryWarningMessage(card)
            if (expiryWarning != null) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(NeonRed.copy(alpha = if (isDark) 0.14f else 0.08f))
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                ) {
                    Text(
                        text = expiryWarning,
                        color = NeonRed,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
                Spacer(modifier = Modifier.height(16.dp))
            }

            // 3. 年费收取到期橙色警示栏
            val annualFeeWarning = getAnnualFeeWarningMessage(card)
            if (!isDebitCard && annualFeeWarning != null) {
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

            // 如果卡片数据中有媒体文件，动态呈现跨端同步图片预览；旧版本沙盒图片作为兼容兜底。
            if (hasCardImage) {
                CollapsibleDetailSection(
                    title = "图片与附件",
                    expanded = mediaSectionExpanded,
                    onExpandedChange = { mediaSectionExpanded = it }
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "${previewList.size} 张图片 · 总大小 ${formatFileSize(previewList.sumOf { previewByteSize(it) })}",
                            color = if (isDark) TextGray else TextMuted,
                            fontSize = 12.sp
                        )
                        Text(
                            text = "横向滑动查看",
                            color = if (isDark) NeonCyan else GoldPrimary,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        previewList.forEachIndexed { index, preview ->
                            MediaThumbnail(
                                preview = preview,
                                index = index,
                                total = previewList.size,
                                isDark = isDark,
                                onClick = {
                                    fullscreenImageIndex = index
                                    showFullscreenImage = true
                                }
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))
            }

            // 4. 额度年费区块仅适用于信用卡
            if (!isDebitCard) {
                CollapsibleDetailSection(
                    title = "账单与还款",
                    expanded = limitFeeSectionExpanded,
                    onExpandedChange = { limitFeeSectionExpanded = it }
                ) {
                    val limitText = if (card.limit > 0.0) {
                        formatCurrencyAmount(card.type, card.limit)
                    } else {
                        "--"
                    }
                    InfoRow(label = "额度", value = limitText)
                    InfoRow(label = "账单日", value = if (card.accountBillDate.isNotEmpty()) "每月 ${card.accountBillDate} 日" else "--")
                    InfoRow(label = "还款日", value = if (card.dueDate.isNotEmpty()) "每月 ${card.dueDate} 日" else "--")
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
                        "3" -> "终免年费"
                        else -> "--"
                    }
                    val statusColor = when (card.isQualified) {
                        "1" -> if (isDark) NeonGreen else ForestGreen
                        "2" -> if (isDark) NeonRed else WarmOrange
                        else -> if (isDark) NeonCyan else GoldPrimary
                    }
                    
                    InfoRow(label = "年费达标状态", value = statusText, valueColor = statusColor)
                    InfoRow(label = "年费金额", value = annualFeeAmountText(card))
                    
                    InfoRow(
                        label = "下次年费扣除日",
                        value = if (card.nextAnnualFeeCollectionTime != null && card.isQualified != "3") formatDate(card.nextAnnualFeeCollectionTime!!) else "--"
                    )
                    InfoRow(label = "上次提额日期", value = card.lastTime?.let { formatDate(it) } ?: "--")
                }

                Spacer(modifier = Modifier.height(16.dp))
            }

            // 5. 附加权益与备注区块
            CollapsibleDetailSection(
                title = "卡片属性与备注",
                expanded = benefitSectionExpanded,
                onExpandedChange = { benefitSectionExpanded = it }
            ) {
                Column(modifier = Modifier.padding(vertical = 6.dp)) {
                    Text(if (isDebitCard) "卡片权益" else "核心年费权益", color = if (isDark) TextGray else TextMuted, fontSize = 12.sp)
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = displayOrDash(card.equity),
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
                        text = displayOrDash(card.remark),
                        color = MaterialTheme.colorScheme.onBackground,
                        fontSize = 14.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            DetailSection(title = "安全与管理") {
                OutlinedButton(
                    onClick = { showDeleteDialog = true },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.error.copy(alpha = 0.55f))
                ) {
                    Icon(Icons.Filled.Delete, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("删除这张卡")
                }
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }

    // 确认删除警告弹窗
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("确认删除卡片吗？") },
            text = { Text("删除后，这张卡会从当前设备移除，并在下次同步时同步到云端。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        
                        // 1. 级联删除本地沙盒存储的扫描件图片文件，防积攒冗余存储垃圾
                        if (cardImageFile.exists()) {
                            cardImageFile.delete()
                        }
                        
                        SyncCoordinator.commitCardDelete(context, cardId)
                        Toast.makeText(context, "卡片已删除", Toast.LENGTH_SHORT).show()
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

    // 2. 全屏大图预览模态 Dialog (支持捏合缩放、双击还原与左右Pager滑动)
    if (showFullscreenImage && previewList.isNotEmpty()) {
        val pagerState = rememberPagerState(
            initialPage = fullscreenImageIndex.coerceIn(0, previewList.lastIndex),
            pageCount = { previewList.size }
        )
        val pagerScope = rememberCoroutineScope()
        Dialog(
            onDismissRequest = { showFullscreenImage = false },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black),
                contentAlignment = Alignment.Center
            ) {
                // 顶层整体的背景轻触关闭
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clickable { showFullscreenImage = false }
                )

                // 监控全局图片缩放因子，若被放大，锁定左右划页
                var isZoomed by remember { mutableStateOf(false) }

                HorizontalPager(
                    state = pagerState,
                    userScrollEnabled = !isZoomed,
                    modifier = Modifier.fillMaxSize()
                ) { page ->
                    val previewImg = previewList[page]
                    val bitmap = remember(previewImg) {
                        when (previewImg) {
                            is PreviewImage.Asset -> CardImageCodec.decodeBitmap(previewImg.asset)
                            is PreviewImage.LocalFile -> {
                                try {
                                    BitmapFactory.decodeFile(previewImg.file.absolutePath)
                                } catch (e: Exception) {
                                    null
                                }
                            }
                        }
                    }

                    if (bitmap != null) {
                        ZoomableImage(
                            bitmap = bitmap,
                            contentDescription = "预览图片 ${page + 1}",
                            onScaleChanged = { scale: Float ->
                                isZoomed = scale > 1f
                            },
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(16.dp)
                        )
                    } else {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("图片加载失败", color = MaterialTheme.colorScheme.error)
                        }
                    }
                }

                if (previewList.size > 1) {
                    IconButton(
                        onClick = {
                            pagerScope.launch {
                                val target = if (pagerState.currentPage == 0) previewList.lastIndex else pagerState.currentPage - 1
                                pagerState.animateScrollToPage(target)
                            }
                        },
                        modifier = Modifier
                            .align(Alignment.CenterStart)
                            .padding(start = 12.dp)
                            .size(46.dp)
                            .background(Color.Black.copy(alpha = 0.48f), CircleShape)
                    ) {
                        Icon(Icons.Filled.ChevronLeft, contentDescription = "上一张", tint = Color.White)
                    }

                    IconButton(
                        onClick = {
                            pagerScope.launch {
                                val target = if (pagerState.currentPage == previewList.lastIndex) 0 else pagerState.currentPage + 1
                                pagerState.animateScrollToPage(target)
                            }
                        },
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .padding(end = 12.dp)
                            .size(46.dp)
                            .background(Color.Black.copy(alpha = 0.48f), CircleShape)
                    ) {
                        Icon(Icons.Filled.ChevronRight, contentDescription = "下一张", tint = Color.White)
                    }
                }

                // 底部指示器 (如: 1 / 3)
                if (previewList.size > 1) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = 32.dp)
                            .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(20.dp))
                            .padding(horizontal = 14.dp, vertical = 6.dp)
                    ) {
                        Text(
                            text = "${pagerState.currentPage + 1} / ${previewList.size}",
                            color = Color.White,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
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

@Composable
private fun CardNumberInfoRow(
    cardNumber: String,
    visible: Boolean,
    countdownProgress: Float,
    isDark: Boolean,
    onToggleVisible: () -> Unit,
    onCopy: () -> Unit
) {
    val displayNumber = if (cardNumber.isBlank()) {
        "--"
    } else if (visible) {
        formatSpacingCardNumber(cardNumber)
    } else {
        formatMaskedCardNumber(cardNumber)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "银行卡卡号 *",
                color = if (isDark) TextGray else TextMuted,
                fontSize = 12.sp
            )
            Spacer(modifier = Modifier.height(4.dp))
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(enabled = cardNumber.isNotBlank(), onClick = onCopy)
                    .padding(vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = displayNumber,
                    color = MaterialTheme.colorScheme.onBackground,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = FontFamily.Monospace,
                    letterSpacing = 1.sp
                )
                Spacer(modifier = Modifier.width(6.dp))
                if (cardNumber.isNotBlank()) {
                    Icon(
                        imageVector = Icons.Filled.ContentCopy,
                        contentDescription = "复制卡号",
                        tint = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.78f),
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
            if (cardNumber.isNotBlank()) {
                Text(
                    text = "点击卡号复制完整号码",
                    color = if (isDark) TextGray else TextMuted,
                    fontSize = 11.sp
                )
            }
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            if (visible) {
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

            IconButton(onClick = onToggleVisible) {
                Icon(
                    imageVector = if (visible) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                    contentDescription = "卡号可见性",
                    tint = if (isDark) NeonCyan else GoldPrimary
                )
            }
        }
    }
}

@Composable
private fun SensitiveValueRow(
    label: String,
    value: String,
    visible: Boolean,
    isDark: Boolean,
    onToggleVisible: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                color = if (isDark) TextGray else TextMuted,
                fontSize = 12.sp
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = value,
                color = MaterialTheme.colorScheme.onBackground,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.Monospace
            )
        }

        IconButton(onClick = onToggleVisible) {
            Icon(
                imageVector = if (visible) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                contentDescription = "${label}可见性",
                tint = if (isDark) NeonCyan else GoldPrimary
            )
        }
    }
}

@Composable
private fun DetailDivider(isDark: Boolean) {
    HorizontalDivider(
        color = if (isDark) Color.White.copy(alpha = 0.06f) else Color.Black.copy(alpha = 0.06f),
        modifier = Modifier.padding(vertical = 4.dp)
    )
}

@Composable
private fun MediaThumbnail(
    preview: PreviewImage,
    index: Int,
    total: Int,
    isDark: Boolean,
    onClick: () -> Unit
) {
    val bitmap = remember(preview) { decodePreviewBitmap(preview) }

    Column(
        modifier = Modifier.width(170.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1.586f)
                .clip(RoundedCornerShape(12.dp))
                .background(if (isDark) DarkBg else Color(0xFFF8FAFC))
                .border(
                    width = 1.dp,
                    color = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.22f),
                    shape = RoundedCornerShape(12.dp)
                )
                .clickable(onClick = onClick)
                .padding(5.dp),
            contentAlignment = Alignment.Center
        ) {
            if (bitmap != null) {
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = "卡片图片 ${index + 1}",
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(RoundedCornerShape(9.dp)),
                    contentScale = androidx.compose.ui.layout.ContentScale.Fit
                )
            } else {
                Text("无法预览", color = MaterialTheme.colorScheme.error, fontSize = 12.sp)
            }

            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .background(Color.Black.copy(alpha = 0.62f), shape = RoundedCornerShape(8.dp))
                    .padding(horizontal = 7.dp, vertical = 3.dp)
            ) {
                Text("${index + 1}/$total", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
            }
        }
        Text(
            text = previewName(preview, index),
            color = MaterialTheme.colorScheme.onSurface,
            fontSize = 11.sp,
            maxLines = 1,
            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
        )
        Text(
            text = "上传时间 ${formatPreviewUploadTime(preview)}",
            color = if (isDark) TextGray else TextMuted,
            fontSize = 10.sp,
            maxLines = 1
        )
        Text(
            text = "文件大小 ${formatFileSize(previewByteSize(preview))}",
            color = if (isDark) TextGray else TextMuted,
            fontSize = 10.sp,
            maxLines = 1
        )
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
    Column(modifier = Modifier.fillMaxWidth()) {
        if (title.isNotBlank()) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(vertical = 12.dp)
            )
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp),
            content = content
        )
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }
}

@Composable
fun CollapsibleDetailSection(
    title: String,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onExpandedChange(!expanded) }
                .padding(horizontal = 4.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f)
            )
            Icon(
                imageVector = if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                contentDescription = if (expanded) "收起" else "展开",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

        AnimatedVisibility(visible = expanded) {
            Column(modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp)) {
                content()
            }
        }
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

private fun copyCardNumberToClipboard(context: android.content.Context, cardNumber: String) {
    val cleanNumber = cardNumber.filter { it.isDigit() }
    if (cleanNumber.isBlank()) {
        Toast.makeText(context, "暂无可复制的卡号", Toast.LENGTH_SHORT).show()
        return
    }

    val clipboard = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
    clipboard.setPrimaryClip(android.content.ClipData.newPlainText("银行卡卡号", cleanNumber))
    Toast.makeText(context, "已复制完整卡号", Toast.LENGTH_SHORT).show()
}

private fun decodePreviewBitmap(preview: PreviewImage): android.graphics.Bitmap? {
    return when (preview) {
        is PreviewImage.Asset -> CardImageCodec.decodeBitmap(preview.asset)
        is PreviewImage.LocalFile -> {
            try {
                BitmapFactory.decodeFile(preview.file.absolutePath)
            } catch (e: Exception) {
                null
            }
        }
    }
}

private fun formatCurrencyAmount(currency: String, value: Double): String {
    val currencyCode = currency.trim()
    val symbol = when (currencyCode.uppercase()) {
        "CNY", "JPY" -> "¥"
        "USD" -> "$"
        "EUR" -> "€"
        "GBP" -> "£"
        "HKD" -> "HK$"
        "MOP" -> "MOP$"
        "TWD" -> "NT$"
        "SGD" -> "S$"
        "AUD" -> "A$"
        "CAD" -> "C$"
        else -> ""
    }
    val amountText = "$symbol${String.format("%,.2f", value)}"
    return listOf(currencyCode, amountText).filter { it.isNotBlank() }.joinToString(" ")
}

private fun annualFeeAmountText(card: SharedCard): String {
    return if (card.annualFee > 0.0) {
        formatCurrencyAmount(card.type, card.annualFee)
    } else {
        "--"
    }
}

private fun displayOrDash(value: String?): String {
    return value?.trim()?.takeIf { it.isNotEmpty() } ?: "--"
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
private fun getAnnualFeeWarningMessage(card: SharedCard): String? {
    val result = CardReminderRules.annualFeeDetection(card) ?: return null
    return when (result.kind) {
        AnnualFeeDetectionKind.UNQUALIFIED ->
            "⚠️ 年费未达标：距离扣年费时间还剩 ${result.days} 天，请尽快确认刷卡笔数或额度。"
        AnnualFeeDetectionKind.WARNING ->
            "⚠️ 年费即将扣收：${result.days} 天后收取年费，请确认今年是否已经达标。"
        AnnualFeeDetectionKind.OVERDUE ->
            "⚠️ 年费已过期：已过 ${result.days} 天，请核对是否已扣费并更新卡片状态。"
    }
}

private fun getExpiryWarningMessage(card: SharedCard): String? {
    return when (CardReminderRules.cardExpiryStatus(card.valid)) {
        CardExpiryStatus.EXPIRED -> "⚠️ 卡片有效期已过期：请确认是否已换发新卡并更新有效期。"
        CardExpiryStatus.SOON_EXPIRING -> "⚠️ 卡片将在 6 个月内到期：请留意银行换卡进度。"
        CardExpiryStatus.NORMAL, null -> null
    }
}

/**
 * 大图预览融合数据密封类
 */
sealed class PreviewImage {
    data class Asset(val asset: CardImageAsset) : PreviewImage()
    data class LocalFile(val file: java.io.File) : PreviewImage()
}

private fun previewByteSize(preview: PreviewImage): Long = when (preview) {
    is PreviewImage.Asset -> CardImageCodec.dataByteSize(preview.asset)
    is PreviewImage.LocalFile -> preview.file.length().coerceAtLeast(0L)
}

private fun previewName(preview: PreviewImage, index: Int): String = when (preview) {
    is PreviewImage.Asset -> preview.asset.name.ifBlank { preview.asset.source.ifBlank { "图片 ${index + 1}" } }
    is PreviewImage.LocalFile -> preview.file.name.ifBlank { "图片 ${index + 1}" }
}

private fun formatPreviewUploadTime(preview: PreviewImage): String {
    val rawTimestamp = when (preview) {
        is PreviewImage.Asset -> preview.asset.createdAt
        is PreviewImage.LocalFile -> preview.file.lastModified()
    }
    val timestamp = if (preview is PreviewImage.Asset && rawTimestamp in 1 until 1_000_000_000_000L) {
        rawTimestamp * 1000
    } else {
        rawTimestamp
    }
    return if (timestamp > 0) formatDateTime(timestamp) else "未知"
}

private fun formatFileSize(bytes: Long): String {
    val value = bytes.coerceAtLeast(0L)
    return when {
        value < 1024 -> "$value B"
        value < 1024L * 1024 -> String.format(java.util.Locale.CHINA, "%.1f KB", value / 1024.0)
        value < 1024L * 1024 * 1024 -> String.format(java.util.Locale.CHINA, "%.1f MB", value / 1024.0 / 1024.0)
        else -> String.format(java.util.Locale.CHINA, "%.1f GB", value / 1024.0 / 1024.0 / 1024.0)
    }
}

/**
 * 手势捏合缩放（Pinch-to-zoom）、双击还原与拖拽 pan 的大图渲染组件
 */
@Composable
private fun ZoomableImage(
    bitmap: android.graphics.Bitmap,
    contentDescription: String,
    onScaleChanged: (Float) -> Unit,
    modifier: Modifier = Modifier
) {
    var scale by remember { mutableStateOf(1f) }
    var offset by remember { mutableStateOf(androidx.compose.ui.geometry.Offset.Zero) }

    Box(
        modifier = modifier
            .clipToBounds()
            .pointerInput(Unit) {
                detectTransformGestures { _, pan, zoom, _ ->
                    val newScale = (scale * zoom).coerceIn(1f, 5f)
                    scale = newScale
                    onScaleChanged(newScale)
                    if (newScale > 1f) {
                        offset += pan
                    } else {
                        offset = androidx.compose.ui.geometry.Offset.Zero
                    }
                }
            }
            .pointerInput(Unit) {
                detectTapGestures(
                    onDoubleTap = {
                        if (scale > 1f) {
                            scale = 1f
                            offset = androidx.compose.ui.geometry.Offset.Zero
                        } else {
                            scale = 2.5f
                        }
                        onScaleChanged(scale)
                    }
                )
            }
    ) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = contentDescription,
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer(
                    scaleX = scale,
                    scaleY = scale,
                    translationX = offset.x,
                    translationY = offset.y
                ),
            contentScale = androidx.compose.ui.layout.ContentScale.Fit
        )
    }
}
