package com.example.creditcard.ui

import android.app.DatePickerDialog
import android.graphics.Bitmap
import android.graphics.Canvas as AndroidCanvas
import android.graphics.Paint as AndroidPaint
import android.widget.Toast
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Save
import androidx.compose.material.icons.filled.Nfc
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.*
import com.example.creditcard.ui.main.CardBrandBadge
import com.example.creditcard.ui.main.getCardBrand
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager
import com.example.creditcard.utils.NfcScannerManager
import com.example.creditcard.utils.CardScanProgressManager
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.UUID

/**
 * 录入信用卡三阶段状态机
 */
enum class FormStep {
    SCAN_NFC,     // 1. NFC 扫描录入状态
    SCAN_CAMERA,  // 2. 相机激光扫描录入状态
    MANUAL_FORM   // 3. 常规手动表单录入状态
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CardFormScreen(
    cardId: String?,
    onBack: () -> Unit,
    onNavigateToDetail: (String) -> Unit
) {
    val context = LocalContext.current
    val isDark by ThemeManager.isDarkTheme.collectAsState()
    val db = remember { DatabaseHelper(context) }

    // 判断是编辑还是新建
    val isEditMode = !cardId.isNullOrEmpty()
    val originalCard = remember(cardId) {
        if (cardId.isNullOrEmpty()) null else db.getCardById(cardId)
    }

    // ==========================================
    // NFC、相机状态与步骤管理器
    // ==========================================
    val nfcAdapter = remember { android.nfc.NfcAdapter.getDefaultAdapter(context) }
    val isNfcSupported = remember { nfcAdapter != null }
    
    // 生成卡片唯一关联的真正 ID (新建模式下提前锁定，利于在保存卡片前静默命名保存扫描原件图片)
    val tempCardId = remember { UUID.randomUUID().toString() }
    val finalCardId = cardId ?: tempCardId
    
    // 是否已确认成功保存卡片，用于在退出时防空转垃圾回收 (若用户中途退出新建，则静默回收未保存卡片的本地临时扫描原件)
    var isSaved by remember { mutableStateOf(false) }

    // 初始化进入步骤：新建模式下若有 NFC 硬件进入 NFC 雷达扫描，否则降级至相机扫描，编辑模式直接进常规表单
    var currentStep by remember {
        mutableStateOf(
            if (isEditMode) FormStep.MANUAL_FORM else {
                if (isNfcSupported) FormStep.SCAN_NFC else FormStep.SCAN_CAMERA
            }
        )
    }

    // ==========================================
    // 表单状态变量
    // ==========================================
    var country by remember { mutableStateOf(originalCard?.country ?: "中国") }
    var bank by remember { mutableStateOf(originalCard?.bank ?: "") }
    var alias by remember { mutableStateOf(originalCard?.alias ?: "") }
    var level by remember { mutableStateOf(originalCard?.level ?: "白金卡") }
    
    var cardNumber by remember { mutableStateOf(originalCard?.cardNumber ?: "") }
    var cvv by remember { mutableStateOf(originalCard?.cvv ?: "") }
    var valid by remember { mutableStateOf(originalCard?.valid ?: "") }
    
    var limit by remember { mutableStateOf(originalCard?.limit ?: 20000.0) }
    var type by remember { mutableStateOf(originalCard?.type ?: "CNY") }
    var isSharedLimit by remember { mutableStateOf(originalCard?.isSharedLimit ?: true) }
    
    var accountBillDate by remember { mutableStateOf(originalCard?.accountBillDate ?: "") }
    var dueDate by remember { mutableStateOf(originalCard?.dueDate ?: "") }
    var billingDaySpendingToNextBill by remember { mutableStateOf(originalCard?.billingDaySpendingToNextBill ?: true) }
    
    var annualFee by remember { mutableStateOf(originalCard?.annualFee ?: 0.0) }
    var isQualified by remember { mutableStateOf(originalCard?.isQualified ?: "2") }
    var nextAnnualFeeCollectionTime by remember { mutableStateOf(originalCard?.nextAnnualFeeCollectionTime) }
    var lastTime by remember { mutableStateOf(originalCard?.lastTime) }
    
    var equity by remember { mutableStateOf(originalCard?.equity ?: "") }
    var remark by remember { mutableStateOf(originalCard?.remark ?: "") }

    // 已录入/扫描出的卡片图片路径
    var scannedImagePath by remember {
        mutableStateOf<String?>(
            if (isEditMode) {
                val file = File(File(context.filesDir, "scanned_cards"), "${cardId}.jpg")
                if (file.exists()) file.absolutePath else null
            } else null
        )
    }

    // ==========================================
    // 重名冲突对话框与拦截状态
    // ==========================================
    var showConflictDialog by remember { mutableStateOf(false) }
    var existingCardIdForConflict by remember { mutableStateOf("") }
    var scannedTempNumber by remember { mutableStateOf("") }
    var scannedTempValid by remember { mutableStateOf("") }
    var scannedTempImagePath by remember { mutableStateOf<String?>(null) }
    var scannedTempSource by remember { mutableStateOf("NFC") }

    /**
     * 核心重名冲突拦截比对方法
     */
    fun handleScannedCard(scannedNo: String, scannedVal: String, imagePath: String?, source: String) {
        val existingCard = db.getAllCards().firstOrNull { it.cardNumber == scannedNo }
        if (existingCard != null) {
            // 本地已有相同卡号，拉起冲突确认引导弹窗
            scannedTempNumber = scannedNo
            scannedTempValid = scannedVal
            scannedTempImagePath = imagePath
            scannedTempSource = source
            existingCardIdForConflict = existingCard.id
            showConflictDialog = true
        } else {
            // 无任何重名卡号，直接愉快代入手动表单
            cardNumber = scannedNo
            valid = scannedVal
            scannedImagePath = imagePath
            currentStep = FormStep.MANUAL_FORM
        }
    }

    /**
     * Canvas 绘制高清渐变银行卡 Mock 扫描件并写入本地沙盒
     */
    fun generateMockScannedCardImage(cardNo: String, bankName: String): String {
        val dir = File(context.filesDir, "scanned_cards")
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, "${finalCardId}.jpg")
        
        val bitmap = Bitmap.createBitmap(800, 500, Bitmap.Config.ARGB_8888)
        val canvas = AndroidCanvas(bitmap)
        val paint = AndroidPaint()
        
        // 1. 绘制极富质感的深蓝渐变银行卡背景
        val colors = intArrayOf(0xFF1E293B.toInt(), 0xFF0F172A.toInt(), 0xFF020617.toInt())
        paint.shader = android.graphics.LinearGradient(
            0f, 0f, 800f, 500f,
            colors, null, android.graphics.Shader.TileMode.CLAMP
        )
        canvas.drawRoundRect(0f, 0f, 800f, 500f, 32f, 32f, paint)
        paint.shader = null
        
        // 2. 绘制醒目的青色扫描件边框
        paint.color = 0xFF22D3EE.toInt() // NeonCyan
        paint.style = android.graphics.Paint.Style.STROKE
        paint.strokeWidth = 6f
        canvas.drawRoundRect(3f, 3f, 797f, 497f, 32f, 32f, paint)
        
        // 3. 绘制装饰性金色感应芯片
        paint.color = 0xFFFBBF24.toInt() // Gold
        paint.style = android.graphics.Paint.Style.FILL
        canvas.drawRoundRect(80f, 150f, 180f, 220f, 12f, 12f, paint)
        
        // 4. 绘制银行名称
        paint.color = android.graphics.Color.WHITE
        paint.textSize = 34f
        paint.isFakeBoldText = true
        canvas.drawText(bankName.ifEmpty { "信用卡扫描原件" }, 80f, 80f, paint)
        
        // 5. 绘制卡号
        paint.textSize = 44f
        paint.letterSpacing = 0.08f
        val formattedNo = cardNo.chunked(4).joinToString("  ")
        canvas.drawText(formattedNo, 80f, 310f, paint)
        
        // 6. 绘制 SCANNED ORIGINAL 半透明水印
        paint.color = 0x1A22D3EE.toInt()
        paint.textSize = 72f
        paint.isFakeBoldText = true
        paint.textSkewX = -0.25f
        canvas.drawText("SCANNED ORIGINAL", 120f, 440f, paint)
        
        try {
            val fos = FileOutputStream(file)
            bitmap.compress(Bitmap.CompressFormat.JPEG, 95, fos)
            fos.flush()
            fos.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return file.absolutePath
    }

    // ==========================================
    // 监听物理 NFC 刷卡感应通知广播
    // ==========================================
    LaunchedEffect(Unit) {
        NfcScannerManager.nfcCardData.collect { (scannedNo, scannedVal) ->
            if (currentStep == FormStep.SCAN_NFC) {
                // 收到物理刷卡信号，执行 Mock 图片生成，并触发重名拦截比对
                val path = generateMockScannedCardImage(scannedNo, bank)
                handleScannedCard(scannedNo, scannedVal, path, "NFC")
            }
        }
    }

    // ==========================================
    // 监听页面生命周期 Resume，完美拦截处理“详情页流转决策”
    // ==========================================
    val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    val lifecycleState by lifecycleOwner.lifecycle.currentStateFlow.collectAsState()
    
    LaunchedEffect(lifecycleState) {
        if (lifecycleState == androidx.lifecycle.Lifecycle.State.RESUMED) {
            // 如果处于待录入挂起状态，说明刚从已存在的卡片详情页跳转返回！
            if (CardScanProgressManager.isPendingScan) {
                if (CardScanProgressManager.isRejectedFromDetail) {
                    // 情况 A：用户在详情页拒绝了继续录入，恢复至之前的扫描状态 (NFC 或 相机)
                    currentStep = if (CardScanProgressManager.scanSource == "NFC") FormStep.SCAN_NFC else FormStep.SCAN_CAMERA
                    CardScanProgressManager.clear()
                    Toast.makeText(context, "已退回扫描界面", Toast.LENGTH_SHORT).show()
                } else {
                    // 情况 B：用户同意继续录入，直接代入数据到手动表单
                    cardNumber = CardScanProgressManager.pendingScanCardNumber ?: ""
                    valid = CardScanProgressManager.pendingScanValid ?: ""
                    scannedImagePath = CardScanProgressManager.pendingScanImagePath
                    currentStep = FormStep.MANUAL_FORM
                    CardScanProgressManager.clear()
                    Toast.makeText(context, "扫描数据已成功代入表单", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    // 新建模式中途放弃的临时扫描原件垃圾回收
    DisposableEffect(Unit) {
        onDispose {
            if (!isEditMode && !isSaved) {
                // 如果是新建模式，且最终用户未保存退出，静默清空本地生成的该卡片图片
                val file = File(File(context.filesDir, "scanned_cards"), "${tempCardId}.jpg")
                if (file.exists()) {
                    file.delete()
                }
            }
        }
    }

    // 监听卡号前缀判定卡组织品牌
    val detectedBrand = remember(cardNumber) { getCardBrand(cardNumber) }

    // ==========================================
    // 共享额度智能联动逻辑
    // ==========================================
    // 查询同国家同银行是否存在其他的“共享额度”卡片，并提取其共享额度
    val existingSharedLimitCard = remember(cardId, country, bank, type, isSharedLimit) {
        if (isSharedLimit && bank.trim().isNotEmpty()) {
            val all = db.getAllCards()
            all.firstOrNull { it.id != cardId && it.country == country && it.bank == bank && it.type == type && it.isSharedLimit }
        } else null
    }
    val shouldLockSharedLimitInput = !isEditMode && existingSharedLimitCard != null

    // 新增同组共享卡时沿用既有额度；编辑已有卡时允许修改，并在保存前批量确认。
    LaunchedEffect(existingSharedLimitCard) {
        if (!isEditMode && existingSharedLimitCard != null) {
            limit = existingSharedLimitCard.limit
        }
    }

    // 全局修改警告弹窗控制
    var showSharedLimitWarningDialog by remember { mutableStateOf(false) }

    val handleBackAction = {
        if (!isEditMode && currentStep == FormStep.MANUAL_FORM) {
            // 新增：如果是新建模式且正处于手动表单，返回时自动退回到之前的扫描录入状态
            currentStep = if (isNfcSupported) FormStep.SCAN_NFC else FormStep.SCAN_CAMERA
        } else {
            onBack()
        }
    }

    when (currentStep) {
        FormStep.SCAN_NFC -> {
            NfcScanLayout(
                context = context,
                isDark = isDark,
                onBack = onBack,
                onSwitchCamera = { currentStep = FormStep.SCAN_CAMERA },
                onSwitchManual = { currentStep = FormStep.MANUAL_FORM },
                onSimulateScanned = { scannedNo, scannedVal ->
                    val path = generateMockScannedCardImage(scannedNo, bank)
                    handleScannedCard(scannedNo, scannedVal, path, "NFC")
                }
            )
        }
        FormStep.SCAN_CAMERA -> {
            CameraScanLayout(
                context = context,
                isDark = isDark,
                lifecycleOwner = lifecycleOwner,
                onBack = onBack,
                onSwitchManual = { currentStep = FormStep.MANUAL_FORM },
                onSimulateScanned = { scannedNo, scannedVal ->
                    val path = generateMockScannedCardImage(scannedNo, bank)
                    handleScannedCard(scannedNo, scannedVal, path, "Camera")
                }
            )
        }
        FormStep.MANUAL_FORM -> {
            Scaffold(
                topBar = {
                    TopAppBar(
                        title = { Text(if (isEditMode) "修改信用卡" else "添加信用卡", fontWeight = FontWeight.Bold) },
                        navigationIcon = {
                            IconButton(onClick = handleBackAction) {
                                Icon(imageVector = Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                            }
                        },
                        actions = {
                            // 保存 FAB
                            IconButton(onClick = {
                                // 表单格式校验
                                if (bank.trim().isEmpty()) {
                                    Toast.makeText(context, "请输入银行名称", Toast.LENGTH_SHORT).show()
                                    return@IconButton
                                }
                                if (cardNumber.trim().isEmpty()) {
                                    Toast.makeText(context, "请输入卡号", Toast.LENGTH_SHORT).show()
                                    return@IconButton
                                }

                                // 检测是否发生了共享额度的“全局修改”
                                val sameGroupCards = if (isSharedLimit) {
                                    db.getAllCards().filter { it.id != cardId && it.country == country && it.bank == bank && it.type == type && it.isSharedLimit }
                                } else emptyList()

                                if (sameGroupCards.isNotEmpty() && limit != sameGroupCards[0].limit) {
                                    // 额度发生改变，且存在同组共享卡，拉起全局更新警示
                                    showSharedLimitWarningDialog = true
                                } else {
                                    // 直接保存，设置 isSaved = true 避免图片垃圾回收
                                    isSaved = true
                                    executeSaveCard(
                                        context, db, cardId, originalCard, country, bank, alias, level,
                                        cardNumber, cvv, valid, limit, type, isSharedLimit,
                                        accountBillDate, dueDate, billingDaySpendingToNextBill,
                                        annualFee, isQualified, nextAnnualFeeCollectionTime, lastTime, equity, remark
                                    )
                                    onBack()
                                }
                            }) {
                                Icon(
                                    imageVector = Icons.Filled.Save,
                                    contentDescription = "保存",
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
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Spacer(modifier = Modifier.height(4.dp))

                    // 新增：如果为新建卡片提供重新回到扫描的快捷 UX 入口
                    if (!isEditMode) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End
                        ) {
                            TextButton(onClick = {
                                currentStep = if (isNfcSupported) FormStep.SCAN_NFC else FormStep.SCAN_CAMERA
                            }) {
                                Icon(imageVector = Icons.Default.PhotoCamera, contentDescription = "扫描")
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("NFC/相机扫描录入", fontSize = 12.sp, color = if (isDark) NeonCyan else GoldPrimary)
                            }
                        }
                    }

                    // ==========================================
                    // Section 1: 🌏 基础信息 (BASIC INFO)
                    // ==========================================
                    FormSection(title = "🌏 基础信息") {
                        OutlinedTextField(
                            value = country,
                            onValueChange = { country = it },
                            label = { Text("国家 / 地区") },
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = bank,
                            onValueChange = { bank = it },
                            label = { Text("银行名称") },
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = alias,
                            onValueChange = { alias = it },
                            label = { Text("卡片别名 (如：车主白金卡)") },
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = level,
                            onValueChange = { level = it },
                            label = { Text("卡片等级 (如：白金卡, 金卡)") },
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )
                    }

                    // ==========================================
                    // Section 2: 💳 安全信息 (CARD INFO)
                    // ==========================================
                    FormSection(title = "💳 安全信息") {
                        OutlinedTextField(
                            value = cardNumber,
                            onValueChange = { input ->
                                // 过滤非数字，并限制长度最长为 20 位
                                val filtered = input.filter { it.isDigit() }.take(20)
                                cardNumber = filtered
                            },
                            label = { Text("信用卡卡号") },
                            placeholder = { Text("请输入数字") },
                            trailingIcon = {
                                if (detectedBrand != "Unknown") {
                                    CardBrandBadge(brand = detectedBrand)
                                }
                            },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )

                        if (cardNumber.isNotEmpty()) {
                            Text(
                                text = "排版预览: " + formatSpacingCardNumber(cardNumber),
                                fontSize = 12.sp,
                                fontFamily = FontFamily.Monospace,
                                color = if (isDark) NeonCyan else GoldPrimary,
                                modifier = Modifier.padding(top = 4.dp, start = 4.dp)
                            )
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            OutlinedTextField(
                                value = cvv,
                                onValueChange = { input ->
                                    // CVV 最长 4 位数字
                                    cvv = input.filter { it.isDigit() }.take(4)
                                },
                                label = { Text("CVV") },
                                placeholder = { Text("***") },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                modifier = Modifier.weight(1f),
                                colors = getOutlinedTextFieldColors(isDark)
                            )

                            OutlinedTextField(
                                value = valid,
                                onValueChange = { input ->
                                    // 自动排版有效期 MM/YY，当输入两位月数后，自动补上斜杠 '/'
                                    var clean = input.replace("/", "")
                                    if (clean.length > 4) clean = clean.substring(0, 4)
                                    valid = if (clean.length >= 2) {
                                        clean.substring(0, 2) + "/" + clean.substring(2)
                                    } else {
                                        clean
                                    }
                                },
                                label = { Text("有效期 (MM/YY)") },
                                placeholder = { Text("如: 08/29") },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                modifier = Modifier.weight(1f),
                                colors = getOutlinedTextFieldColors(isDark)
                            )
                        }
                    }

                    // ==========================================
                    // Section 3: 💰 额度年费 (LIMITS & FEES)
                    // ==========================================
                    FormSection(title = "💰 额度与年费") {
                        // 币种与共享开关行
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            OutlinedTextField(
                                value = type,
                                onValueChange = { type = it.uppercase().take(3) },
                                label = { Text("结算币种 (如 CNY, USD)") },
                                modifier = Modifier.weight(1f),
                                colors = getOutlinedTextFieldColors(isDark)
                            )

                            Spacer(modifier = Modifier.width(16.dp))

                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("共享额度", fontSize = 11.sp, color = if (isDark) TextGray else TextMuted)
                                Switch(
                                    checked = isSharedLimit,
                                    onCheckedChange = { isSharedLimit = it },
                                    colors = SwitchDefaults.colors(
                                        checkedThumbColor = if (isDark) NeonCyan else GoldPrimary,
                                        checkedTrackColor = if (isDark) NeonCyan.copy(alpha = 0.3f) else GoldPrimary.copy(alpha = 0.3f)
                                    )
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        // 额度滑块及输入锁定提示
                        Text(
                            text = "信用卡额度: $${String.format("%,.0f", limit)} $type",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                        
                        // 共享额度智能提示
                        if (existingSharedLimitCard != null) {
                            Text(
                                text = if (shouldLockSharedLimitInput) {
                                    "🔒 已自动关联同银行共享额度组: $${String.format("%,.0f", existingSharedLimitCard.limit)} $type"
                                } else {
                                    "同银行共享额度组当前额度: $${String.format("%,.0f", existingSharedLimitCard.limit)} $type"
                                },
                                color = if (isDark) NeonGreen else ForestGreen,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                modifier = Modifier.padding(vertical = 4.dp)
                            )
                        }

                        Slider(
                            value = limit.toFloat(),
                            onValueChange = { limit = it.toDouble() },
                            valueRange = 0f..500000f,
                            steps = 100,
                            enabled = !shouldLockSharedLimitInput,
                            colors = SliderDefaults.colors(
                                thumbColor = if (isDark) NeonCyan else GoldPrimary,
                                activeTrackColor = if (isDark) NeonCyan else GoldPrimary
                            )
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = limit.toString(),
                            onValueChange = { input ->
                                limit = input.toDoubleOrNull() ?: 0.0
                            },
                            label = { Text("精准额度数值") },
                            enabled = !shouldLockSharedLimitInput,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = annualFee.toString(),
                            onValueChange = { input ->
                                annualFee = input.toDoubleOrNull() ?: 0.0
                            },
                            label = { Text("年费金额") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        // 年费达标选择
                        Text("年费减免政策", fontSize = 12.sp, color = if (isDark) TextGray else TextMuted)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            val states = listOf("1" to "已达标", "2" to "未达标", "3" to "终身免")
                            states.forEach { (code, labelText) ->
                                FilterChip(
                                    selected = isQualified == code,
                                    onClick = { isQualified = code },
                                    label = { Text(labelText) },
                                    modifier = Modifier.weight(1f),
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = if (isDark) NeonCyan.copy(alpha = 0.2f) else GoldPrimary.copy(alpha = 0.15f),
                                        selectedLabelColor = if (isDark) NeonCyan else GoldPrimary
                                    )
                                )
                            }
                        }

                        if (isQualified != "3") {
                            Spacer(modifier = Modifier.height(10.dp))
                            // 下期收年费时间日期选择器
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text("下期年费扣除日", fontSize = 12.sp, color = if (isDark) TextGray else TextMuted)
                                    val dateStr = nextAnnualFeeCollectionTime?.let {
                                        SimpleDateFormat("yyyy-MM-dd", java.util.Locale.CHINA).format(Date(it))
                                    } ?: "尚未选择日期"
                                    Text(text = dateStr, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                }

                                IconButton(onClick = {
                                    val calendar = Calendar.getInstance()
                                    nextAnnualFeeCollectionTime?.let { calendar.timeInMillis = it }
                                    DatePickerDialog(
                                        context,
                                        { _, y, m, d ->
                                            val cal = Calendar.getInstance()
                                            cal.set(y, m, d, 0, 0, 0)
                                            nextAnnualFeeCollectionTime = cal.timeInMillis
                                        },
                                        calendar.get(Calendar.YEAR),
                                        calendar.get(Calendar.MONTH),
                                        calendar.get(Calendar.DAY_OF_MONTH)
                                    ).show()
                                }) {
                                    Icon(
                                        imageVector = Icons.Filled.CalendarToday,
                                        contentDescription = "选择日期",
                                        tint = if (isDark) NeonCyan else GoldPrimary
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("上次提额日期", fontSize = 12.sp, color = if (isDark) TextGray else TextMuted)
                                val dateStr = lastTime?.let {
                                    SimpleDateFormat("yyyy-MM-dd", java.util.Locale.CHINA).format(Date(it))
                                } ?: "尚未选择日期"
                                Text(text = dateStr, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            }

                            TextButton(onClick = { lastTime = null }, enabled = lastTime != null) {
                                Text("清除")
                            }

                            IconButton(onClick = {
                                val calendar = Calendar.getInstance()
                                lastTime?.let { calendar.timeInMillis = it }
                                DatePickerDialog(
                                    context,
                                    { _, y, m, d ->
                                        val cal = Calendar.getInstance()
                                        cal.set(y, m, d, 0, 0, 0)
                                        cal.set(Calendar.MILLISECOND, 0)
                                        lastTime = cal.timeInMillis
                                    },
                                    calendar.get(Calendar.YEAR),
                                    calendar.get(Calendar.MONTH),
                                    calendar.get(Calendar.DAY_OF_MONTH)
                                ).show()
                            }) {
                                Icon(
                                    imageVector = Icons.Filled.CalendarToday,
                                    contentDescription = "选择上次提额日期",
                                    tint = if (isDark) NeonCyan else GoldPrimary
                                )
                            }
                        }
                    }

                    // ==========================================
                    // Section 4: 🎁 权益备注 (BENEFITS & NOTES)
                    // ==========================================
                    FormSection(title = "🎁 权益与备注") {
                        OutlinedTextField(
                            value = equity,
                            onValueChange = { equity = it },
                            label = { Text("核心年费权益 (如 延误险, 积分里程等)") },
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = remark,
                            onValueChange = { remark = it },
                            label = { Text("账包独立备注说明") },
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )
                        
                        Spacer(modifier = Modifier.height(10.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("账单日", fontSize = 11.sp, color = if (isDark) TextGray else TextMuted)
                                OutlinedTextField(
                                    value = accountBillDate,
                                    onValueChange = { input ->
                                        val filtered = input.filter { it.isDigit() }
                                        val num = filtered.toIntOrNull()
                                        if (num == null || num in 1..31) accountBillDate = filtered
                                    },
                                    placeholder = { Text("1-31") },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = getOutlinedTextFieldColors(isDark)
                                )
                            }

                            Spacer(modifier = Modifier.width(16.dp))

                            Column(modifier = Modifier.weight(1f)) {
                                Text("还款日", fontSize = 11.sp, color = if (isDark) TextGray else TextMuted)
                                OutlinedTextField(
                                    value = dueDate,
                                    onValueChange = { input ->
                                        val filtered = input.filter { it.isDigit() }
                                        val num = filtered.toIntOrNull()
                                        if (num == null || num in 1..31) dueDate = filtered
                                    },
                                    placeholder = { Text("1-31") },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = getOutlinedTextFieldColors(isDark)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("账单日当天消费计入下期账单", fontSize = 13.sp)
                            Switch(
                                checked = billingDaySpendingToNextBill,
                                onCheckedChange = { billingDaySpendingToNextBill = it },
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = if (isDark) NeonCyan else GoldPrimary,
                                    checkedTrackColor = if (isDark) NeonCyan.copy(alpha = 0.3f) else GoldPrimary.copy(alpha = 0.3f)
                                )
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(30.dp))
                }
            }
        }
    }

    // 共享额度全局修改的确认警告对话框
    if (showSharedLimitWarningDialog) {
        AlertDialog(
            onDismissRequest = { showSharedLimitWarningDialog = false },
            title = { Text("确认修改共享总额度吗？") },
            text = { Text("⚠️ 修改该共享额度，将会自动一并批量更新该银行旗下其它全部共享信用卡的额度。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showSharedLimitWarningDialog = false
                        // 批量修改并保存
                        isSaved = true
                        executeSaveCard(
                            context, db, cardId, originalCard, country, bank, alias, level,
                            cardNumber, cvv, valid, limit, type, isSharedLimit,
                            accountBillDate, dueDate, billingDaySpendingToNextBill,
                            annualFee, isQualified, nextAnnualFeeCollectionTime, lastTime, equity, remark
                        )
                        // 批量更新同组其它共享卡片的额度
                        val otherCards = db.getAllCards().filter {
                            it.id != cardId && it.country == country && it.bank == bank && it.type == type && it.isSharedLimit
                        }
                        for (other in otherCards) {
                            other.limit = limit
                            SyncCoordinator.commitCardChange(context, other)
                        }
                        
                        Toast.makeText(context, "共享额度已全局同步保存", Toast.LENGTH_SHORT).show()
                        onBack()
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = if (isDark) NeonCyan else GoldPrimary)
                ) {
                    Text("确认更新")
                }
            },
            dismissButton = {
                TextButton(onClick = { showSharedLimitWarningDialog = false }) {
                    Text("取消")
                }
            }
        )
    }

    // ==========================================
    // 新增：重名拦截流转确认引导对话框
    // ==========================================
    if (showConflictDialog) {
        AlertDialog(
            onDismissRequest = { showConflictDialog = false },
            title = { Text("发现相同卡号卡片") },
            text = { Text("⚠️ 本地已经有相同卡号的卡片了，是否需要先去查看该卡片详情后确定是否录入？") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showConflictDialog = false
                        // 挂起录入并跳转至冲突的卡片详情页进行审查
                        CardScanProgressManager.startPending(
                            scannedTempNumber,
                            scannedTempValid,
                            scannedTempImagePath,
                            scannedTempSource
                        )
                        onNavigateToDetail(existingCardIdForConflict)
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = if (isDark) NeonCyan else GoldPrimary)
                ) {
                    Text("去查看卡片详情")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        showConflictDialog = false
                        // 直接强行代入表单
                        cardNumber = scannedTempNumber
                        valid = scannedTempValid
                        scannedImagePath = scannedTempImagePath
                        currentStep = FormStep.MANUAL_FORM
                        Toast.makeText(context, "已强行代入扫描卡号", Toast.LENGTH_SHORT).show()
                    }
                ) {
                    Text("直接录入")
                }
            }
        )
    }
}

/**
 * 表单 Section 区块容器
 */
@Composable
fun FormSection(
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
            fontSize = 13.sp,
            color = if (isDark) NeonCyan else GoldPrimary,
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp)
        )
        Column(modifier = bgModifier, content = content)
    }
}

/**
 * 定制输入框色彩集
 */
@Composable
fun getOutlinedTextFieldColors(isDark: Boolean) = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = if (isDark) NeonCyan else GoldPrimary,
    unfocusedBorderColor = if (isDark) Color.White.copy(alpha = 0.15f) else Color.Black.copy(alpha = 0.15f),
    focusedLabelColor = if (isDark) NeonCyan else GoldPrimary,
    unfocusedLabelColor = if (isDark) TextGray else TextMuted
)

/**
 * 实际执行卡片数据保存的方法
 */
fun executeSaveCard(
    context: android.content.Context,
    db: DatabaseHelper,
    cardId: String?,
    originalCard: SharedCard?,
    country: String,
    bank: String,
    alias: String,
    level: String,
    cardNumber: String,
    cvv: String,
    valid: String,
    limit: Double,
    type: String,
    isSharedLimit: Boolean,
    accountBillDate: String,
    dueDate: String,
    billingDaySpendingToNextBill: Boolean,
    annualFee: Double,
    isQualified: String,
    nextAnnualFeeCollectionTime: Long?,
    lastTime: Long?,
    equity: String,
    remark: String
) {
    val finalCard = SharedCard(
        id = cardId ?: UUID.randomUUID().toString(),
        country = country.trim(),
        bank = bank.trim(),
        alias = alias.trim(),
        level = level.trim(),
        cardNumber = cardNumber.trim(),
        cvv = cvv.trim(),
        valid = valid.trim(),
        limit = limit,
        type = type.trim().uppercase(),
        isSharedLimit = isSharedLimit,
        accountBillDate = accountBillDate,
        dueDate = dueDate,
        billingDaySpendingToNextBill = billingDaySpendingToNextBill,
        annualFee = annualFee,
        isQualified = isQualified,
        nextAnnualFeeCollectionTime = nextAnnualFeeCollectionTime,
        lastTime = lastTime,
        equity = equity.trim(),
        remark = remark.trim()
    )

    // 保存至本地账本（自动管理 lastModifyTime 和触发 pendingSync 状态）
    SyncCoordinator.commitCardChange(context, finalCard)
    Toast.makeText(context, "卡片已成功保存至本地账本", Toast.LENGTH_SHORT).show()
}

/**
 * NFC 酷炫感应刷卡全屏渲染层
 */
@Composable
fun NfcScanLayout(
    context: android.content.Context,
    isDark: Boolean,
    onBack: () -> Unit,
    onSwitchCamera: () -> Unit,
    onSwitchManual: () -> Unit,
    onSimulateScanned: (String, String) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(if (isDark) Color(0xFF0F172A) else Color(0xFFF8FAFC)),
        contentAlignment = Alignment.Center
    ) {
        // 科技感雷达扩散脉冲动画驱动
        val transition = rememberInfiniteTransition(label = "nfc")
        val radiusScale by transition.animateFloat(
            initialValue = 0.4f,
            targetValue = 1.0f,
            animationSpec = infiniteRepeatable(
                animation = tween(2200, easing = LinearEasing),
                repeatMode = RepeatMode.Restart
            ),
            label = "radius"
        )
        val alphaVal by transition.animateFloat(
            initialValue = 0.6f,
            targetValue = 0.0f,
            animationSpec = infiniteRepeatable(
                animation = tween(2200, easing = LinearEasing),
                repeatMode = RepeatMode.Restart
            ),
            label = "alpha"
        )

        val accentColor = if (isDark) NeonCyan else GoldPrimary

        // 顶部 Overlay 状态返回导航
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .statusBarsPadding()
                .padding(16.dp)
        ) {
            IconButton(
                onClick = onBack,
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.15f), shape = CircleShape)
                    .align(Alignment.CenterStart)
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "返回",
                    tint = if (isDark) Color.White else Color.Black
                )
            }
            Text(
                text = "NFC 刷卡录入",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = if (isDark) Color.White else Color.Black,
                modifier = Modifier.align(Alignment.Center)
            )
        }

        // 中央雷达与手机靠近微动画
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(32.dp)
        ) {
            Box(
                modifier = Modifier.size(240.dp),
                contentAlignment = Alignment.Center
            ) {
                // 绘制 3 层酷炫脉冲圆圈
                Canvas(modifier = Modifier.fillMaxSize()) {
                    drawCircle(
                        color = accentColor.copy(alpha = alphaVal),
                        radius = size.minDimension / 2 * radiusScale,
                        style = Stroke(width = 4.dp.toPx())
                    )
                    drawCircle(
                        color = accentColor.copy(alpha = (alphaVal + 0.3f).coerceAtMost(0.5f) * alphaVal),
                        radius = size.minDimension / 2 * (radiusScale - 0.25f).coerceAtLeast(0f),
                        style = Stroke(width = 2.dp.toPx())
                    )
                }

                // NFC 中央呼吸芯片区
                Box(
                    modifier = Modifier
                        .size(90.dp)
                        .background(
                            brush = Brush.radialGradient(
                                colors = listOf(accentColor.copy(alpha = 0.8f), accentColor.copy(alpha = 0.2f))
                            ),
                            shape = CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Nfc,
                        contentDescription = "NFC芯片",
                        modifier = Modifier.size(48.dp),
                        tint = Color.White
                    )
                }
            }

            Spacer(modifier = Modifier.height(36.dp))

            Text(
                text = "请将您的信用卡贴在手机背面",
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = if (isDark) Color.White else Color.Black,
                textAlign = TextAlign.Center
            )
            
            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "系统正处于自动感应芯片监听中...",
                fontSize = 13.sp,
                color = if (isDark) TextGray else TextMuted,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(48.dp))

            // 调试用“模拟刷卡”核心按钮，用于无硬件下 100% 测试通过
            Button(
                onClick = { onSimulateScanned("6222081001987654321", "08/30") },
                colors = ButtonDefaults.buttonColors(containerColor = accentColor),
                shape = RoundedCornerShape(12.dp),
                elevation = ButtonDefaults.buttonElevation(defaultElevation = 4.dp)
            ) {
                Icon(imageVector = Icons.Default.Nfc, contentDescription = "模拟")
                Spacer(modifier = Modifier.width(6.dp))
                Text("模拟 NFC 刷卡感应", fontWeight = FontWeight.Bold)
            }
        }

        // 底部引导切换栏
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                modifier = Modifier
                    .background(
                        color = if (isDark) Color.Black.copy(alpha = 0.25f) else Color.Black.copy(alpha = 0.08f),
                        shape = RoundedCornerShape(24.dp)
                    )
                    .padding(horizontal = 8.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(onClick = onSwitchCamera) {
                    Icon(imageVector = Icons.Default.PhotoCamera, contentDescription = "相机", tint = accentColor, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("相机扫描", fontSize = 13.sp, color = accentColor, fontWeight = FontWeight.SemiBold)
                }
                
                Box(modifier = Modifier.size(width = 1.dp, height = 16.dp).background(Color.Gray.copy(alpha = 0.3f)))

                TextButton(onClick = onSwitchManual) {
                    Icon(imageVector = Icons.Default.Edit, contentDescription = "手动", tint = accentColor, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("手动直接录", fontSize = 13.sp, color = accentColor, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

/**
 * CameraX 真实渲染且包含绿色发光激光扫描线的高清对齐蒙板全屏页面
 */
@Composable
fun CameraScanLayout(
    context: android.content.Context,
    isDark: Boolean,
    lifecycleOwner: androidx.lifecycle.LifecycleOwner,
    onBack: () -> Unit,
    onSwitchManual: () -> Unit,
    onSimulateScanned: (String, String) -> Unit
) {
    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        var cameraBindError by remember { mutableStateOf(false) }

        if (!cameraBindError) {
            AndroidView(
                factory = { ctx ->
                    val previewView = PreviewView(ctx).apply {
                        scaleType = PreviewView.ScaleType.FILL_CENTER
                    }
                    val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
                    cameraProviderFuture.addListener({
                        try {
                            val cameraProvider = cameraProviderFuture.get()
                            val preview = Preview.Builder().build().apply {
                                setSurfaceProvider(previewView.surfaceProvider)
                            }
                            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                            cameraProvider.unbindAll()
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                cameraSelector,
                                preview
                            )
                        } catch (e: Exception) {
                            e.printStackTrace()
                            cameraBindError = true
                        }
                    }, ContextCompat.getMainExecutor(ctx))
                    previewView
                },
                modifier = Modifier.fillMaxSize()
            )
        } else {
            // 仿真取景器 (用于无相机权限或模拟器运行容错)
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Brush.radialGradient(listOf(Color(0xFF0F172A), Color.Black))),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "📸 智能聚焦感应器就绪...",
                    color = Color.LightGray.copy(alpha = 0.5f),
                    fontSize = 14.sp
                )
            }
        }

        // 绘制对准框与霓虹绿色粗直角四角包边
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            val transition = rememberInfiniteTransition(label = "laser")
            
            // 循环滑动的激光扫描线动画
            val laserOffset by transition.animateFloat(
                initialValue = 0.05f,
                targetValue = 0.95f,
                animationSpec = infiniteRepeatable(
                    animation = tween(1800, easing = LinearEasing),
                    repeatMode = RepeatMode.Reverse
                ),
                label = "offset"
            )

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier.fillMaxSize()
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.85f)
                        .aspectRatio(1.586f) // 完美符合银行卡 85.6 : 53.98 的国际黄金比例
                        .border(1.dp, Color.White.copy(alpha = 0.25f), RoundedCornerShape(16.dp))
                ) {
                    val cornerSize = 24.dp
                    val strokeW = 4.dp

                    // 左上角包边
                    Box(modifier = Modifier.size(cornerSize).align(Alignment.TopStart).border(width = strokeW, color = NeonGreen, shape = RoundedCornerShape(topStart = 16.dp)))
                    // 右上角包边
                    Box(modifier = Modifier.size(cornerSize).align(Alignment.TopEnd).border(width = strokeW, color = NeonGreen, shape = RoundedCornerShape(topEnd = 16.dp)))
                    // 左下角包边
                    Box(modifier = Modifier.size(cornerSize).align(Alignment.BottomStart).border(width = strokeW, color = NeonGreen, shape = RoundedCornerShape(bottomStart = 16.dp)))
                    // 右下角包边
                    Box(modifier = Modifier.size(cornerSize).align(Alignment.BottomEnd).border(width = strokeW, color = NeonGreen, shape = RoundedCornerShape(bottomEnd = 16.dp)))

                    // 脉冲滑动的霓虹激光扫描线
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.96f)
                            .height(3.dp)
                            .align(Alignment.TopCenter)
                            .offset(y = 120.dp + (100.dp * laserOffset)) // 限制上下活动空间在卡内
                            .background(
                                brush = Brush.horizontalGradient(
                                    colors = listOf(Color.Transparent, Color(0xFF4ADE80), Color.Transparent)
                                )
                            )
                            .shadow(elevation = 6.dp, spotColor = Color(0xFF4ADE80))
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))

                Text(
                    text = "请将您的卡片对齐绿色框内",
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                
                Spacer(modifier = Modifier.height(6.dp))

                Text(
                    text = "取景器正在进行卡号与有效期自动捕捉...",
                    color = Color.LightGray.copy(alpha = 0.8f),
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center
                )

                Spacer(modifier = Modifier.height(48.dp))

                // 调试用相机模拟按钮，点击可完美生成 mock 扫描原件并进行冲突检测
                Button(
                    onClick = { onSimulateScanned("6217002010098765432", "12/29") },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4ADE80)),
                    shape = RoundedCornerShape(12.dp),
                    elevation = ButtonDefaults.buttonElevation(defaultElevation = 4.dp)
                ) {
                    Icon(imageVector = Icons.Default.PhotoCamera, contentDescription = "相机模拟", tint = Color.Black)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("模拟相机激光扫描成功", fontWeight = FontWeight.Bold, color = Color.Black)
                }
            }
        }

        // 顶层半透明导航栏
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .statusBarsPadding()
                .padding(16.dp)
        ) {
            IconButton(
                onClick = onBack,
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.4f), shape = CircleShape)
                    .align(Alignment.CenterStart)
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "返回",
                    tint = Color.White
                )
            }
            Text(
                text = "相机扫描录入",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.align(Alignment.Center)
            )
        }

        // 底部切换至手动直接填写按钮
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(bottom = 32.dp),
            contentAlignment = Alignment.Center
        ) {
            TextButton(
                onClick = onSwitchManual,
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.35f), shape = RoundedCornerShape(20.dp))
                    .padding(horizontal = 16.dp, vertical = 4.dp)
            ) {
                Icon(imageVector = Icons.Default.Edit, contentDescription = "切换手动", tint = Color.White, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("不想扫描？手动录入", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
