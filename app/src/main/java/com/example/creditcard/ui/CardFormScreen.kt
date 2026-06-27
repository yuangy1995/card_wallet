package com.example.creditcard.ui

import android.app.DatePickerDialog
import android.widget.Toast
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.activity.OnBackPressedCallback
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Save
import androidx.compose.material.icons.filled.Nfc
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.compose.ui.window.PopupProperties
import com.example.creditcard.data.CardImageAsset
import com.example.creditcard.data.CardReferenceData
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.*
import com.example.creditcard.ui.components.AppBackButton
import com.example.creditcard.ui.main.CardBrandBadge
import com.example.creditcard.ui.main.getCardBrand
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager
import com.example.creditcard.utils.NfcScannerManager
import com.example.creditcard.utils.CardScanProgressManager
import com.example.creditcard.utils.CardImageCodec
import com.example.creditcard.utils.VibrationUtils
import com.example.creditcard.utils.bankNamesReferToSameBank
import com.example.creditcard.utils.displayBankName

import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.exifinterface.media.ExifInterface
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

/**
 * 录入银行卡三阶段状态机
 */
enum class FormStep {
    SCAN_NFC,     // 1. NFC 扫描录入状态
    SCAN_CAMERA,  // 2. 相机激光扫描录入状态
    MANUAL_FORM   // 3. 常规手动表单录入状态
}

private const val REFERENCE_AUTO_MATCH_DELAY_MILLIS = 200L

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CardFormScreen(
    cardId: String?,
    prefillCardNumber: String = "",
    prefillValid: String = "",
    initialCardCategory: String = "credit",
    onBack: () -> Unit,
    onNavigateToDetail: (String) -> Unit
) {
    val context = LocalContext.current
    val activity = context as? ComponentActivity
    val isDark by ThemeManager.isDarkTheme.collectAsState()
    val appContext = context.applicationContext
    val db = remember(appContext) { DatabaseHelper(appContext) }
    DisposableEffect(db) {
        onDispose {
            db.close()
        }
    }

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
    
    // 新建模式下保留临时 ID，用于中途退出时清理未保存扫描原件。
    val tempCardId = remember { UUID.randomUUID().toString() }
    
    // 是否已确认成功保存卡片，用于在退出时防空转垃圾回收 (若用户中途退出新建，则静默回收未保存卡片的本地临时扫描原件)
    var isSaved by remember { mutableStateOf(false) }

    // 初始化进入步骤：新建模式下若有 NFC 硬件进入 NFC 雷达扫描，否则降级至相机扫描，编辑模式直接进常规表单
    var currentStep by remember {
        mutableStateOf(
            if (isEditMode) FormStep.MANUAL_FORM else {
                if (prefillCardNumber.isNotBlank() || prefillValid.isNotBlank()) {
                    FormStep.MANUAL_FORM
                } else if (isNfcSupported) FormStep.SCAN_NFC else FormStep.SCAN_CAMERA
            }
        )
    }

    // ==========================================
    // 表单状态变量
    // ==========================================
    var country by remember { mutableStateOf(originalCard?.country ?: "") }
    var cardCategory by remember { mutableStateOf(originalCard?.cardCategory ?: if (initialCardCategory == "debit") "debit" else "credit") }
    val isDebitCard = cardCategory == "debit"
    var bank by remember { mutableStateOf(originalCard?.bank ?: "") }
    var alias by remember { mutableStateOf(originalCard?.alias ?: "") }
    var level by remember { mutableStateOf(CardReferenceData.normalizeLevel(originalCard?.level) ?: "") }
    
    var cardNumber by remember { mutableStateOf(originalCard?.cardNumber ?: prefillCardNumber) }
    var cvv by remember { mutableStateOf(originalCard?.cvv ?: "") }
    var valid by remember { mutableStateOf(originalCard?.valid ?: prefillValid) }
    var validFieldValue by remember {
        mutableStateOf(TextFieldValue(valid, selection = TextRange(valid.length)))
    }

    LaunchedEffect(valid) {
        if (validFieldValue.text != valid) {
            validFieldValue = TextFieldValue(valid, selection = TextRange(valid.length))
        }
    }
    
    var limitText by remember {
        mutableStateOf(if (isEditMode) formatEditableAmount(originalCard?.limit ?: 0.0) else "")
    }
    var type by remember { mutableStateOf(originalCard?.type ?: "") }
    var isSharedLimit by remember { mutableStateOf(originalCard?.isSharedLimit ?: true) }
    
    var accountBillDate by remember { mutableStateOf(originalCard?.accountBillDate ?: "") }
    var dueDate by remember { mutableStateOf(originalCard?.dueDate ?: "") }
    var billingDaySpendingToNextBill by remember { mutableStateOf(originalCard?.billingDaySpendingToNextBill ?: true) }
    
    var annualFeeText by remember {
        mutableStateOf(if (isEditMode) formatEditableAmount(originalCard?.annualFee ?: 0.0) else "")
    }
    var isQualified by remember { mutableStateOf(originalCard?.isQualified ?: "") }
    var nextAnnualFeeCollectionTime by remember { mutableStateOf(originalCard?.nextAnnualFeeCollectionTime) }
    var lastTime by remember { mutableStateOf(originalCard?.lastTime) }
    
    var equity by remember { mutableStateOf(originalCard?.equity ?: "") }
    var remark by remember { mutableStateOf(originalCard?.remark ?: "") }
    var cardImages by remember { mutableStateOf(originalCard?.cardImages ?: emptyList()) }
    var showFullscreenImage by remember { mutableStateOf(false) }
    var fullscreenImageIndex by remember { mutableStateOf(0) }
    var coreSectionExpanded by remember { mutableStateOf(true) }
    var mediaSectionExpanded by remember { mutableStateOf(false) }
    var limitFeeSectionExpanded by remember { mutableStateOf(false) }
    var benefitSectionExpanded by remember { mutableStateOf(false) }

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

    val galleryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { uris ->
        val newImages = uris.mapNotNull { uri ->
            CardImageCodec.fromUri(context, uri, "gallery")
        }
        if (newImages.isNotEmpty()) {
            cardImages = cardImages + newImages
            Toast.makeText(context, "已添加 ${newImages.size} 张卡片图片", Toast.LENGTH_SHORT).show()
        }
    }

    var pendingCameraPhotoFile by remember { mutableStateOf<File?>(null) }
    val cameraPhotoLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        val photoFile = pendingCameraPhotoFile
        pendingCameraPhotoFile = null

        if (success && photoFile != null && photoFile.exists() && photoFile.length() > 0L) {
            CardImageCodec.fromFile(photoFile, "manual_camera")?.let { image ->
                cardImages = cardImages + image
                Toast.makeText(context, "已添加拍摄图片", Toast.LENGTH_SHORT).show()
            } ?: Toast.makeText(context, "拍摄图片读取失败", Toast.LENGTH_SHORT).show()
        }

        try {
            photoFile?.delete()
        } catch (e: Exception) {
            // 临时拍照文件会随系统缓存清理，删除失败不影响图片保存。
        }
    }

    fun launchManualCameraPhoto() {
        val photoFile = try {
            File.createTempFile("manual_card_", ".jpg", context.cacheDir)
        } catch (e: Exception) {
            Toast.makeText(context, "创建拍照临时文件失败", Toast.LENGTH_SHORT).show()
            return
        }

        val photoUri = try {
            FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                photoFile
            )
        } catch (e: Exception) {
            try { photoFile.delete() } catch (_: Exception) {}
            Toast.makeText(context, "无法启动高清拍照", Toast.LENGTH_SHORT).show()
            return
        }

        pendingCameraPhotoFile = photoFile
        try {
            cameraPhotoLauncher.launch(photoUri)
        } catch (e: Exception) {
            pendingCameraPhotoFile = null
            try { photoFile.delete() } catch (_: Exception) {}
            Toast.makeText(context, "未找到可用的相机应用", Toast.LENGTH_SHORT).show()
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            try {
                pendingCameraPhotoFile?.delete()
            } catch (e: Exception) {
            }
        }
    }

    fun appendScannedImage(imagePath: String?, source: String) {
        if (imagePath.isNullOrBlank()) return
        val image = CardImageCodec.fromFile(File(imagePath), source.lowercase()) ?: return
        cardImages = cardImages + image
    }

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
            appendScannedImage(imagePath, source)
            currentStep = FormStep.MANUAL_FORM
        }
    }

    // ==========================================
    // 物理 NFC 刷卡感应广播已由 NfcScanLayout 页面内部状态机统一截获与延迟解析回调处理
    // ==========================================

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
                    appendScannedImage(CardScanProgressManager.pendingScanImagePath, CardScanProgressManager.scanSource)
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
    val existingSharedLimitCard = remember(cardId, country, bank, type, isSharedLimit, cardCategory) {
        if (!isDebitCard && isSharedLimit && bank.trim().isNotEmpty()) {
            val all = db.getAllCards()
            all.firstOrNull {
                it.id != cardId &&
                    it.cardCategory != "debit" &&
                    it.country == country &&
                    bankNamesReferToSameBank(it.bank, bank) &&
                    it.type == type &&
                    it.isSharedLimit
            }
        } else null
    }
    val shouldLockSharedLimitInput = !isEditMode && existingSharedLimitCard != null

    // 新增同组共享卡时沿用既有额度；编辑已有卡时允许修改，并在保存前批量确认。
    LaunchedEffect(existingSharedLimitCard) {
        if (!isEditMode && existingSharedLimitCard != null) {
            limitText = formatEditableAmount(existingSharedLimitCard.limit)
            if (type.isBlank()) {
                type = existingSharedLimitCard.type
            }
        }
    }

    LaunchedEffect(isQualified) {
        if (isQualified == "3") {
            nextAnnualFeeCollectionTime = null
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

    // 直接将 OnBackPressedCallback 注册到主 Activity 的 OnBackPressedDispatcher 上，
    // 彻底解决局部 OnBackPressedDispatcher 链接失效导致的全面屏返回闪退问题
    val currentHandleBackAction by rememberUpdatedState(handleBackAction)
    DisposableEffect(activity) {
        val backCallback = object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                currentHandleBackAction()
            }
        }
        activity?.onBackPressedDispatcher?.addCallback(backCallback)
        onDispose {
            backCallback.remove()
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
                onScanSuccess = { scannedNo, scannedVal ->
                    handleScannedCard(scannedNo, scannedVal, null, "NFC")
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
                tempCardId = if (isEditMode) cardId else tempCardId,
                onCardScanned = { scannedNo, scannedVal, imagePath ->
                    handleScannedCard(scannedNo, scannedVal, imagePath, "Camera")
                }
            )
        }
        FormStep.MANUAL_FORM -> {
            Scaffold(
                topBar = {
                    TopAppBar(
                        title = { Text(if (isEditMode) "修改${if (isDebitCard) "储蓄卡" else "信用卡"}" else "添加${if (isDebitCard) "储蓄卡" else "信用卡"}", fontWeight = FontWeight.Bold) },
                        navigationIcon = {
                            AppBackButton(
                                onClick = handleBackAction,
                                tint = if (isDark) NeonCyan else GoldPrimary,
                                containerColor = MaterialTheme.colorScheme.surface,
                                borderColor = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.32f)
                            )
                        },
                        actions = {
                            if (!isEditMode) {
                                TextButton(
                                    onClick = {
                                        currentStep = if (isNfcSupported) FormStep.SCAN_NFC else FormStep.SCAN_CAMERA
                                    },
                                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.PhotoCamera,
                                        contentDescription = "NFC/相机扫描录入",
                                        modifier = Modifier.size(16.dp),
                                        tint = if (isDark) NeonCyan else GoldPrimary
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = "扫描录入",
                                        fontSize = 12.sp,
                                        color = if (isDark) NeonCyan else GoldPrimary
                                    )
                                }
                            }
                            // 保存 FAB
                            IconButton(onClick = {
                                val cleanCountry = country.trim()
                                val cleanBank = bank.trim()
                                val cleanCardNumber = cardNumber.filter { it.isDigit() }
                                val cleanValid = valid.trim()
                                val parsedLimit = if (isDebitCard) 0.0 else parseAmountOrNull(limitText) ?: 0.0
                                val parsedAnnualFee = if (isDebitCard) 0.0 else parseAmountOrNull(annualFeeText) ?: 0.0

                                // 四个核心字段必填，其余字段仅在填写后校验。
                                if (cleanCountry.isEmpty()) {
                                    Toast.makeText(context, "请选择国家 / 地区", Toast.LENGTH_SHORT).show()
                                    return@IconButton
                                }
                                if (cleanBank.isEmpty()) {
                                    Toast.makeText(context, "请选择发卡银行", Toast.LENGTH_SHORT).show()
                                    return@IconButton
                                }
                                if (cleanCardNumber.isEmpty()) {
                                    Toast.makeText(context, "请输入卡号", Toast.LENGTH_SHORT).show()
                                    return@IconButton
                                }
                                if (cleanCardNumber.length !in 13..20) {
                                    Toast.makeText(context, "卡号长度需为 13-20 位", Toast.LENGTH_SHORT).show()
                                    return@IconButton
                                }
                                if (!isValidExpiry(cleanValid)) {
                                    Toast.makeText(context, "请输入有效期，格式为 MM/YY", Toast.LENGTH_SHORT).show()
                                    return@IconButton
                                }
                                if (!isDebitCard && limitText.isNotBlank() && parseAmountOrNull(limitText) == null) {
                                    Toast.makeText(context, "请输入正确的额度", Toast.LENGTH_SHORT).show()
                                    return@IconButton
                                }
                                if (!isDebitCard && annualFeeText.isNotBlank() && parseAmountOrNull(annualFeeText) == null) {
                                    Toast.makeText(context, "请输入正确的年费金额", Toast.LENGTH_SHORT).show()
                                    return@IconButton
                                }
                                if (!isDebitCard && isQualified.isNotBlank() && isQualified !in listOf("1", "2", "3")) {
                                    Toast.makeText(context, "请选择正确的年费减免政策", Toast.LENGTH_SHORT).show()
                                    return@IconButton
                                }

                                // 检测是否发生了共享额度的“全局修改”
                                val sameGroupCards = if (!isDebitCard && isSharedLimit) {
                                    db.getAllCards().filter {
                                        it.id != cardId &&
                                            it.cardCategory != "debit" &&
                                            it.country == cleanCountry &&
                                            bankNamesReferToSameBank(it.bank, cleanBank) &&
                                            it.type == type &&
                                            it.isSharedLimit
                                    }
                                } else emptyList()

                                if (sameGroupCards.isNotEmpty() && parsedLimit != sameGroupCards[0].limit) {
                                    // 额度发生改变，且存在同组共享卡，拉起全局更新警示
                                    showSharedLimitWarningDialog = true
                                } else {
                                    // 直接保存，设置 isSaved = true 避免图片垃圾回收
                                    isSaved = true
                                    executeSaveCard(
                                        context, db, cardId, originalCard, cardCategory, cleanCountry, cleanBank, alias, level,
                                        cleanCardNumber, cvv, cleanValid, parsedLimit, type, isSharedLimit,
                                        accountBillDate, dueDate, billingDaySpendingToNextBill,
                                        parsedAnnualFee, isQualified, nextAnnualFeeCollectionTime, lastTime, equity, remark,
                                        cardImages
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
                    Spacer(modifier = Modifier.height(2.dp))

                    // ==========================================
                    // Section 1: 核心信息，四项必填，其余字段可留空
                    // ==========================================
                    CollapsibleFormSection(
                        title = "核心信息",
                        expanded = coreSectionExpanded,
                        onExpandedChange = { coreSectionExpanded = it }
                    ) {
                        Text("卡类别", fontSize = 12.sp, color = if (isDark) TextGray else TextMuted)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            listOf("credit" to "信用卡", "debit" to "储蓄卡").forEach { (code, labelText) ->
                                FilterChip(
                                    selected = cardCategory == code,
                                    onClick = { cardCategory = code },
                                    label = { Text(labelText) },
                                    modifier = Modifier.weight(1f),
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = if (isDark) NeonCyan.copy(alpha = 0.2f) else GoldPrimary.copy(alpha = 0.15f),
                                        selectedLabelColor = if (isDark) NeonCyan else GoldPrimary
                                    )
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        ReferenceDropdownField(
                            value = country,
                            onValueChange = { country = it },
                            label = "国家 / 地区 *",
                            options = CardReferenceData.countries,
                            isDark = isDark,
                            modifier = Modifier.fillMaxWidth(),
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        ReferenceDropdownField(
                            value = bank,
                            onValueChange = { bank = it },
                            label = "发卡银行 *",
                            options = CardReferenceData.banks,
                            isDark = isDark,
                            modifier = Modifier.fillMaxWidth(),
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = cardNumber,
                            onValueChange = { input ->
                                // 过滤非数字，并限制长度最长为 20 位
                                val filtered = input.filter { it.isDigit() }.take(20)
                                cardNumber = filtered
                            },
                            label = { Text("银行卡号 *") },
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

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            OutlinedTextField(
                                value = validFieldValue,
                                onValueChange = { input ->
                                    val formatted = formatExpiryInput(input.text, validFieldValue.text)
                                    valid = formatted
                                    validFieldValue = TextFieldValue(
                                        text = formatted,
                                        selection = TextRange(formatted.length)
                                    )
                                },
                                label = { Text("有效期 *") },
                                placeholder = { Text("MM/YY") },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                modifier = Modifier.weight(1f),
                                colors = getOutlinedTextFieldColors(isDark)
                            )

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
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = alias,
                            onValueChange = { alias = it },
                            label = { Text("卡片别名") },
                            placeholder = { Text("如：车主白金卡") },
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        ReferenceDropdownField(
                            value = level,
                            onValueChange = { level = it },
                            label = "卡片等级",
                            options = CardReferenceData.levels,
                            isDark = isDark,
                            modifier = Modifier.fillMaxWidth(),
                        )

                        if (isDebitCard) {
                            Spacer(modifier = Modifier.height(10.dp))
                            ReferenceDropdownField(
                                value = type,
                                onValueChange = { type = it },
                                label = "币种",
                                options = CardReferenceData.currencies,
                                isDark = isDark,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }

                    CollapsibleFormSection(
                        title = "卡片媒体文件",
                        expanded = mediaSectionExpanded,
                        onExpandedChange = { mediaSectionExpanded = it }
                    ) {
                        CardMediaSection(
                            images = cardImages,
                            isDark = isDark,
                            onTakePhoto = { launchManualCameraPhoto() },
                            onPickImages = { galleryLauncher.launch("image/*") },
                            onDelete = { imageId ->
                                cardImages = cardImages.filterNot { it.id == imageId }
                            },
                            onImageClick = { image ->
                                val idx = cardImages.indexOf(image)
                                if (idx != -1) {
                                    fullscreenImageIndex = idx
                                    showFullscreenImage = true
                                }
                            }
                        )
                    }

                    if (!isDebitCard) {
                        CollapsibleFormSection(
                            title = "额度与年费",
                            expanded = limitFeeSectionExpanded,
                            onExpandedChange = { limitFeeSectionExpanded = it }
                        ) {
                        ReferenceDropdownField(
                            value = type,
                            onValueChange = { type = it },
                            label = "结算币种",
                            options = CardReferenceData.currencies,
                            isDark = isDark,
                            modifier = Modifier.fillMaxWidth(),
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = limitText,
                            onValueChange = { input ->
                                limitText = filterAmountInput(input)
                            },
                            label = { Text("额度") },
                            placeholder = { Text("0") },
                            enabled = !shouldLockSharedLimitInput,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )

                        // 共享额度智能提示
                        if (existingSharedLimitCard != null) {
                            Text(
                                text = if (shouldLockSharedLimitInput) {
                                    "已自动关联同银行共享额度组: ${String.format("%,.0f", existingSharedLimitCard.limit)} ${type.ifBlank { existingSharedLimitCard.type }}"
                                } else {
                                    "同银行共享额度组当前额度: ${String.format("%,.0f", existingSharedLimitCard.limit)} ${type.ifBlank { existingSharedLimitCard.type }}"
                                },
                                color = if (isDark) NeonGreen else ForestGreen,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                modifier = Modifier.padding(top = 6.dp)
                            )
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("共享额度", fontSize = 13.sp)
                            Switch(
                                checked = isSharedLimit,
                                onCheckedChange = { isSharedLimit = it },
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = if (isDark) NeonCyan else GoldPrimary,
                                    checkedTrackColor = if (isDark) NeonCyan.copy(alpha = 0.3f) else GoldPrimary.copy(alpha = 0.3f)
                                )
                            )
                        }

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

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = annualFeeText,
                            onValueChange = { input ->
                                annualFeeText = filterAmountInput(input)
                            },
                            label = { Text("年费金额") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
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
                            CardReferenceData.qualificationStatuses.forEach { (code, labelText) ->
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

                                if (nextAnnualFeeCollectionTime != null) {
                                    TextButton(onClick = { nextAnnualFeeCollectionTime = null }) {
                                        Text("清除")
                                    }
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

                            if (lastTime != null) {
                                TextButton(onClick = { lastTime = null }) {
                                    Text("清除")
                                }
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
                    }

                    CollapsibleFormSection(
                        title = "权益与备注",
                        expanded = benefitSectionExpanded,
                        onExpandedChange = { benefitSectionExpanded = it }
                    ) {
                        OutlinedTextField(
                            value = equity,
                            onValueChange = { equity = it },
                            label = { Text("核心年费权益") },
                            placeholder = { Text("如：延误险、积分里程") },
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = remark,
                            onValueChange = { remark = it },
                            label = { Text("备注说明") },
                            modifier = Modifier.fillMaxWidth(),
                            colors = getOutlinedTextFieldColors(isDark)
                        )
                        
                        Spacer(modifier = Modifier.height(10.dp))

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
            text = { Text("⚠️ 修改该共享额度，将会自动一并批量更新该银行旗下其它全部共享信用卡的额度。储蓄卡不参与额度同步。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showSharedLimitWarningDialog = false
                        val parsedLimit = parseAmountOrNull(limitText) ?: 0.0
                        val parsedAnnualFee = parseAmountOrNull(annualFeeText) ?: 0.0
                        val cleanCardNumber = cardNumber.filter { it.isDigit() }
                        val cleanCountry = country.trim()
                        val cleanBank = bank.trim()
                        // 批量修改并保存
                        isSaved = true
                        executeSaveCard(
                            context, db, cardId, originalCard, cardCategory, cleanCountry, cleanBank, alias, level,
                            cleanCardNumber, cvv, valid.trim(), parsedLimit, type, isSharedLimit,
                            accountBillDate, dueDate, billingDaySpendingToNextBill,
                            parsedAnnualFee, isQualified, nextAnnualFeeCollectionTime, lastTime, equity, remark,
                            cardImages
                        )
                        // 批量更新同组其它共享卡片的额度
                        val otherCards = db.getAllCards().filter {
                            it.id != cardId &&
                                it.cardCategory != "debit" &&
                                it.country == cleanCountry &&
                                bankNamesReferToSameBank(it.bank, cleanBank) &&
                                it.type == type &&
                                it.isSharedLimit
                        }
                        for (other in otherCards) {
                            other.limit = parsedLimit
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
                        appendScannedImage(scannedTempImagePath, scannedTempSource)
                        currentStep = FormStep.MANUAL_FORM
                        Toast.makeText(context, "已强行代入扫描卡号", Toast.LENGTH_SHORT).show()
                    }
                ) {
                    Text("直接录入")
                }
            }
        )
    }

    // 4. 全屏大图预览模态 Dialog (支持捏合缩放、双击还原与左右Pager滑动)
    if (showFullscreenImage && cardImages.isNotEmpty()) {
        val pagerState = rememberPagerState(
            initialPage = fullscreenImageIndex.coerceIn(0, cardImages.lastIndex),
            pageCount = { cardImages.size }
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
                // 顶层整体背景轻触关闭
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
                    val image = cardImages[page]
                    val bitmap = remember(image.id, image.data) {
                        CardImageCodec.decodeBitmap(image)
                    }
                    if (bitmap != null) {
                        ZoomableImage(
                            bitmap = bitmap,
                            contentDescription = "全屏大图预览 ${page + 1}",
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

                if (cardImages.size > 1) {
                    IconButton(
                        onClick = {
                            pagerScope.launch {
                                val target = if (pagerState.currentPage == 0) cardImages.lastIndex else pagerState.currentPage - 1
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
                                val target = if (pagerState.currentPage == cardImages.lastIndex) 0 else pagerState.currentPage + 1
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
                if (cardImages.size > 1) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = 32.dp)
                            .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(20.dp))
                            .padding(horizontal = 14.dp, vertical = 6.dp)
                    ) {
                        Text(
                            text = "${pagerState.currentPage + 1} / ${cardImages.size}",
                            color = Color.White,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
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
        if (title.isNotBlank()) {
            Text(
                text = title,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
                color = if (isDark) NeonCyan else GoldPrimary,
                modifier = Modifier.padding(start = 4.dp, bottom = 6.dp)
            )
        }
        Column(modifier = bgModifier, content = content)
    }
}

@Composable
fun CollapsibleFormSection(
    title: String,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    content: @Composable ColumnScope.() -> Unit
) {
    val isDark by ThemeManager.isDarkTheme.collectAsState()
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(if (isDark) DarkCardBg else LightCardBg)
                .clickable { onExpandedChange(!expanded) }
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                color = if (isDark) NeonCyan else GoldPrimary,
                modifier = Modifier.weight(1f)
            )
            Icon(
                imageVector = if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                contentDescription = if (expanded) "收起" else "展开",
                tint = if (isDark) NeonCyan else GoldPrimary
            )
        }

        AnimatedVisibility(visible = expanded) {
            FormSection(title = "") {
                content()
            }
        }
    }
}

@Composable
fun ReferenceDropdownField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    options: List<String>,
    isDark: Boolean,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }
    var pendingAutoMatch by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current
    val filteredOptions = remember(value, options) {
        val keyword = value.trim()
        if (keyword.isEmpty()) {
            options
        } else {
            options.filter { it.contains(keyword, ignoreCase = true) }
        }
    }
    val canUseCustomValue = value.trim().isNotEmpty() && options.none { it == value.trim() }

    LaunchedEffect(value, pendingAutoMatch) {
        if (!pendingAutoMatch) return@LaunchedEffect

        val keyword = value.trim()
        if (keyword.isEmpty()) {
            expanded = false
            pendingAutoMatch = false
            return@LaunchedEffect
        }

        delay(REFERENCE_AUTO_MATCH_DELAY_MILLIS)
        if (filteredOptions.isNotEmpty() || canUseCustomValue) {
            expanded = true
        }
        pendingAutoMatch = false
    }

    Box(modifier = modifier) {
        OutlinedTextField(
            value = value,
            onValueChange = {
                onValueChange(it)
                expanded = false
                pendingAutoMatch = true
            },
            label = { Text(label) },
            singleLine = true,
            trailingIcon = {
                IconButton(onClick = {
                    pendingAutoMatch = false
                    expanded = !expanded
                }) {
                    Icon(
                        imageVector = Icons.Filled.ArrowDropDown,
                        contentDescription = "显示匹配选项",
                        tint = if (isDark) NeonCyan else GoldPrimary
                    )
                }
            },
            modifier = Modifier.fillMaxWidth(),
            colors = getOutlinedTextFieldColors(isDark)
        )
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            properties = PopupProperties(focusable = false),
            modifier = Modifier
                .heightIn(max = 320.dp)
                .background(if (isDark) DarkCardBg else Color.White)
        ) {
            if (canUseCustomValue) {
                DropdownMenuItem(
                    text = {
                        Text(
                            text = "使用“${value.trim()}”",
                            color = if (isDark) NeonCyan else GoldPrimary,
                            maxLines = 1,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                        )
                    },
                    onClick = {
                        pendingAutoMatch = false
                        onValueChange(value.trim())
                        expanded = false
                        focusManager.clearFocus()
                    }
                )
            }

            filteredOptions.forEach { option ->
                DropdownMenuItem(
                    text = {
                        Text(
                            text = option,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                        )
                    },
                    onClick = {
                        pendingAutoMatch = false
                        onValueChange(option)
                        expanded = false
                        focusManager.clearFocus()
                    }
                )
            }
        }
    }
}

@Composable
fun CardMediaSection(
    images: List<CardImageAsset>,
    isDark: Boolean,
    onTakePhoto: () -> Unit,
    onPickImages: () -> Unit,
    onDelete: (String) -> Unit,
    onImageClick: (CardImageAsset) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            OutlinedButton(
                onClick = onTakePhoto,
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(10.dp)
            ) {
                Icon(Icons.Filled.PhotoCamera, contentDescription = "拍照", modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("拍照")
            }

            OutlinedButton(
                onClick = onPickImages,
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(10.dp)
            ) {
                Icon(Icons.Filled.PhotoLibrary, contentDescription = "相册", modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("相册")
            }
        }

        if (images.isEmpty()) {
            Text(
                text = "暂无卡片图片。相机扫描成功裁剪出的卡面也会显示在这里。",
                color = if (isDark) TextGray else TextMuted,
                fontSize = 12.sp,
                lineHeight = 17.sp
            )
        } else {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                images.forEachIndexed { index, image ->
                    Box(
                        modifier = Modifier
                            .width(160.dp)
                            .aspectRatio(1.586f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (isDark) DarkBg else Color.White)
                            .border(
                                width = 1.dp,
                                color = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.25f),
                                shape = RoundedCornerShape(10.dp)
                            )
                            .clickable { onImageClick(image) }
                    ) {
                        val bitmap = remember(image.id, image.data) {
                            CardImageCodec.decodeBitmap(image)
                        }
                        if (bitmap != null) {
                            Image(
                                bitmap = bitmap.asImageBitmap(),
                                contentDescription = "卡片图片 ${index + 1}",
                                modifier = Modifier.fillMaxSize(),
                                contentScale = ContentScale.Crop
                            )
                        } else {
                            Text(
                                text = "图片无法预览",
                                color = MaterialTheme.colorScheme.error,
                                fontSize = 12.sp,
                                modifier = Modifier.align(Alignment.Center)
                            )
                        }

                        IconButton(
                            onClick = { onDelete(image.id) },
                            modifier = Modifier
                                .align(Alignment.TopEnd)
                                .padding(4.dp)
                                .size(30.dp)
                                .background(Color.Black.copy(alpha = 0.55f), CircleShape)
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Delete,
                                contentDescription = "删除图片",
                                tint = Color.White,
                                modifier = Modifier.size(16.dp)
                            )
                        }

                        Text(
                            text = image.source.ifBlank { "image" },
                            color = Color.White,
                            fontSize = 10.sp,
                            maxLines = 1,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                            modifier = Modifier
                                .align(Alignment.BottomStart)
                                .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(topEnd = 6.dp))
                                .padding(horizontal = 6.dp, vertical = 3.dp)
                        )
                    }
                }
            }
        }
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
    unfocusedLabelColor = if (isDark) TextGray else TextMuted,
    focusedTextColor = MaterialTheme.colorScheme.onSurface,
    unfocusedTextColor = MaterialTheme.colorScheme.onSurface,
    focusedPlaceholderColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.75f),
    unfocusedPlaceholderColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.75f),
    cursorColor = if (isDark) NeonCyan else GoldPrimary,
    focusedContainerColor = if (isDark) DarkBg else Color.White,
    unfocusedContainerColor = if (isDark) DarkBg else Color.White
)

/**
 * 实际执行卡片数据保存的方法
 */
fun executeSaveCard(
    context: android.content.Context,
    db: DatabaseHelper,
    cardId: String?,
    originalCard: SharedCard?,
    cardCategory: String,
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
    remark: String,
    cardImages: List<CardImageAsset>
) {
    val finalCard = SharedCard(
        id = cardId ?: UUID.randomUUID().toString(),
        cardCategory = if (cardCategory == "debit") "debit" else "credit",
        country = country.trim(),
        bank = bank.trim(),
        alias = alias.trim(),
        level = level.trim(),
        cardNumber = cardNumber.trim(),
        cvv = cvv.trim(),
        valid = valid.trim(),
        limit = limit,
        type = type.trim().uppercase(),
        isSharedLimit = if (cardCategory == "debit") false else isSharedLimit,
        accountBillDate = accountBillDate,
        dueDate = dueDate,
        billingDaySpendingToNextBill = billingDaySpendingToNextBill,
        annualFee = if (cardCategory == "debit") 0.0 else annualFee,
        isQualified = if (cardCategory == "debit") "" else isQualified,
        nextAnnualFeeCollectionTime = if (cardCategory == "debit") null else nextAnnualFeeCollectionTime,
        lastTime = if (cardCategory == "debit") null else lastTime,
        equity = equity.trim(),
        remark = remark.trim(),
        cardImages = cardImages
    )

    // 保存至本地账本（自动管理 lastModifyTime 和触发 pendingSync 状态）
    SyncCoordinator.commitCardChange(context, finalCard)

    Toast.makeText(context, "卡片已保存", Toast.LENGTH_SHORT).show()
}

private fun formatExpiryInput(input: String, previousValue: String): String {
    val digits = input.filter { it.isDigit() }.take(4)
    val deletingAutoSlash = previousValue.endsWith("/") &&
        input == previousValue.dropLast(1) &&
        digits.length == 2

    if (deletingAutoSlash) {
        return digits.take(1)
    }

    return when {
        digits.length < 2 -> digits
        else -> digits.take(2) + "/" + digits.drop(2)
    }
}

private fun filterAmountInput(input: String): String {
    val normalized = input.replace(",", "")
    val builder = StringBuilder()
    var hasDot = false
    normalized.forEach { char ->
        when {
            char.isDigit() -> builder.append(char)
            char == '.' && !hasDot -> {
                builder.append(char)
                hasDot = true
            }
        }
    }
    return builder.toString()
}

private fun parseAmountOrNull(value: String): Double? {
    val cleaned = value.replace(",", "").trim()
    if (cleaned.isEmpty()) return null
    return cleaned.toDoubleOrNull()?.takeIf { it >= 0.0 }
}

private fun formatEditableAmount(value: Double): String {
    return if (value % 1.0 == 0.0) {
        value.toLong().toString()
    } else {
        value.toString()
    }
}

private fun isValidExpiry(value: String): Boolean {
    if (!Regex("^\\d{2}/\\d{2}$").matches(value)) return false
    val month = value.substring(0, 2).toIntOrNull() ?: return false
    return month in 1..12
}

enum class NfcUiState {
    WAITING,
    READING,
    PARSING,
    SUCCESS,
    ERROR
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
    onScanSuccess: (String, String) -> Unit
) {
    var uiState by remember { mutableStateOf(NfcUiState.WAITING) }
    var scannedNumber by remember { mutableStateOf("") }
    var scannedValid by remember { mutableStateOf("") }

    DisposableEffect(Unit) {
        NfcScannerManager.beginReaderSession("card-form-nfc")
        onDispose {
            NfcScannerManager.endReaderSession("card-form-nfc")
        }
    }

    LaunchedEffect(Unit) {
        launch {
            NfcScannerManager.nfcReadingState.collect { state ->
                if (state == "READING") {
                    uiState = NfcUiState.READING
                }
            }
        }
        launch {
            NfcScannerManager.nfcCardData.collect { (number, valid) ->
                scannedNumber = number
                scannedValid = valid
                
                // 1. 进入“读取完成，正在解析数据”
                uiState = NfcUiState.PARSING
                
                // 2. 模拟高保真数据流解析仪式感延迟
                kotlinx.coroutines.delay(1200)
                
                // 3. 解析成功
                uiState = NfcUiState.SUCCESS
                
                // 4. 触发智能震动
                VibrationUtils.vibrate(context, 120)
                
                // 5. 让用户看清成功动画后，执行成功回调
                kotlinx.coroutines.delay(1000)
                onScanSuccess(number, valid)
            }
        }
        launch {
            NfcScannerManager.nfcUnsupportedCard.collect {
                uiState = NfcUiState.ERROR
                
                // 触发错误震动反馈
                VibrationUtils.vibratePattern(context, longArrayOf(0, 80, 80, 80))
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(if (isDark) Color(0xFF0F172A) else Color(0xFFF8FAFC)),
        contentAlignment = Alignment.Center
    ) {
        // 科技感雷达扩散脉冲动画驱动
        val transition = rememberInfiniteTransition(label = "nfc")
        val isAnimating = uiState == NfcUiState.WAITING || uiState == NfcUiState.READING || uiState == NfcUiState.PARSING
        val duration = when (uiState) {
            NfcUiState.READING -> 700
            NfcUiState.PARSING -> 600
            else -> 2200
        }
        
        val radiusScale by transition.animateFloat(
            initialValue = 0.4f,
            targetValue = 1.0f,
            animationSpec = infiniteRepeatable(
                animation = tween(duration, easing = LinearEasing),
                repeatMode = RepeatMode.Restart
            ),
            label = "radius"
        )
        val alphaVal by transition.animateFloat(
            initialValue = 0.6f,
            targetValue = 0.0f,
            animationSpec = infiniteRepeatable(
                animation = tween(duration, easing = LinearEasing),
                repeatMode = RepeatMode.Restart
            ),
            label = "alpha"
        )

        val accentColor = when (uiState) {
            NfcUiState.PARSING -> if (isDark) NeonGreen else ForestGreen
            NfcUiState.SUCCESS -> if (isDark) NeonGreen else ForestGreen
            NfcUiState.ERROR -> if (isDark) NeonRed else Color.Red
            else -> if (isDark) NeonCyan else GoldPrimary
        }

        // 顶部 Overlay 状态返回导航
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .statusBarsPadding()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            AppBackButton(
                onClick = onBack,
                modifier = Modifier.align(Alignment.CenterStart),
                tint = if (isDark) Color.White else Color.Black,
                containerColor = if (isDark) Color.Black.copy(alpha = 0.42f) else Color.White.copy(alpha = 0.88f),
                borderColor = accentColor.copy(alpha = 0.45f)
            )
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
                    val finalAlpha = if (isAnimating) alphaVal else 0f
                    val finalScale = if (isAnimating) radiusScale else 0f
                    if (finalAlpha > 0f) {
                        drawCircle(
                            color = accentColor.copy(alpha = finalAlpha),
                            radius = size.minDimension / 2 * finalScale,
                            style = Stroke(width = 4.dp.toPx())
                        )
                        drawCircle(
                            color = accentColor.copy(alpha = (finalAlpha + 0.3f).coerceAtMost(0.5f) * finalAlpha),
                            radius = size.minDimension / 2 * (finalScale - 0.25f).coerceAtLeast(0f),
                            style = Stroke(width = 2.dp.toPx())
                        )
                    }
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
                    when (uiState) {
                        NfcUiState.READING -> {
                            CircularProgressIndicator(
                                strokeWidth = 3.dp,
                                color = Color.White,
                                modifier = Modifier.size(48.dp)
                            )
                        }
                        NfcUiState.PARSING -> {
                            CircularProgressIndicator(
                                strokeWidth = 3.dp,
                                color = Color.White,
                                modifier = Modifier.size(48.dp)
                            )
                        }
                        NfcUiState.SUCCESS -> {
                            Icon(
                                imageVector = Icons.Filled.Check,
                                contentDescription = "成功",
                                modifier = Modifier.size(48.dp),
                                tint = Color.White
                            )
                        }
                        NfcUiState.ERROR -> {
                            Icon(
                                imageVector = Icons.Filled.Close,
                                contentDescription = "失败",
                                modifier = Modifier.size(48.dp),
                                tint = Color.White
                            )
                        }
                        else -> {
                            Icon(
                                imageVector = Icons.Default.Nfc,
                                contentDescription = "NFC芯片",
                                modifier = Modifier.size(48.dp),
                                tint = Color.White
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(36.dp))

            Text(
                text = when (uiState) {
                    NfcUiState.WAITING -> "等待卡片靠近..."
                    NfcUiState.READING -> "读取中，请勿移动卡片...."
                    NfcUiState.PARSING -> "读取完成，正在解析数据....."
                    NfcUiState.SUCCESS -> "解析成功"
                    NfcUiState.ERROR -> "解析失败，该卡不支持读取"
                },
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = if (uiState == NfcUiState.ERROR) (if (isDark) NeonRed else Color.Red) else (if (isDark) Color.White else Color.Black),
                textAlign = TextAlign.Center
            )
            
            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = when (uiState) {
                    NfcUiState.WAITING -> "系统正处于自动感应芯片监听中..."
                    NfcUiState.READING -> "金融级安全通道已建立，请保持平稳"
                    NfcUiState.PARSING -> "高保真解密算法执行中，请稍候"
                    NfcUiState.SUCCESS -> "卡号数据提取成功，正在前往录入表单"
                    NfcUiState.ERROR -> "由于该卡片具备金融级防克隆屏蔽或非银行卡，暂不支持读取。建议使用相机扫描或手动录入。"
                },
                fontSize = 13.sp,
                color = if (uiState == NfcUiState.ERROR) (if (isDark) NeonRed.copy(alpha = 0.8f) else Color.Red.copy(alpha = 0.8f)) else (if (isDark) TextGray else TextMuted),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 24.dp)
            )

            Spacer(modifier = Modifier.height(10.dp))
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
    tempCardId: String,
    onCardScanned: (String, String, String?) -> Unit,
    scanTitle: String = "相机扫描录入",
    secondaryActionText: String = "不想扫描？手动录入",
    secondaryActionUseNfcIcon: Boolean = false
) {
    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        val analysisInFlight = remember { AtomicBoolean(false) }
        val lastAnalysisAtMillis = remember { AtomicLong(0L) }
        val cameraProviderRef = remember { AtomicReference<ProcessCameraProvider?>(null) }
        val streamTextRecognizer = remember { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }

        DisposableEffect(Unit) {
            onDispose {
                streamTextRecognizer.close()
                cameraProviderRef.getAndSet(null)?.unbindAll()
            }
        }

        // 动态相机权限检查与索要 Launcher
        var hasCameraPermission by remember {
            mutableStateOf(
                androidx.core.content.ContextCompat.checkSelfPermission(
                    context,
                    android.Manifest.permission.CAMERA
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            )
        }

        val permissionLauncher = rememberLauncherForActivityResult(
            contract = ActivityResultContracts.RequestPermission()
        ) { isGranted ->
            hasCameraPermission = isGranted
            if (!isGranted) {
                Toast.makeText(context, "相机权限被拒绝，无法使用扫描功能", Toast.LENGTH_LONG).show()
            }
        }

        // 进入页面时自动索要相机权限
        LaunchedEffect(Unit) {
            if (!hasCameraPermission) {
                permissionLauncher.launch(android.Manifest.permission.CAMERA)
            }
        }

        var cameraBindError by remember { mutableStateOf(false) }

        // 用以控制防抖，防止识别到后多次回调
        var isScannedTriggered by remember { mutableStateOf(false) }

        // 快门拍照时的 Loading 状态层
        var isCapturing by remember { mutableStateOf(false) }

        // 拍照用 ImageCapture
        val imageCapture = remember {
            ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()
        }

        fun takePhotoAndRecognize(ctx: android.content.Context) {
            if (isCapturing) return
            isCapturing = true

            // 创建大图原件临时存储文件
            val rawFile = try {
                File.createTempFile("raw_card_", ".jpg", ctx.cacheDir)
            } catch (e: Exception) {
                isCapturing = false
                Toast.makeText(ctx, "创建临时文件失败", Toast.LENGTH_SHORT).show()
                return
            }

            val outputOptions = ImageCapture.OutputFileOptions.Builder(rawFile).build()
            imageCapture.takePicture(
                outputOptions,
                ContextCompat.getMainExecutor(ctx),
                object : ImageCapture.OnImageSavedCallback {
                    override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                        Thread {
                            val photoTextRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                            val parsed = try {
                                recognizeCardPhoto(rawFile, photoTextRecognizer)
                            } catch (e: Exception) {
                                e.printStackTrace()
                                null
                            } finally {
                                photoTextRecognizer.close()
                            }

                            val croppedPath = cropCardImage(ctx, rawFile, tempCardId)
                            try { rawFile.delete() } catch (e: Exception) {}

                            (ctx as? android.app.Activity)?.runOnUiThread {
                                isCapturing = false
                                VibrationUtils.vibrate(ctx, 100)
                                if (parsed != null) {
                                    val (cardNo, expiry) = parsed
                                    Toast.makeText(ctx, "📸 智能识别并自动代入卡号！", Toast.LENGTH_SHORT).show()
                                    onCardScanned(cardNo, expiry, croppedPath)
                                } else {
                                    // 优雅降级：OCR 失败但依然成功获取了裁剪后的精美卡片预览
                                    Toast.makeText(ctx, "未能自动识别卡号，已为您裁剪保留卡片照片", Toast.LENGTH_LONG).show()
                                    onCardScanned("", "", croppedPath)
                                }
                            }
                        }.start()
                    }

                    override fun onError(exception: ImageCaptureException) {
                        isCapturing = false
                        Toast.makeText(ctx, "拍照快门激活失败: ${exception.message}", Toast.LENGTH_SHORT).show()
                    }
                }
            )
        }

        if (hasCameraPermission && !cameraBindError) {
            AndroidView(
                factory = { ctx ->
                    val previewView = PreviewView(ctx).apply {
                        scaleType = PreviewView.ScaleType.FILL_CENTER
                    }
                    val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
                    cameraProviderFuture.addListener({
                        try {
                            val cameraProvider = cameraProviderFuture.get()
                            cameraProviderRef.set(cameraProvider)
                            val preview = Preview.Builder().build().apply {
                                setSurfaceProvider(previewView.surfaceProvider)
                            }

                            // A. 初始化 ImageAnalysis 帧分析器（保留自动探测，方便瞬间解析）
                            val imageAnalysis = ImageAnalysis.Builder()
                                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                                .build()

                            imageAnalysis.setAnalyzer(ContextCompat.getMainExecutor(ctx)) { imageProxy ->
                                val now = android.os.SystemClock.elapsedRealtime()
                                if (
                                    isScannedTriggered ||
                                    isCapturing ||
                                    analysisInFlight.get() ||
                                    now - lastAnalysisAtMillis.get() < 650L
                                ) {
                                    imageProxy.close()
                                    return@setAnalyzer
                                }

                                val mediaImage = imageProxy.image
                                if (mediaImage != null) {
                                    analysisInFlight.set(true)
                                    lastAnalysisAtMillis.set(now)
                                    val inputImage = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                                    streamTextRecognizer.process(inputImage)
                                        .addOnSuccessListener { visionText ->
                                            val text = visionText.text
                                            val parsed = parseCardInfoFromText(text)
                                            if (parsed != null && !isScannedTriggered && !isCapturing) {
                                                isScannedTriggered = true
                                                val (cardNo, expiry) = parsed
                                                
                                                VibrationUtils.vibrate(ctx, 100)

                                                // 自动流解析无法提取裁剪图，代入 null
                                                onCardScanned(cardNo, expiry, null)
                                            }
                                        }
                                        .addOnCompleteListener {
                                            analysisInFlight.set(false)
                                            imageProxy.close()
                                        }
                                } else {
                                    imageProxy.close()
                                }
                            }

                            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                            cameraProvider.unbindAll()
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                cameraSelector,
                                preview,
                                imageAnalysis,
                                imageCapture // 同时绑定 ImageCapture 快门组件
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
            // 备用取景器背景 (用于无相机权限或模拟器运行容错)
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Brush.radialGradient(listOf(Color(0xFF0D1117), Color.Black))),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.padding(28.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.PhotoCamera,
                        contentDescription = "相机权限缺失",
                        tint = (if (isDark) Color(0xFF22D3EE) else Color(0xFFC0A060)).copy(alpha = 0.4f),
                        modifier = Modifier.size(48.dp)
                    )
                    Text(
                        text = if (!hasCameraPermission) "⚠️ 未获得相机授权，无法使用扫描功能" else "📸 智能聚焦感应器就绪...",
                        color = Color.LightGray.copy(alpha = 0.85f),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                    if (!hasCameraPermission) {
                        Text(
                            text = "扫描银行卡需要调用您的相机权限进行本地 OCR 识别。卡片图像严格在本地进行分析，绝不上报，100% 保护隐私安全。",
                            color = Color.Gray,
                            fontSize = 12.sp,
                            textAlign = TextAlign.Center,
                            lineHeight = 18.sp
                        )
                        Button(
                            onClick = {
                                permissionLauncher.launch(android.Manifest.permission.CAMERA)
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = (if (isDark) Color(0xFF22D3EE) else Color(0xFFC0A060)).copy(alpha = 0.15f),
                                contentColor = if (isDark) Color(0xFF22D3EE) else Color(0xFFC0A060)
                            ),
                            border = androidx.compose.foundation.BorderStroke(1.dp, (if (isDark) Color(0xFF22D3EE) else Color(0xFFC0A060)).copy(alpha = 0.5f)),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text("点击发起授权申请", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
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
                    text = "已集成智能大图 OCR，可手动拍照瞬间代入卡包卡面。",
                    color = Color.LightGray.copy(alpha = 0.8f),
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center
                )

                Spacer(modifier = Modifier.height(32.dp))
            }
        }

        // 顶层半透明导航栏
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .statusBarsPadding()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            AppBackButton(
                onClick = onBack,
                modifier = Modifier.align(Alignment.CenterStart),
                tint = Color.White,
                containerColor = Color.Black.copy(alpha = 0.48f),
                borderColor = Color.White.copy(alpha = 0.32f)
            )
            Text(
                text = scanTitle,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.align(Alignment.Center)
            )
        }

        // 底部操控区：快门拍照 + 手动输入
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // 快门拍照大按钮
            Box(
                modifier = Modifier
                    .size(76.dp)
                    .background(
                        brush = Brush.radialGradient(listOf(Color(0xFF4ADE80), Color(0xFF16A34A))),
                        shape = CircleShape
                    )
                    .border(4.dp, Color.White, CircleShape)
                    .shadow(elevation = 8.dp, shape = CircleShape)
                    .clickable {
                        takePhotoAndRecognize(context)
                    },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.PhotoCamera,
                    contentDescription = "快门拍照",
                    tint = Color.White,
                    modifier = Modifier.size(32.dp)
                )
            }

            // 切换手动直接填写按钮
            TextButton(
                onClick = onSwitchManual,
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.35f), shape = RoundedCornerShape(20.dp))
                    .padding(horizontal = 16.dp, vertical = 4.dp)
            ) {
                Icon(
                    imageVector = if (secondaryActionUseNfcIcon) Icons.Default.Nfc else Icons.Default.Edit,
                    contentDescription = secondaryActionText,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(secondaryActionText, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
        }

        // 快门拍照时的智能 Loading 解析蒙层
        if (isCapturing) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.75f)),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator(color = NeonGreen)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text("📷 正在抓取高清卡片...", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(6.dp))
                    Text("🔍 正在智能识别并裁剪卡包卡面...", color = Color.LightGray, fontSize = 12.sp)
                }
            }
        }
    }
}

/**
 * 高清拍照后做多区域 OCR。复杂花纹卡面直接识别整图容易被背景和装饰文字干扰，
 * 因此按「卡片框区域 -> 卡号常见区域 -> 对比度增强区域 -> 全图兜底」逐级尝试。
 */
fun recognizeCardPhoto(rawFile: File, recognizer: TextRecognizer): Pair<String, String>? {
    val ownedBitmaps = mutableListOf<Bitmap>()
    val candidates = mutableListOf<Bitmap>()

    fun own(bitmap: Bitmap?): Bitmap? {
        if (bitmap != null) {
            ownedBitmaps.add(bitmap)
        }
        return bitmap
    }

    fun addCandidate(bitmap: Bitmap?) {
        if (bitmap != null) {
            candidates.add(bitmap)
        }
    }

    return try {
        val fullBitmap = own(decodeOrientedBitmap(rawFile, maxDimension = 2400)) ?: return null
        val cardBitmap = own(cropCenteredCardBitmap(fullBitmap, widthRatio = 0.90f, centerYRatio = 0.52f))
        val numberBand = own(cardBitmap?.let { cropRelativeBitmap(it, 0.04f, 0.34f, 0.96f, 0.72f) })
        val lowerBand = own(cardBitmap?.let { cropRelativeBitmap(it, 0.04f, 0.48f, 0.96f, 0.88f) })
        val enhancedCard = own(cardBitmap?.let { createHighContrastBitmap(it) })
        val enhancedNumberBand = own(numberBand?.let { createHighContrastBitmap(it) })
        val enlargedNumberBand = own(numberBand?.let { createScaledBitmapForOcr(it, maxWidth = 1800) })

        addCandidate(cardBitmap)
        addCandidate(numberBand)
        addCandidate(enlargedNumberBand)
        addCandidate(enhancedNumberBand)
        addCandidate(lowerBand)
        addCandidate(enhancedCard)
        addCandidate(fullBitmap)

        val allText = StringBuilder()
        for (candidate in candidates) {
            val text = try {
                Tasks.await(recognizer.process(InputImage.fromBitmap(candidate, 0))).text
            } catch (e: Exception) {
                ""
            }
            if (text.isNotBlank()) {
                allText.appendLine(text)
                parseCardInfoFromText(text)?.let { return it }
            }
        }
        parseCardInfoFromText(allText.toString())
    } finally {
        ownedBitmaps.forEach { bitmap ->
            if (!bitmap.isRecycled) {
                bitmap.recycle()
            }
        }
    }
}

private fun decodeOrientedBitmap(rawFile: File, maxDimension: Int = 2400): Bitmap? {
    val exifInterface = ExifInterface(rawFile.absolutePath)
    val orientation = exifInterface.getAttributeInt(
        ExifInterface.TAG_ORIENTATION,
        ExifInterface.ORIENTATION_NORMAL
    )
    val rotationDegrees = when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90 -> 90
        ExifInterface.ORIENTATION_ROTATE_180 -> 180
        ExifInterface.ORIENTATION_ROTATE_270 -> 270
        else -> 0
    }

    val bounds = BitmapFactory.Options().apply {
        inJustDecodeBounds = true
    }
    BitmapFactory.decodeFile(rawFile.absolutePath, bounds)
    val sampleSize = calculateBitmapSampleSize(bounds.outWidth, bounds.outHeight, maxDimension)
    val options = BitmapFactory.Options().apply {
        inSampleSize = sampleSize
    }

    var bitmap = BitmapFactory.decodeFile(rawFile.absolutePath, options) ?: return null
    if (rotationDegrees != 0) {
        val matrix = Matrix()
        matrix.postRotate(rotationDegrees.toFloat())
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        if (rotated != bitmap) {
            bitmap.recycle()
            bitmap = rotated
        }
    }
    return bitmap
}

private fun calculateBitmapSampleSize(width: Int, height: Int, maxDimension: Int): Int {
    if (width <= 0 || height <= 0 || maxDimension <= 0) return 1
    var sampleSize = 1
    var scaledWidth = width
    var scaledHeight = height
    while (scaledWidth / 2 >= maxDimension || scaledHeight / 2 >= maxDimension) {
        sampleSize *= 2
        scaledWidth /= 2
        scaledHeight /= 2
    }
    return sampleSize
}

private fun cropCenteredCardBitmap(
    bitmap: Bitmap,
    widthRatio: Float,
    centerYRatio: Float
): Bitmap? {
    val w = bitmap.width
    val h = bitmap.height
    if (w <= 0 || h <= 0) return null

    val cropW = (w * widthRatio).toInt().coerceIn(1, w)
    val cropH = (cropW / 1.586f).toInt().coerceIn(1, h)
    val startX = ((w - cropW) / 2).coerceIn(0, w - cropW)
    val desiredCenterY = (h * centerYRatio).toInt()
    val startY = (desiredCenterY - cropH / 2).coerceIn(0, h - cropH)
    return Bitmap.createBitmap(bitmap, startX, startY, cropW, cropH)
}

private fun cropRelativeBitmap(
    bitmap: Bitmap,
    leftRatio: Float,
    topRatio: Float,
    rightRatio: Float,
    bottomRatio: Float
): Bitmap? {
    val left = (bitmap.width * leftRatio).toInt().coerceIn(0, bitmap.width - 1)
    val top = (bitmap.height * topRatio).toInt().coerceIn(0, bitmap.height - 1)
    val right = (bitmap.width * rightRatio).toInt().coerceIn(left + 1, bitmap.width)
    val bottom = (bitmap.height * bottomRatio).toInt().coerceIn(top + 1, bitmap.height)
    return Bitmap.createBitmap(bitmap, left, top, right - left, bottom - top)
}

private fun createScaledBitmapForOcr(bitmap: Bitmap, maxWidth: Int): Bitmap? {
    if (bitmap.width <= 0 || bitmap.height <= 0 || bitmap.width >= maxWidth) return null
    val scale = (maxWidth.toFloat() / bitmap.width).coerceAtMost(2.2f)
    if (scale <= 1.05f) return null
    val targetW = (bitmap.width * scale).toInt().coerceAtLeast(bitmap.width)
    val targetH = (bitmap.height * scale).toInt().coerceAtLeast(bitmap.height)
    return Bitmap.createScaledBitmap(bitmap, targetW, targetH, true)
}

private fun createHighContrastBitmap(bitmap: Bitmap): Bitmap {
    val output = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
    val width = bitmap.width
    val height = bitmap.height
    val pixels = IntArray(width * height)
    bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
    for (index in pixels.indices) {
        val color = pixels[index]
        val r = (color shr 16) and 0xFF
        val g = (color shr 8) and 0xFF
        val b = color and 0xFF
        val gray = (r * 0.299f + g * 0.587f + b * 0.114f).toInt()
        val contrasted = ((gray - 128) * 1.65f + 128).toInt().coerceIn(0, 255)
        pixels[index] = (0xFF shl 24) or (contrasted shl 16) or (contrasted shl 8) or contrasted
    }
    output.setPixels(pixels, 0, width, 0, 0, width, height)
    return output
}

/**
 * Exif 物理方向旋转还原并 1.586 银行卡中间比例居中裁剪
 */
fun cropCardImage(context: android.content.Context, rawFile: File, cardId: String): String? {
    try {
        val bitmap = decodeOrientedBitmap(rawFile) ?: return null
        val cropped = cropCenteredCardBitmap(bitmap, widthRatio = 0.85f, centerYRatio = 0.52f) ?: run {
            bitmap.recycle()
            return null
        }

        // 5. 保存剪裁卡片至沙盒 scanned_cards 目录
        val outputDir = File(context.filesDir, "scanned_cards")
        if (!outputDir.exists()) {
            outputDir.mkdirs()
        }
        val outputFile = File(outputDir, "${cardId}.jpg")
        outputFile.outputStream().use { out ->
            cropped.compress(Bitmap.CompressFormat.JPEG, 90, out)
        }

        // 6. 严密回收 Bitmap 对象，释放 Heap 物理内存，规避 OOM
        bitmap.recycle()
        cropped.recycle()

        return outputFile.absolutePath
    } catch (e: Exception) {
        e.printStackTrace()
    }
    return null
}

/**
 * 从识别出的文本中智能过滤匹配卡号及有效期
 */
fun parseCardInfoFromText(text: String): Pair<String, String>? {
    val normalizedTexts = listOf(text, normalizeOcrDigitLikeText(text)).distinct()
    val candidates = linkedSetOf<String>()

    normalizedTexts.forEach { candidateText ->
        candidateText.lineSequence().forEach { line ->
            collectCardNumberCandidatesFromLine(line, candidates)
        }
        collectCardNumberCandidatesFromDenseText(candidateText, candidates)
    }

    for (candidate in candidates) {
        // 对识别到的潜在卡号执行 Luhn 校验过滤，防噪点和错码。
        if (candidate.length in 13..19 && luhnCheck(candidate)) {
            val expiry = findExpiryFromText(text).ifEmpty { findExpiryFromText(normalizeOcrDigitLikeText(text)) }
            return Pair(candidate, expiry)
        }
    }
    return null
}

private fun collectCardNumberCandidatesFromLine(line: String, output: MutableSet<String>) {
    val digitGroups = Regex("\\d+").findAll(line).map { it.value }.toList()
    for (start in digitGroups.indices) {
        val builder = StringBuilder()
        for (index in start until digitGroups.size) {
            builder.append(digitGroups[index])
            val value = builder.toString()
            when {
                value.length in 13..19 -> output.add(value)
                value.length > 19 -> break
            }
        }
    }

    val compact = line.replace("\\s".toRegex(), "").replace("-", "")
    if (compact.length in 13..19 && compact.all { it.isDigit() }) {
        output.add(compact)
    }
}

private fun collectCardNumberCandidatesFromDenseText(text: String, output: MutableSet<String>) {
    val pattern = Regex("(?:\\d[\\s\\-·•]*){13,23}")
    pattern.findAll(text).forEach { match ->
        val digits = match.value.filter { it.isDigit() }
        if (digits.length in 13..19) {
            output.add(digits)
        } else if (digits.length > 19) {
            for (start in 0..(digits.length - 13)) {
                for (length in 13..19) {
                    if (start + length <= digits.length) {
                        output.add(digits.substring(start, start + length))
                    }
                }
            }
        }
    }
}

private fun normalizeOcrDigitLikeText(text: String): String {
    return buildString(text.length) {
        text.forEach { char ->
            append(
                when (char) {
                    '０' -> '0'
                    '１' -> '1'
                    '２' -> '2'
                    '３' -> '3'
                    '４' -> '4'
                    '５' -> '5'
                    '６' -> '6'
                    '７' -> '7'
                    '８' -> '8'
                    '９' -> '9'
                    'O', 'o', 'D' -> '0'
                    'I', 'l', '|', '!' -> '1'
                    'S', 's' -> '5'
                    'B' -> '8'
                    else -> char
                }
            )
        }
    }
}

/**
 * 银行卡标准卡号 Luhn 逻辑校验算法
 */
fun luhnCheck(number: String): Boolean {
    var sum = 0
    var alternate = false
    for (i in number.length - 1 downTo 0) {
        var n = Character.getNumericValue(number[i])
        if (alternate) {
            n *= 2
            if (n > 9) {
                n = n % 10 + 1
            }
        }
        sum += n
        alternate = !alternate
    }
    return sum % 10 == 0
}

/**
 * 从文本中正则扫描符合 MM/YY 格式的有效期字段
 */
fun findExpiryFromText(text: String): String {
    val keywordPattern = Regex("(?i)(EXP|VALID|THRU|VALID\\s+THRU|有效期)\\D{0,12}(0[1-9]|1[0-2])\\D{0,4}(\\d{2}|\\d{4})")
    keywordPattern.find(text)?.let { match ->
        return formatExpiryValue(match.groupValues[2], match.groupValues[3])
    }

    val separatedPattern = Regex("(?<!\\d)(0[1-9]|1[0-2])\\s*[/\\.\\-]\\s*(\\d{2}|\\d{4})(?!\\d)")
    separatedPattern.find(text)?.let { match ->
        return formatExpiryValue(match.groupValues[1], match.groupValues[2])
    }

    return ""
}

private fun formatExpiryValue(month: String, year: String): String {
    val finalYear = if (year.length == 4) year.takeLast(2) else year
    return "${month.padStart(2, '0')}/$finalYear"
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
            contentScale = ContentScale.Fit
        )
    }
}
