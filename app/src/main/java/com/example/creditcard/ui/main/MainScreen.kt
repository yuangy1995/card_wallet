package com.example.creditcard.ui.main

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.navigation3.runtime.NavKey
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.min
import com.example.creditcard.CardDetail
import com.example.creditcard.CardForm
import com.example.creditcard.data.CardChangeDetail
import com.example.creditcard.data.SharedCard
import com.example.creditcard.data.SyncHistoryEntry
import com.example.creditcard.theme.*
import com.example.creditcard.ui.components.AppBackButton
import com.example.creditcard.utils.AppStorageManager
import com.example.creditcard.utils.AppStorageSnapshot
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.NfcScannerManager
import com.example.creditcard.utils.ThemeManager
import com.example.creditcard.utils.WebDAVClient
import com.example.creditcard.utils.WebDAVConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class ToolsMode {
    HOME,
    STATS,
    VERIFY_PREFETCH,
    VERIFY,
    SYNC_LOG,
    BEST_USAGE
}

private const val TOOL_MENU_PREFS = "tool_menu_preferences"
private const val TOOL_MENU_ORDER_KEY = "tool_menu_order"
private const val TOOL_MENU_HIDDEN_KEY = "tool_menu_hidden"

private val defaultToolMenuIds = listOf("stats", "verify", "best_usage", "sync_log")

private data class ToolMenuItem(
    val id: String,
    val icon: ImageVector,
    val title: String,
    val subtitle: String,
    val accent: Color,
    val onClick: () -> Unit
)

private data class VerifiedCardRecord(
    val cardNumber: String,
    val valid: String,
    val existedAtScan: Boolean
)

/**
 * Android 原生信用卡客户端 ── 体验精塑与共享额度算法修正重塑主屏幕
 * 高内聚集成：零顶栏极简视觉、动态四态云同步微标、财富分析面板、内聚大融合设置
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(
    onItemClick: (NavKey) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    
    // 监听全局核心状态
    val cards by SyncCoordinator.cardsFlow.collectAsState()
    val syncStatus by SyncCoordinator.syncStatus.collectAsState()
    val isDark by ThemeManager.isDarkTheme.collectAsState()

    // 底部 Tab 切换状态 (0: 卡包, 1: 工具, 2: 设置) - 纯图标化极简渲染
    var selectedTab by remember { mutableIntStateOf(0) }
    var toolsMode by remember { mutableStateOf(ToolsMode.HOME) }
    var settingsMode by remember { mutableStateOf(SettingsMode.MAIN) }
    var verifySessionSeed by remember { mutableIntStateOf(0) }

    // 系统返回先处理工具、设置子页面和非首页 Tab，再交给 Activity 默认退出。
    BackHandler(enabled = selectedTab != 0 || toolsMode != ToolsMode.HOME || settingsMode != SettingsMode.MAIN) {
        when {
            selectedTab == 1 && toolsMode != ToolsMode.HOME -> toolsMode = ToolsMode.HOME
            selectedTab == 2 && settingsMode != SettingsMode.MAIN -> settingsMode = SettingsMode.MAIN
            selectedTab != 0 -> {
                selectedTab = 0
                toolsMode = ToolsMode.HOME
                settingsMode = SettingsMode.MAIN
            }
            else -> {
                toolsMode = ToolsMode.HOME
                settingsMode = SettingsMode.MAIN
            }
        }
    }
    
    // 卡包搜索状态
    var searchQuery by remember { mutableStateOf("") }

    // 过滤后的卡片列表
    val filteredCards = remember(cards, searchQuery) {
        if (searchQuery.isBlank()) {
            cards
        } else {
            cards.filter { card ->
                card.bank.contains(searchQuery, ignoreCase = true) ||
                card.alias.contains(searchQuery, ignoreCase = true) ||
                card.cardNumber.replace(" ", "").contains(searchQuery.replace(" ", "")) ||
                card.remark.contains(searchQuery, ignoreCase = true) ||
                getCardBrand(card.cardNumber).contains(searchQuery, ignoreCase = true)
            }
        }
    }

    val isSubPage = (selectedTab == 1 && toolsMode != ToolsMode.HOME) ||
                    (selectedTab == 2 && settingsMode != SettingsMode.MAIN)

    Scaffold(
        bottomBar = {
            if (!isSubPage) {
                NavigationBar(
                    modifier = Modifier.height(60.dp),
                    containerColor = MaterialTheme.colorScheme.surface,
                    tonalElevation = 8.dp
                ) {
                    // 1. 卡包 Tab - 去文字纯图标
                    NavigationBarItem(
                        selected = selectedTab == 0,
                        onClick = {
                            selectedTab = 0
                            toolsMode = ToolsMode.HOME
                            settingsMode = SettingsMode.MAIN
                        },
                        icon = { Icon(Icons.Filled.Wallet, contentDescription = "卡包") },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = if (isDark) NeonCyan else GoldPrimary,
                            indicatorColor = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.15f)
                        )
                    )
                    // 2. 统计 Tab - 去文字纯图标
                    NavigationBarItem(
                        selected = selectedTab == 1,
                        onClick = {
                            selectedTab = 1
                            toolsMode = ToolsMode.HOME
                            settingsMode = SettingsMode.MAIN
                        },
                        icon = { Icon(Icons.Filled.Handyman, contentDescription = "工具") },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = if (isDark) NeonCyan else GoldPrimary,
                            indicatorColor = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.15f)
                        )
                    )
                    // 3. 设置 Tab - 去文字纯图标
                    NavigationBarItem(
                        selected = selectedTab == 2,
                        onClick = {
                            selectedTab = 2
                            toolsMode = ToolsMode.HOME
                            settingsMode = SettingsMode.MAIN
                        },
                        icon = { Icon(Icons.Filled.Settings, contentDescription = "设置") },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = if (isDark) NeonCyan else GoldPrimary,
                            indicatorColor = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.15f)
                        )
                    )
                }
            }
        },
        floatingActionButton = {
            if (selectedTab == 0) {
                FloatingActionButton(
                    onClick = { onItemClick(CardForm(null)) },
                    containerColor = if (isDark) NeonCyan else GoldPrimary,
                    contentColor = if (isDark) DarkBg else Color.White,
                    shape = CircleShape,
                    modifier = Modifier.padding(bottom = 16.dp, end = 8.dp)
                ) {
                    Icon(imageVector = Icons.Filled.Add, contentDescription = "新增信用卡")
                }
            }
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { innerPadding ->
        
        Box(
            modifier = modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            when (selectedTab) {
                // =====================================================================
                // 📂 Tab 0: 零顶栏极简视觉、动态四态云同步微标与单行高度搜索框
                // =====================================================================
                0 -> {
                    Column(modifier = Modifier.fillMaxSize()) {
                        
                        // A. 顶部极简操作状态行 (彻底去除大标题与多余留白)
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 6.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // 左侧完全清空，极致高雅
                            Spacer(modifier = Modifier.weight(1f))

                            // 右侧并排：云同步动态呼吸微标 与 深浅主题切换按钮
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                // 1. 云同步四态指示动态微标
                                DynamicSyncBadge(
                                    isSyncing = syncStatus.isSyncing,
                                    statusType = syncStatus.type,
                                    isDark = isDark,
                                    onSyncClick = {
                                        Toast.makeText(context, "正在同步云端数据...", Toast.LENGTH_SHORT).show()
                                        coroutineScope.launch {
                                            SyncCoordinator.synchronize(context, publishLocalChanges = true)
                                        }
                                    }
                                )
                                
                                Spacer(modifier = Modifier.width(8.dp))

                                // 2. 主题热切换图标
                                IconButton(
                                    onClick = { ThemeManager.toggleTheme(context) },
                                    modifier = Modifier.size(36.dp)
                                ) {
                                    Icon(
                                        imageVector = if (isDark) Icons.Filled.LightMode else Icons.Filled.NightlightRound,
                                        contentDescription = "切换主题",
                                        tint = if (isDark) NeonCyan else GoldPrimary,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                        }

                        // B. 精致单行高度搜索框 (精准收窄至48.dp，垂直完美居中，不占两行)
                        OutlinedTextField(
                            value = searchQuery,
                            onValueChange = { searchQuery = it },
                            placeholder = {
                                Text(
                                    text = "搜索银行、卡号、别名、备注或卡组织...",
                                    color = if (isDark) TextGray.copy(alpha = 0.5f) else TextMuted.copy(alpha = 0.5f),
                                    fontSize = 12.sp
                                )
                            },
                            leadingIcon = {
                                Icon(
                                    imageVector = Icons.Filled.Search,
                                    contentDescription = "搜索",
                                    tint = if (isDark) NeonCyan else GoldPrimary,
                                    modifier = Modifier.size(18.dp)
                                )
                            },
                            trailingIcon = {
                                if (searchQuery.isNotEmpty()) {
                                    IconButton(
                                        onClick = { searchQuery = "" },
                                        modifier = Modifier.size(32.dp)
                                    ) {
                                        Icon(imageVector = Icons.Filled.Clear, contentDescription = "清除", modifier = Modifier.size(16.dp))
                                    }
                                }
                            },
                            singleLine = true,
                            shape = RoundedCornerShape(24.dp),
                            textStyle = TextStyle(
                                fontSize = 13.sp,
                                color = MaterialTheme.colorScheme.onBackground
                            ),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(52.dp) // 调整高度为 52.dp，确保文字在 OutlinedTextField 默认内部 padding 下能够完美垂直居中并显示全
                                .padding(horizontal = 12.dp)
                                .shadow(
                                    elevation = if (isDark) 3.dp else 1.5.dp,
                                    shape = RoundedCornerShape(24.dp),
                                    spotColor = if (isDark) NeonCyan else GoldPrimary
                                ),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = if (isDark) NeonCyan else GoldPrimary,
                                unfocusedBorderColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.3f),
                                focusedContainerColor = if (isDark) DarkCardBg else Color.White,
                                unfocusedContainerColor = if (isDark) DarkCardBg else Color.White
                            )
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        // C. 过滤渲染卡片列表
                        if (filteredCards.isEmpty()) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .weight(1f),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = if (searchQuery.isEmpty()) "暂无信用卡，点击右下角新增卡片" else "未匹配到符合条件的信用卡",
                                    color = if (isDark) TextGray else TextMuted,
                                    fontSize = 14.sp
                                )
                            }
                        } else {
                            LazyColumn(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .weight(1f),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                verticalArrangement = Arrangement.spacedBy(14.dp)
                            ) {
                                items(filteredCards, key = { it.id }) { card ->
                                    CreditCardTile(
                                        card = card,
                                        isDark = isDark,
                                        onClick = { onItemClick(CardDetail(card.id)) }
                                    )
                                }
                            }
                        }
                    }
                }

                // =====================================================================
                // 🧰 Tab 1: 工具入口，统计分析与快速验卡
                // =====================================================================
                1 -> {
                    when (toolsMode) {
                        ToolsMode.HOME -> ToolsPanel(
                            cards = cards,
                            isDark = isDark,
                            onOpenStats = { toolsMode = ToolsMode.STATS },
                            onStartVerify = {
                                if (android.nfc.NfcAdapter.getDefaultAdapter(context) == null) {
                                    Toast.makeText(context, "当前手机不支持 NFC，无法使用快速验卡功能", Toast.LENGTH_LONG).show()
                                } else {
                                    verifySessionSeed += 1
                                    toolsMode = ToolsMode.VERIFY_PREFETCH
                                }
                            },
                            onOpenSyncHistory = { toolsMode = ToolsMode.SYNC_LOG },
                            onOpenBestUsage = { toolsMode = ToolsMode.BEST_USAGE }
                        )
                        ToolsMode.STATS -> ToolsStatsPanel(
                            cards = cards,
                            isDark = isDark,
                            onBack = { toolsMode = ToolsMode.HOME }
                        )
                        ToolsMode.VERIFY_PREFETCH -> VerifyCloudPrefetchPanel(
                            seed = verifySessionSeed,
                            isDark = isDark,
                            onReady = { toolsMode = ToolsMode.VERIFY },
                            onCancel = { toolsMode = ToolsMode.HOME }
                        )
                        ToolsMode.VERIFY -> QuickVerifyPanel(
                            cards = cards,
                            isDark = isDark,
                            onAddCard = { number, valid ->
                                onItemClick(CardForm(cardId = null, prefillCardNumber = number, prefillValid = valid))
                            },
                            onFinish = { toolsMode = ToolsMode.HOME }
                        )
                        ToolsMode.SYNC_LOG -> ToolsSyncHistoryPanel(
                            isDark = isDark,
                            onBack = { toolsMode = ToolsMode.HOME }
                        )
                        ToolsMode.BEST_USAGE -> BestUsagePanel(
                            cards = cards,
                            isDark = isDark,
                            onConfigureCard = { cardId ->
                                onItemClick(CardForm(cardId = cardId))
                            },
                            onBack = { toolsMode = ToolsMode.HOME }
                        )
                    }
                }

                // =====================================================================
                // ⚙️ Tab 2: 云配置盾牌卡片、配置折叠、样式高级大融合控制台
                // =====================================================================
                2 -> {
                    SettingsPanel(
                        isDark = isDark,
                        settingsMode = settingsMode,
                        onSettingsModeChange = { settingsMode = it }
                    )
                }
            }
        }
    }
}

// =============================================================================
// 📂 Tab 0 子组件: 动态云同步徽标、拟真卡片与金芯片手绘
// =============================================================================

/**
 * 右上角发光动态云端/同步状态指示徽标 (Interactive Cloud Stamp)
 * 具备360度流畅旋转动效，并承载四态呼吸配色
 */
@Composable
fun DynamicSyncBadge(
    isSyncing: Boolean,
    statusType: String,
    isDark: Boolean,
    onSyncClick: () -> Unit
) {
    // 1. 无限顺时针360度旋转动画 spec 声明
    val infiniteTransition = rememberInfiniteTransition(label = "syncRotation")
    val rotationAngle by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "syncRotation"
    )

    // 2. 自适应状态颜色确定
    val iconColor = when {
        isSyncing -> if (isDark) NeonCyan else NavySecondary
        statusType == "success" -> if (isDark) NeonGreen else ForestGreen
        statusType == "error" -> if (isDark) NeonRed else Color.Red
        else -> if (isDark) Color(0xFFFF9100) else WarmOrange // warning
    }

    val badgeBgColor = iconColor.copy(alpha = 0.15f)

    Box(
        modifier = Modifier
            .size(width = 44.dp, height = 36.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(badgeBgColor)
            .border(1.dp, iconColor.copy(alpha = 0.3f), RoundedCornerShape(8.dp))
            .clickable(enabled = !isSyncing) { onSyncClick() },
        contentAlignment = Alignment.Center
    ) {
        if (isSyncing) {
            // 正在同步：进行 360 度圆滑旋转
            Icon(
                imageVector = Icons.Filled.Sync,
                contentDescription = "正在同步",
                tint = iconColor,
                modifier = Modifier
                    .size(20.dp)
                    .rotate(rotationAngle)
            )
        } else {
            // 静止态：按同步成败状态显示经典 Icon
            Icon(
                imageVector = when (statusType) {
                    "success" -> Icons.Filled.CloudDone
                    "error" -> Icons.Filled.CloudOff
                    else -> Icons.Filled.CloudQueue // warning
                },
                contentDescription = "同步状态",
                tint = iconColor,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

/**
 * 1:1.586 实体卡比例的高质感拟真信用卡磁贴
 */
@Composable
fun CreditCardTile(
    card: SharedCard,
    isDark: Boolean,
    onClick: () -> Unit
) {
    val brand = getCardBrand(card.cardNumber)
    
    // 自定义卡片背景渐变
    val gradientBrush = when (brand) {
        "Visa" -> Brush.linearGradient(listOf(Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)))
        "Mastercard" -> Brush.linearGradient(listOf(Color(0xFF373B44), Color(0xFF4286f4)))
        "Amex" -> Brush.linearGradient(listOf(Color(0xFF11998e), Color(0xFF38ef7d)))
        "UnionPay" -> Brush.linearGradient(listOf(Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)))
        "JCB" -> Brush.linearGradient(listOf(Color(0xFF1F1C2C), Color(0xFF928DAB)))
        "Discover" -> Brush.linearGradient(listOf(Color(0xFFF000FF), Color(0xFF7B00FF)))
        else -> Brush.linearGradient(listOf(Color(0xFF1F1C2C), Color(0xFF928DAB)))
    }

    val cardModifier = if (isDark) {
        Modifier
            .fillMaxWidth()
            .aspectRatio(1.586f)
            .shadow(8.dp, shape = RoundedCornerShape(16.dp), spotColor = Color.Black)
            .clip(RoundedCornerShape(16.dp))
            .background(gradientBrush)
    } else {
        Modifier
            .fillMaxWidth()
            .aspectRatio(1.586f)
            .shadow(6.dp, shape = RoundedCornerShape(16.dp), spotColor = NavySecondary)
            .clip(RoundedCornerShape(16.dp))
            .background(gradientBrush)
    }

    Box(
        modifier = cardModifier
            .clickable { onClick() }
            .padding(18.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // 第一行：银行名与卡组织 Logo
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = card.bank.ifEmpty { "信用银行" },
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = card.alias.ifEmpty { "未命名别名" },
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Light,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                // 全套高保真卡组织徽标
                CardBrandBadge(brand = brand)
            }

            // 第二行：智能安全金属金芯片 (EMV Chip) 的高保真绘制
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                EMVChip()
            }

            // 第三行：分段完整卡号
            Text(
                text = formatSpacingCardNumber(card.cardNumber),
                color = Color.White,
                fontSize = 15.sp,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            // 第四行：额度与还款信息
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Bottom
            ) {
                Column {
                    Text(
                        text = "信用额度",
                        color = Color.White.copy(alpha = 0.6f),
                        fontSize = 9.sp
                    )
                    Text(
                        text = "${card.type} $${String.format("%,.0f", card.limit)}",
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        text = "有效期",
                        color = Color.White.copy(alpha = 0.6f),
                        fontSize = 9.sp
                    )
                    Text(
                        text = card.valid.ifEmpty { "MM/YY" },
                        color = Color.White,
                        fontSize = 12.sp,
                        fontFamily = FontFamily.Monospace
                    )
                }
            }
        }
    }
}

// =============================================================================
// 🧰 Tab 1 子组件: 工具主页、统计入口与快速验卡
// =============================================================================

@Composable
fun ToolsPanel(
    cards: List<SharedCard>,
    isDark: Boolean,
    onOpenStats: () -> Unit,
    onStartVerify: () -> Unit,
    onOpenSyncHistory: () -> Unit,
    onOpenBestUsage: () -> Unit
) {
    val context = LocalContext.current
    var toolOrder by remember { mutableStateOf(loadToolMenuOrder(context)) }
    var hiddenToolIds by remember { mutableStateOf(loadHiddenToolIds(context)) }
    var showCustomizeDialog by remember { mutableStateOf(false) }
    var draggingToolId by remember { mutableStateOf<String?>(null) }
    var draggingOffsetPx by remember { mutableFloatStateOf(0f) }
    val density = LocalDensity.current
    val reorderThresholdPx = with(density) { 82.dp.toPx() }
    val allTools = listOf(
        ToolMenuItem(
            id = "stats",
            icon = Icons.Filled.Analytics,
            title = "统计分析",
            subtitle = "查看额度、币种、共享额度和年费预警",
            accent = if (isDark) NeonCyan else GoldPrimary,
            onClick = onOpenStats
        ),
        ToolMenuItem(
            id = "verify",
            icon = Icons.Filled.FactCheck,
            title = "快速验卡",
            subtitle = "先同步云端最新数据，再用 NFC 逐张核对本地卡包",
            accent = if (isDark) NeonGreen else ForestGreen,
            onClick = onStartVerify
        ),
        ToolMenuItem(
            id = "best_usage",
            icon = Icons.Filled.AutoAwesome,
            title = "优惠用卡",
            subtitle = "实时计算卡片当前可用免息期，智能推荐今日消费首选卡片",
            accent = if (isDark) NeonPurple else NavySecondary,
            onClick = onOpenBestUsage
        ),
        ToolMenuItem(
            id = "sync_log",
            icon = Icons.Filled.History,
            title = "同步记录",
            subtitle = "查看与 WebDAV 云盘的数据同步记录",
            accent = if (isDark) NeonCyan else GoldPrimary,
            onClick = onOpenSyncHistory
        )
    )
    val toolMap = allTools.associateBy { it.id }
    val orderedTools = toolOrder.mapNotNull { toolMap[it] }
    val visibleTools = orderedTools.filterNot { it.id in hiddenToolIds }

    fun updateToolMenu(nextOrder: List<String> = toolOrder, nextHidden: Set<String> = hiddenToolIds) {
        toolOrder = nextOrder
        hiddenToolIds = nextHidden
        saveToolMenuConfig(context, nextOrder, nextHidden)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Spacer(modifier = Modifier.height(2.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "工具",
                fontSize = 26.sp,
                fontWeight = FontWeight.Black,
                color = MaterialTheme.colorScheme.onBackground
            )

            TextButton(onClick = { showCustomizeDialog = true }) {
                Icon(
                    imageVector = Icons.Filled.Tune,
                    contentDescription = "自定义工具列表",
                    modifier = Modifier.size(17.dp),
                    tint = if (isDark) NeonCyan else GoldPrimary
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text("自定义", fontSize = 12.sp, color = if (isDark) NeonCyan else GoldPrimary)
            }
        }

        if (visibleTools.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .border(1.dp, (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.18f), RoundedCornerShape(14.dp))
                    .padding(18.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "暂无显示的工具，可点击右上角自定义恢复显示。",
                    fontSize = 13.sp,
                    color = if (isDark) TextGray else TextMuted,
                    textAlign = TextAlign.Center
                )
            }
        } else {
            visibleTools.forEach { tool ->
                val isDragging = draggingToolId == tool.id
                ToolActionTile(
                    icon = tool.icon,
                    title = tool.title,
                    subtitle = tool.subtitle,
                    accent = tool.accent,
                    onClick = tool.onClick,
                    modifier = Modifier
                        .zIndex(if (isDragging) 1f else 0f)
                        .graphicsLayer {
                            translationY = if (isDragging) draggingOffsetPx else 0f
                            shadowElevation = if (isDragging) 12.dp.toPx() else 0f
                        }
                        .pointerInput(tool.id, toolOrder, hiddenToolIds) {
                            detectDragGesturesAfterLongPress(
                                onDragStart = {
                                    draggingToolId = tool.id
                                    draggingOffsetPx = 0f
                                },
                                onDragCancel = {
                                    draggingToolId = null
                                    draggingOffsetPx = 0f
                                },
                                onDragEnd = {
                                    draggingToolId = null
                                    draggingOffsetPx = 0f
                                },
                                onDrag = { change, dragAmount ->
                                    change.consume()
                                    if (draggingToolId != tool.id) return@detectDragGesturesAfterLongPress

                                    draggingOffsetPx += dragAmount.y
                                    val currentVisibleIds = normalizeToolMenuOrder(toolOrder).filterNot { it in hiddenToolIds }
                                    val currentIndex = currentVisibleIds.indexOf(tool.id)
                                    if (currentIndex == -1) return@detectDragGesturesAfterLongPress

                                    if (draggingOffsetPx > reorderThresholdPx && currentIndex < currentVisibleIds.lastIndex) {
                                        val nextVisibleOrder = moveListItem(currentVisibleIds, currentIndex, currentIndex + 1)
                                        val nextOrder = mergeVisibleToolOrder(toolOrder, hiddenToolIds, nextVisibleOrder)
                                        updateToolMenu(nextOrder = nextOrder)
                                        draggingOffsetPx -= reorderThresholdPx
                                    } else if (draggingOffsetPx < -reorderThresholdPx && currentIndex > 0) {
                                        val nextVisibleOrder = moveListItem(currentVisibleIds, currentIndex, currentIndex - 1)
                                        val nextOrder = mergeVisibleToolOrder(toolOrder, hiddenToolIds, nextVisibleOrder)
                                        updateToolMenu(nextOrder = nextOrder)
                                        draggingOffsetPx += reorderThresholdPx
                                    }
                                }
                            )
                        }
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))
    }

    if (showCustomizeDialog) {
        ToolMenuCustomizeDialog(
            items = orderedTools,
            order = toolOrder,
            hiddenIds = hiddenToolIds,
            isDark = isDark,
            onMove = { fromIndex, toIndex ->
                updateToolMenu(nextOrder = moveToolMenuItem(toolOrder, fromIndex, toIndex))
            },
            onVisibilityChange = { id, visible ->
                val nextHidden = if (visible) hiddenToolIds - id else hiddenToolIds + id
                updateToolMenu(nextHidden = nextHidden)
            },
            onReset = {
                updateToolMenu(defaultToolMenuIds, emptySet())
            },
            onDismiss = { showCustomizeDialog = false }
        )
    }
}

@Composable
private fun ToolMenuCustomizeDialog(
    items: List<ToolMenuItem>,
    order: List<String>,
    hiddenIds: Set<String>,
    isDark: Boolean,
    onMove: (fromIndex: Int, toIndex: Int) -> Unit,
    onVisibilityChange: (id: String, visible: Boolean) -> Unit,
    onReset: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("自定义工具列表", fontWeight = FontWeight.Bold) },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 420.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items.forEachIndexed { index, item ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (isDark) DarkBg else LightBg)
                            .padding(horizontal = 10.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = item.icon,
                            contentDescription = item.title,
                            tint = item.accent,
                            modifier = Modifier.size(22.dp)
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(item.title, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                            Text(
                                text = if (item.id in hiddenIds) "已隐藏" else "已显示",
                                fontSize = 11.sp,
                                color = if (isDark) TextGray else TextMuted
                            )
                        }
                        IconButton(
                            onClick = { onMove(index, index - 1) },
                            enabled = index > 0,
                            modifier = Modifier.size(34.dp)
                        ) {
                            Icon(Icons.Filled.KeyboardArrowUp, contentDescription = "上移")
                        }
                        IconButton(
                            onClick = { onMove(index, index + 1) },
                            enabled = index < order.lastIndex,
                            modifier = Modifier.size(34.dp)
                        ) {
                            Icon(Icons.Filled.KeyboardArrowDown, contentDescription = "下移")
                        }
                        Checkbox(
                            checked = item.id !in hiddenIds,
                            onCheckedChange = { checked -> onVisibilityChange(item.id, checked) }
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("完成")
            }
        },
        dismissButton = {
            TextButton(onClick = onReset) {
                Text("恢复默认")
            }
        }
    )
}

private fun loadToolMenuOrder(context: Context): List<String> {
    val saved = context.getSharedPreferences(TOOL_MENU_PREFS, Context.MODE_PRIVATE)
        .getString(TOOL_MENU_ORDER_KEY, null)
        ?.split(",")
        ?.map { it.trim() }
        ?.filter { it.isNotEmpty() }
        .orEmpty()
    return normalizeToolMenuOrder(saved)
}

private fun loadHiddenToolIds(context: Context): Set<String> {
    val saved = context.getSharedPreferences(TOOL_MENU_PREFS, Context.MODE_PRIVATE)
        .getString(TOOL_MENU_HIDDEN_KEY, null)
        ?.split(",")
        ?.map { it.trim() }
        ?.filter { it in defaultToolMenuIds }
        .orEmpty()
    return saved.toSet()
}

private fun saveToolMenuConfig(context: Context, order: List<String>, hiddenIds: Set<String>) {
    context.getSharedPreferences(TOOL_MENU_PREFS, Context.MODE_PRIVATE)
        .edit()
        .putString(TOOL_MENU_ORDER_KEY, normalizeToolMenuOrder(order).joinToString(","))
        .putString(TOOL_MENU_HIDDEN_KEY, hiddenIds.filter { it in defaultToolMenuIds }.joinToString(","))
        .apply()
}

private fun normalizeToolMenuOrder(order: List<String>): List<String> {
    val validSaved = order.filter { it in defaultToolMenuIds }.distinct()
    val missing = defaultToolMenuIds.filterNot { it in validSaved }
    return validSaved + missing
}

private fun mergeVisibleToolOrder(order: List<String>, hiddenIds: Set<String>, visibleOrder: List<String>): List<String> {
    val visibleQueue = visibleOrder.toMutableList()
    return normalizeToolMenuOrder(order).map { id ->
        if (id in hiddenIds) {
            id
        } else {
            if (visibleQueue.isNotEmpty()) visibleQueue.removeAt(0) else id
        }
    }
}

private fun moveToolMenuItem(order: List<String>, fromIndex: Int, toIndex: Int): List<String> {
    return moveListItem(normalizeToolMenuOrder(order), fromIndex, toIndex)
}

private fun <T> moveListItem(items: List<T>, fromIndex: Int, toIndex: Int): List<T> {
    if (fromIndex !in items.indices || toIndex !in items.indices) return items
    val next = items.toMutableList()
    val item = next.removeAt(fromIndex)
    next.add(toIndex, item)
    return next
}

@Composable
fun ToolActionTile(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    accent: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, accent.copy(alpha = 0.22f), RoundedCornerShape(14.dp))
            .clickable { onClick() }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(accent.copy(alpha = 0.16f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = title, tint = accent, modifier = Modifier.size(26.dp))
        }
        Spacer(modifier = Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onBackground)
            Spacer(modifier = Modifier.height(3.dp))
            Text(subtitle, fontSize = 12.sp, lineHeight = 17.sp, color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.64f))
        }
        Icon(Icons.Filled.ChevronRight, contentDescription = "进入", tint = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.45f))
    }
}

@Composable
fun SmallMetric(label: String, value: String, unit: String, isDark: Boolean, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(if (isDark) DarkBg else LightBg)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(value, fontSize = 20.sp, fontWeight = FontWeight.Black, color = if (isDark) NeonCyan else GoldPrimary)
        Text("$label$unit", fontSize = 11.sp, color = if (isDark) TextGray else TextMuted)
    }
}

@Composable
fun ToolsStatsPanel(cards: List<SharedCard>, isDark: Boolean, onBack: () -> Unit) {
    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val accent = if (isDark) NeonCyan else GoldPrimary
            AppBackButton(
                onClick = onBack,
                contentDescription = "返回工具",
                tint = accent,
                containerColor = MaterialTheme.colorScheme.surface,
                borderColor = accent.copy(alpha = 0.34f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text("统计分析", fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }
        AnalyticsPanel(cards = cards, isDark = isDark)
    }
}

@Composable
fun ToolsSyncHistoryPanel(
    isDark: Boolean,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val syncStatus by SyncCoordinator.syncStatus.collectAsState()
    val syncProgress by SyncCoordinator.syncProgress.collectAsState()
    val syncHistory by SyncCoordinator.syncHistory.collectAsState()
    var expandedHistoryIds by remember { mutableStateOf(setOf<String>()) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val accent = if (isDark) NeonCyan else GoldPrimary
            AppBackButton(
                onClick = onBack,
                contentDescription = "返回工具",
                tint = accent,
                containerColor = MaterialTheme.colorScheme.surface,
                borderColor = accent.copy(alpha = 0.34f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text("同步记录", fontSize = 22.sp, fontWeight = FontWeight.Black)
                Text(
                    text = "WebDAV 云端同步记录",
                    fontSize = 12.sp,
                    color = if (isDark) NeonCyan else GoldPrimary,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        DetailSection(title = "📡 当前同步状态与进度") {
            SyncProgressBlock(
                statusMessage = syncStatus.message,
                isSyncing = syncStatus.isSyncing,
                pending = syncStatus.pending,
                phase = syncProgress.phase,
                step = syncProgress.step,
                total = syncProgress.total,
                detail = syncProgress.detail,
                isDark = isDark,
                onCancel = {
                    SyncCoordinator.cancelCurrentSync(context)
                    Toast.makeText(context, "已请求终止当前同步", Toast.LENGTH_SHORT).show()
                },
                onRetry = {
                    coroutineScope.launch {
                        SyncCoordinator.synchronize(context, publishLocalChanges = true)
                    }
                }
            )
        }

        DetailSection(title = "📜 同步历史日志") {
            if (syncHistory.isEmpty()) {
                Text(
                    text = "暂无同步记录。完成一次 WebDAV 同步后，这里会显示上传、下载和卡片变化详情。",
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    color = if (isDark) TextGray else TextMuted
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    syncHistory.forEach { entry ->
                        val expanded = expandedHistoryIds.contains(entry.id)
                        SyncHistoryCard(
                            entry = entry,
                            expanded = expanded,
                            isDark = isDark,
                            onToggle = {
                                expandedHistoryIds = if (expanded) {
                                    expandedHistoryIds - entry.id
                                } else {
                                    expandedHistoryIds + entry.id
                                }
                            }
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}

@Composable
fun VerifyCloudPrefetchPanel(
    seed: Int,
    isDark: Boolean,
    onReady: () -> Unit,
    onCancel: () -> Unit
) {
    val context = LocalContext.current
    var attempt by remember(seed) { mutableIntStateOf(0) }
    var failedMessage by remember(seed) { mutableStateOf<String?>(null) }
    val syncProgress by SyncCoordinator.syncProgress.collectAsState()

    LaunchedEffect(seed, attempt) {
        failedMessage = null
        val config = SyncCoordinator.loadConfig(context)
        if (!config.isEnabled || config.url.isBlank()) {
            kotlinx.coroutines.delay(700)
            onReady()
            return@LaunchedEffect
        }
        SyncCoordinator.synchronize(context, publishLocalChanges = false)
        val status = SyncCoordinator.syncStatus.value
        val failed = status.type == "error" || status.message.contains("失败") || status.message.contains("暂停")
        if (failed) {
            failedMessage = status.message
        } else {
            onReady()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 4.dp)
                .align(Alignment.TopCenter),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val accent = if (isDark) NeonCyan else GoldPrimary
            AppBackButton(
                onClick = onCancel,
                contentDescription = "返回工具",
                tint = accent,
                containerColor = MaterialTheme.colorScheme.surface,
                borderColor = accent.copy(alpha = 0.34f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text("快速验卡", fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }

        Column(
            modifier = Modifier
                .align(Alignment.Center)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            val transition = rememberInfiniteTransition(label = "prefetch")
            val pulse by transition.animateFloat(
                initialValue = 0.72f,
                targetValue = 1.08f,
                animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse),
                label = "pulse"
            )
            Box(modifier = Modifier.size(150.dp), contentAlignment = Alignment.Center) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    drawCircle(
                        color = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.18f),
                        radius = size.minDimension * 0.42f * pulse
                    )
                    drawCircle(
                        color = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.48f),
                        radius = size.minDimension * 0.24f,
                        style = Stroke(width = 4.dp.toPx())
                    )
                }
                Icon(Icons.Filled.CloudSync, contentDescription = "同步云端", modifier = Modifier.size(48.dp), tint = if (isDark) NeonCyan else GoldPrimary)
            }

            Spacer(modifier = Modifier.height(18.dp))
            Text("正在从云端获取最新数据", fontSize = 19.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = failedMessage ?: syncProgress.detail.ifBlank { "确保验卡时使用本机和云端的最新数据" },
                fontSize = 13.sp,
                lineHeight = 18.sp,
                textAlign = TextAlign.Center,
                color = if (failedMessage == null) MaterialTheme.colorScheme.onBackground.copy(alpha = 0.65f) else MaterialTheme.colorScheme.error
            )

            if (failedMessage != null) {
                Spacer(modifier = Modifier.height(20.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedButton(onClick = { attempt += 1 }) {
                        Text("重新获取")
                    }
                    Button(onClick = onReady, colors = ButtonDefaults.buttonColors(containerColor = if (isDark) NeonCyan else GoldPrimary)) {
                        Text("直接进入验卡")
                    }
                }
                TextButton(onClick = onCancel) {
                    Text("取消")
                }
            }
        }
    }
}

enum class VerifyUiState {
    WAITING,
    READING,
    PARSING,
    SUCCESS_EXIST,
    SUCCESS_MISSING,
    ERROR
}

@Composable
fun QuickVerifyPanel(
    cards: List<SharedCard>,
    isDark: Boolean,
    onAddCard: (String, String) -> Unit,
    onFinish: () -> Unit
) {
    val context = LocalContext.current
    val nfcSupported = remember { android.nfc.NfcAdapter.getDefaultAdapter(context) != null }
    val existingNumbers = remember(cards) { cards.map { cleanCardNumber(it.cardNumber) }.filter { it.isNotBlank() }.toSet() }

    var verifiedRecords by remember { mutableStateOf<List<VerifiedCardRecord>>(emptyList()) }
    var addedDuringVerification by remember { mutableStateOf(setOf<String>()) }
    var currentMessage by remember { mutableStateOf("等待 NFC 贴卡") }
    var verifyUiState by remember { mutableStateOf(VerifyUiState.WAITING) }
    var currentScannedNumber by remember { mutableStateOf("") }
    var currentScannedValid by remember { mutableStateOf("") }
    var showMissingDialog by remember { mutableStateOf(false) }
    var showSummaryDialog by remember { mutableStateOf(false) }
    var isNumberVisible by androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        launch {
            NfcScannerManager.nfcCardData.collect { (number, valid) ->
                val cleaned = cleanCardNumber(number)
                if (cleaned.isBlank()) {
                    currentMessage = "没有读取到有效卡号，请重新贴近 NFC 感应区"
                    verifyUiState = VerifyUiState.WAITING
                    return@collect
                }
                currentScannedNumber = cleaned
                currentScannedValid = valid
                
                // 1. 进入“读取完成，正在解析数据”阶段
                verifyUiState = VerifyUiState.PARSING
                currentMessage = "读取完成，正在解析数据....."
                
                // 2. 模拟高保真数据流解析仪式感延迟
                kotlinx.coroutines.delay(1200)
                
                // 3. 真正执行验卡结果评估
                if (verifiedRecords.any { it.cardNumber == cleaned }) {
                    currentMessage = "这张卡刚才已经验过，请继续换卡验证"
                    verifyUiState = VerifyUiState.SUCCESS_EXIST
                    return@collect
                }
                
                val exists = cleaned in existingNumbers
                verifiedRecords = verifiedRecords + VerifiedCardRecord(cleaned, valid, exists)
                
                if (exists) {
                    currentMessage = "解析成功！本地已存在，请继续换卡"
                    verifyUiState = VerifyUiState.SUCCESS_EXIST
                } else {
                    currentMessage = "解析成功！本地未录入这张卡"
                    verifyUiState = VerifyUiState.SUCCESS_MISSING
                    showMissingDialog = true
                }
                
                // 4. 触发智能震动
                try {
                    val vibrator = context.getSystemService(android.content.Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        vibrator?.vibrate(android.os.VibrationEffect.createOneShot(120, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator?.vibrate(120)
                    }
                } catch (e: Exception) {}
            }
        }
        launch {
            NfcScannerManager.nfcReadingState.collect { state ->
                if (state == "READING") {
                    verifyUiState = VerifyUiState.READING
                    currentMessage = "正在读取，请勿移动卡片..."
                }
            }
        }
        launch {
            NfcScannerManager.nfcUnsupportedCard.collect {
                verifyUiState = VerifyUiState.ERROR
                currentMessage = "解析失败，该卡不支持读取"
                
                // 触发错误短震动两次
                try {
                    val vibrator = context.getSystemService(android.content.Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        vibrator?.vibrate(android.os.VibrationEffect.createWaveform(longArrayOf(0, 80, 80, 80), -1))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator?.vibrate(160)
                    }
                } catch (e: Exception) {}
            }
        }
    }

    LaunchedEffect(existingNumbers, verifiedRecords) {
        val newlyAdded = verifiedRecords
            .filter { !it.existedAtScan && it.cardNumber in existingNumbers }
            .map { it.cardNumber }
            .toSet() - addedDuringVerification
        if (newlyAdded.isNotEmpty()) {
            addedDuringVerification = addedDuringVerification + newlyAdded
            currentMessage = "已录入 ${newlyAdded.size} 张刚才未登记的卡，请继续验卡"
        }
    }

    val missingNumbers = verifiedRecords.filter { !it.existedAtScan }.map { it.cardNumber }.toSet()
    val openMissingNumbers = missingNumbers - addedDuringVerification
    val existedCount = verifiedRecords.count { it.existedAtScan }

    if (!nfcSupported) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Filled.Nfc, contentDescription = "不支持 NFC", modifier = Modifier.size(56.dp), tint = MaterialTheme.colorScheme.error)
                Spacer(modifier = Modifier.height(14.dp))
                Text("当前手机不支持 NFC", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(6.dp))
                Text("无法使用快速验卡功能", color = if (isDark) TextGray else TextMuted)
                Spacer(modifier = Modifier.height(18.dp))
                Button(onClick = onFinish) {
                    Text("返回工具")
                }
            }
        }
    } else {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                val accent = if (isDark) NeonCyan else GoldPrimary
                AppBackButton(
                    onClick = onFinish,
                    contentDescription = "返回工具",
                    tint = accent,
                    containerColor = MaterialTheme.colorScheme.surface,
                    borderColor = accent.copy(alpha = 0.34f)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text("快速验卡", fontSize = 22.sp, fontWeight = FontWeight.Black)
                    Text(
                        text = "NFC 模式",
                        fontSize = 12.sp,
                        color = if (isDark) NeonCyan else GoldPrimary,
                        fontWeight = FontWeight.SemiBold
                    )
                }
                OutlinedButton(
                    onClick = { showSummaryDialog = true },
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("结束")
                }
            }

            NfcVerifyHero(
                message = currentMessage,
                isDark = isDark,
                hasReadCard = currentScannedNumber.isNotBlank(),
                uiState = verifyUiState
            )

            DetailSection(title = "🎯 当前验卡结果") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = when (verifyUiState) {
                            VerifyUiState.SUCCESS_MISSING -> Icons.Filled.ReportProblem
                            VerifyUiState.SUCCESS_EXIST -> Icons.Filled.CheckCircle
                            VerifyUiState.ERROR -> Icons.Filled.Cancel
                            else -> Icons.Filled.Nfc
                        },
                        contentDescription = "验卡状态",
                        tint = when (verifyUiState) {
                            VerifyUiState.SUCCESS_MISSING -> if (isDark) NeonRed else WarmOrange
                            VerifyUiState.SUCCESS_EXIST -> if (isDark) NeonGreen else ForestGreen
                            VerifyUiState.ERROR -> if (isDark) NeonRed else Color.Red
                            else -> if (isDark) NeonCyan else GoldPrimary
                        },
                        modifier = Modifier.size(28.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = currentMessage,
                            fontSize = 17.sp,
                            lineHeight = 22.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onBackground
                        )
                        Text(
                            text = "请将下一张卡贴近手机背面 NFC 感应区",
                            fontSize = 12.sp,
                            color = if (isDark) TextGray else TextMuted
                        )
                    }
                }
                if (currentScannedNumber.isNotBlank()) {
                    Spacer(modifier = Modifier.height(12.dp))
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (isDark) DarkBg else LightBg)
                            .padding(12.dp)
                    ) {
                        Text("最近读取卡号", fontSize = 11.sp, color = if (isDark) TextGray else TextMuted)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = if (isNumberVisible) formatSpacingCardNumber(currentScannedNumber) else formatMaskedCardNumber(currentScannedNumber),
                                fontFamily = FontFamily.Monospace,
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (isDark) NeonCyan else GoldPrimary,
                                modifier = Modifier.weight(1f)
                            )
                            IconButton(
                                onClick = { isNumberVisible = !isNumberVisible },
                                modifier = Modifier.size(24.dp)
                            ) {
                                Icon(
                                    imageVector = if (isNumberVisible) Icons.Filled.Visibility else Icons.Filled.VisibilityOff,
                                    contentDescription = "切换卡号防窥",
                                    tint = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.8f),
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                        if (currentScannedValid.isNotBlank()) {
                            Text("有效期：$currentScannedValid", fontSize = 12.sp, color = if (isDark) TextGray else TextMuted)
                        }
                    }
                }
            }

            DetailSection(title = "📈 实时验卡统计") {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                    SmallMetric("已验", "${verifiedRecords.size}", "张", isDark, Modifier.weight(1f))
                    SmallMetric("本地存在", "$existedCount", "张", isDark, Modifier.weight(1f))
                }
                Spacer(modifier = Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                    SmallMetric("未录入", "${openMissingNumbers.size}", "张", isDark, Modifier.weight(1f))
                    SmallMetric("已补录", "${addedDuringVerification.size}", "张", isDark, Modifier.weight(1f))
                }
                if (addedDuringVerification.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(10.dp))
                    Text("本次验卡过程中已补录 ${addedDuringVerification.size} 张", color = if (isDark) NeonGreen else ForestGreen, fontSize = 12.sp)
                }
            }

            if (openMissingNumbers.isNotEmpty()) {
                DetailSection(title = "⚠️ 未录入卡号") {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        openMissingNumbers.forEach { number ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(if (isDark) DarkBg else LightBg)
                                    .padding(horizontal = 12.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Filled.CreditCardOff, contentDescription = "未录入", tint = if (isDark) NeonRed else WarmOrange, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(if (isNumberVisible) formatSpacingCardNumber(number) else formatMaskedCardNumber(number), fontFamily = FontFamily.Monospace, fontSize = 14.sp, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }

    if (showMissingDialog) {
        AlertDialog(
            onDismissRequest = { showMissingDialog = false },
            title = { Text("本地未录入这张卡") },
            text = { Text("卡号 ${if (isNumberVisible) formatSpacingCardNumber(currentScannedNumber) else formatMaskedCardNumber(currentScannedNumber)} 不在本地数据中。可以现在录入，也可以继续验卡。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showMissingDialog = false
                        onAddCard(currentScannedNumber, currentScannedValid)
                    }
                ) {
                    Text("现在录入")
                }
            },
            dismissButton = {
                TextButton(onClick = { showMissingDialog = false }) {
                    Text("继续验卡")
                }
            }
        )
    }

    if (showSummaryDialog) {
        AlertDialog(
            onDismissRequest = { showSummaryDialog = false },
            title = { Text("验卡完成") },
            text = {
                Text(
                    "本次验卡 ${verifiedRecords.size} 张；本地已存在 $existedCount 张；未录入 ${missingNumbers.size} 张；验卡过程中已添加 ${addedDuringVerification.size} 张。"
                )
            },
            confirmButton = {
                TextButton(onClick = onFinish) {
                    Text("完成")
                }
            },
            dismissButton = {
                TextButton(onClick = { showSummaryDialog = false }) {
                    Text("继续验卡")
                }
            }
        )
    }
}

@Composable
fun NfcVerifyHero(
    message: String,
    isDark: Boolean,
    hasReadCard: Boolean,
    uiState: VerifyUiState
) {
    val transition = rememberInfiniteTransition(label = "nfcVerifyHero")
    val isAnimating = uiState == VerifyUiState.WAITING || uiState == VerifyUiState.READING || uiState == VerifyUiState.PARSING
    val duration = when (uiState) {
        VerifyUiState.READING -> 700
        VerifyUiState.PARSING -> 600
        else -> 2200
    }
    
    val pulse by transition.animateFloat(
        initialValue = 0.65f,
        targetValue = 1.12f,
        animationSpec = infiniteRepeatable(
            animation = tween(duration, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "nfcPulse"
    )
    val fade by transition.animateFloat(
        initialValue = 0.25f,
        targetValue = 0.78f,
        animationSpec = infiniteRepeatable(
            animation = tween(duration, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "nfcFade"
    )
    val accent = when (uiState) {
        VerifyUiState.PARSING -> if (isDark) NeonGreen else ForestGreen
        VerifyUiState.SUCCESS_EXIST -> if (isDark) NeonGreen else ForestGreen
        VerifyUiState.SUCCESS_MISSING -> if (isDark) NeonRed else WarmOrange
        VerifyUiState.ERROR -> if (isDark) NeonRed else Color.Red
        else -> if (isDark) NeonCyan else GoldPrimary
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(230.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(
                Brush.radialGradient(
                    colors = listOf(accent.copy(alpha = 0.22f), MaterialTheme.colorScheme.surface),
                    center = Offset.Unspecified,
                    radius = 520f
                )
            )
            .border(1.dp, accent.copy(alpha = 0.28f), RoundedCornerShape(18.dp))
            .padding(18.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            // 包裹同心圆水波纹与真实圆形 Icon 的绝对对中大 Box
            Box(
                modifier = Modifier.size(200.dp),
                contentAlignment = Alignment.Center
            ) {
                // A. 动态水波纹外环
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val center = Offset(size.width / 2, size.height / 2)
                    val finalAlpha = if (isAnimating) fade else 0f
                    val finalPulse = if (isAnimating) pulse else 1f
                    if (finalAlpha > 0f) {
                        drawCircle(
                            color = accent.copy(alpha = 0.16f * finalAlpha),
                            radius = 95.dp.toPx() * finalPulse,
                            center = center,
                            style = Stroke(width = 3.dp.toPx())
                        )
                        drawCircle(
                            color = accent.copy(alpha = 0.22f * finalAlpha),
                            radius = 68.dp.toPx() * finalPulse,
                            center = center,
                            style = Stroke(width = 2.dp.toPx())
                        )
                    }
                    drawCircle(
                        color = accent.copy(alpha = 0.12f),
                        radius = 46.dp.toPx(),
                        center = center
                    )
                }

                // B. 核心真实中央圆形卡片图标
                Box(
                    modifier = Modifier
                        .size(88.dp)
                        .clip(CircleShape)
                        .background(accent.copy(alpha = if (uiState != VerifyUiState.WAITING) 0.28f else 0.18f))
                        .border(2.dp, accent.copy(alpha = 0.55f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    when (uiState) {
                        VerifyUiState.READING -> {
                            CircularProgressIndicator(
                                strokeWidth = 3.dp,
                                color = accent,
                                modifier = Modifier.size(42.dp)
                            )
                        }
                        VerifyUiState.PARSING -> {
                            CircularProgressIndicator(
                                strokeWidth = 3.dp,
                                color = accent,
                                modifier = Modifier.size(42.dp)
                            )
                        }
                        VerifyUiState.SUCCESS_EXIST, VerifyUiState.SUCCESS_MISSING -> {
                            Icon(
                                imageVector = Icons.Filled.Check,
                                contentDescription = "成功",
                                tint = accent,
                                modifier = Modifier.size(42.dp)
                            )
                        }
                        VerifyUiState.ERROR -> {
                            Icon(
                                imageVector = Icons.Filled.Close,
                                contentDescription = "失败",
                                tint = accent,
                                modifier = Modifier.size(42.dp)
                            )
                        }
                        else -> {
                            Icon(
                                imageVector = if (hasReadCard) Icons.Filled.CreditCard else Icons.Filled.Nfc,
                                contentDescription = "NFC 验卡",
                                tint = accent,
                                modifier = Modifier.size(42.dp)
                            )
                        }
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = message,
                fontSize = 19.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.Black,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onBackground
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "仅使用真实 NFC 读取结果，不再启用相机验卡",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.62f),
                textAlign = TextAlign.Center
            )
        }
    }
}

private fun cleanCardNumber(value: String): String = value.filter { it.isDigit() }

// =============================================================================
// 📊 Tab 1 子组件: 共享额度去重新算法、手绘Donut环形图、年费扣缴雷达与折叠看板
// =============================================================================

/**
 * 资产分析面板，手绘 Canvas 环形图和预警雷达
 */
@Composable
fun AnalyticsPanel(cards: List<SharedCard>, isDark: Boolean) {
    if (cards.isEmpty()) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(text = "暂无卡片数据，无法进行财务统计分析", color = if (isDark) TextGray else TextMuted, fontSize = 14.sp)
        }
        return
    }

    // A. 重构多币种总资产额度算法 - 完美实现共享限额去重 (第 5 点)
    val currencySummary = remember(cards) {
        cards.groupBy { it.type }.mapValues { entry ->
            val cardList = entry.value
            
            // 1. 过滤出非共享额度的卡片，无条件直接求和
            val nonSharedSum = cardList.filter { !it.isSharedLimit }.sumOf { it.limit }
            
            // 2. 过滤出共享额度的卡片，按 bank 银行分组，每个银行共享组只取额度最大值
            val sharedSum = cardList.filter { it.isSharedLimit && it.bank.isNotEmpty() }
                .groupBy { it.bank }
                .map { bankGroup -> bankGroup.value.maxOfOrNull { it.limit } ?: 0.0 }
                .sum()
                
            val totalLimit = nonSharedSum + sharedSum
            val annualFeeSum = cardList.sumOf { it.annualFee }
            val cardCount = cardList.size
            Triple(totalLimit, annualFeeSum, cardCount)
        }
    }

    // B. 年费距离扣缴不足 60 天且未达标卡片警示列表
    val feeAlerts = remember(cards) {
        val now = System.currentTimeMillis()
        val limitTime = now + 60L * 24 * 3600 * 1000 // 60天
        cards.filter { card ->
            card.isQualified == "2" && // 未达标
            card.nextAnnualFeeCollectionTime != null &&
            card.nextAnnualFeeCollectionTime!! in now..limitTime
        }.sortedBy { it.nextAnnualFeeCollectionTime }
    }

    // C. 共享额度组看板数据
    val sharedLimitGroups = remember(cards) {
        cards.filter { it.isSharedLimit && it.bank.isNotEmpty() }
            .groupBy { it.bank }
            .filter { it.value.size > 1 }
    }

    // D. 共享额度组折叠状态控制 (第 6 点)
    var expandedGroups by remember { mutableStateOf(setOf<String>()) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Spacer(modifier = Modifier.height(6.dp))

        // 1. Canvas 手工绘制的拟真资产额度占比 Donut 环形图 (按去重额度比例展示)
        DetailSection(title = "📊 信用额度占比图") {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 左侧环形图
                Box(
                    modifier = Modifier
                        .size(130.dp)
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    Canvas(modifier = Modifier.size(110.dp)) {
                        val stroke = Stroke(width = 14.dp.toPx())
                        var startAngle = -90f
                        
                        // 使用去重共享后的总信用额度比例
                        val totalLimit = currencySummary.values.sumOf { it.first }

                        if (totalLimit <= 0) {
                            drawArc(
                                color = Color.Gray.copy(alpha = 0.2f),
                                startAngle = 0f,
                                sweepAngle = 360f,
                                useCenter = false,
                                style = stroke
                            )
                        } else {
                            val colors = listOf(NeonCyan, NeonPurple, NeonGreen, Color(0xFFFF9100), NeonRed, GoldPrimary, NavySecondary)
                            var colorIndex = 0
                            currencySummary.forEach { (currency, triple) ->
                                val limit = triple.first
                                val sweepAngle = ((limit / totalLimit) * 360f).toFloat()
                                drawArc(
                                    color = colors[colorIndex % colors.size],
                                    startAngle = startAngle,
                                    sweepAngle = sweepAngle,
                                    useCenter = false,
                                    style = stroke
                                )
                                startAngle += sweepAngle
                                colorIndex++
                            }
                        }
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(text = "币种归集", fontSize = 10.sp, color = if (isDark) TextGray else TextMuted)
                        Text(text = "${currencySummary.size} 种", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    }
                }

                // 右侧图例列表
                Column(
                    modifier = Modifier
                        .weight(1.2f)
                        .padding(start = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    val colors = listOf(NeonCyan, NeonPurple, NeonGreen, Color(0xFFFF9100), NeonRed, GoldPrimary, NavySecondary)
                    var colorIndex = 0
                    currencySummary.forEach { (currency, triple) ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .clip(CircleShape)
                                    .background(colors[colorIndex % colors.size])
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "$currency 信用总额",
                                fontSize = 11.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                        }
                        colorIndex++
                    }
                }
            }
        }

        // 2. 年费到达预警橙红色警报雷达
        if (feeAlerts.isNotEmpty()) {
            DetailSection(title = "🚨 年费扣缴雷达警报") {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    feeAlerts.forEach { card ->
                        val daysLeft = ((card.nextAnnualFeeCollectionTime!! - System.currentTimeMillis()) / (24 * 3600 * 1000L)).coerceAtLeast(0)
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(if (daysLeft < 30) NeonRed.copy(alpha = 0.15f) else Color(0xFFFF9100).copy(alpha = 0.15f))
                                .padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "${card.bank} (${card.alias})",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.sp,
                                    color = if (daysLeft < 30) NeonRed else Color(0xFFFF9100)
                                )
                                Text(
                                    text = "年费: ${card.type} $${card.annualFee} | 状态: 未达标",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.8f)
                                )
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text(
                                    text = "剩 $daysLeft 天",
                                    fontWeight = FontWeight.Black,
                                    fontSize = 14.sp,
                                    color = if (daysLeft < 30) NeonRed else Color(0xFFFF9100)
                                )
                                Text(
                                    text = "到期扣收",
                                    fontSize = 9.sp,
                                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f)
                                )
                            }
                        }
                    }
                }
            }
        }

        // 3. 共享额度组看版 - 精美折叠支持，收放自如 (第 6 点)
        if (sharedLimitGroups.isNotEmpty()) {
            DetailSection(title = "🤝 共享额度组看版 (点击行展开)") {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    sharedLimitGroups.forEach { (bank, groupCards) ->
                        val representative = groupCards.first()
                        val isExpanded = expandedGroups.contains(bank)
                        
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(if (isDark) DarkBg else LightBg)
                                .clickable {
                                    expandedGroups = if (isExpanded) expandedGroups - bank else expandedGroups + bank
                                }
                                .padding(12.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Text(
                                        text = "🏢 $bank",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 13.sp,
                                        maxLines = 2,
                                        overflow = TextOverflow.Ellipsis,
                                        modifier = Modifier.weight(1f, fill = false)
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(4.dp))
                                            .background((if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.2f))
                                            .padding(horizontal = 4.dp, vertical = 2.dp)
                                    ) {
                                        Text(
                                            text = "${groupCards.size}张卡共享",
                                            fontSize = 9.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            color = if (isDark) NeonCyan else GoldPrimary
                                        )
                                    }
                                }
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(start = 8.dp)
                                ) {
                                    Text(
                                        text = "${representative.type} $${String.format("%,.0f", representative.limit)}",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 12.sp,
                                        color = if (isDark) NeonCyan else GoldPrimary,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Icon(
                                        imageVector = if (isExpanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                                        contentDescription = "展开折叠",
                                        tint = if (isDark) TextGray else TextMuted,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            }
                            
                            // 平滑折叠动画区域
                            AnimatedVisibility(
                                visible = isExpanded,
                                enter = expandVertically() + fadeIn(),
                                exit = shrinkVertically() + fadeOut()
                            ) {
                                Column(modifier = Modifier.padding(top = 8.dp)) {
                                    Divider(
                                        color = (if (isDark) TextGray else TextMuted).copy(alpha = 0.15f),
                                        thickness = 1.dp,
                                        modifier = Modifier.padding(vertical = 6.dp)
                                    )
                                    groupCards.forEach { card ->
                                        Row(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .padding(vertical = 3.dp),
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Text(
                                                text = "• ${card.alias.ifEmpty { "卡片" }} (${formatMaskedCardNumber(card.cardNumber).takeLast(4)})",
                                                fontSize = 11.sp,
                                                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.8f),
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis,
                                                modifier = Modifier.weight(1f)
                                            )
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text(
                                                text = "共享锁定中",
                                                color = if (isDark) NeonGreen else ForestGreen,
                                                fontSize = 10.sp,
                                                fontWeight = FontWeight.SemiBold
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // 4. 多币种信用资产看板 (已应用共享去重算法，100%精准财务资产)
        DetailSection(title = "💳 多币种真实总信用资产") {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                currencySummary.forEach { (currency, triple) ->
                    val (totalLimit, totalFee, cardCount) = triple
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (isDark) DarkBg else LightBg)
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(text = "🪙 币种: $currency", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Text(
                                text = "共绑定 $cardCount 张卡片，已去除共享额度重复计算",
                                fontSize = 11.sp,
                                color = if (isDark) TextGray else TextMuted,
                                lineHeight = 15.sp
                            )
                        }
                        Spacer(modifier = Modifier.width(10.dp))
                        Column(
                            horizontalAlignment = Alignment.End,
                            modifier = Modifier.weight(0.9f)
                        ) {
                            Text(
                                text = "$currency $${String.format("%,.0f", totalLimit)}",
                                fontWeight = FontWeight.Black,
                                fontSize = 15.sp,
                                color = if (isDark) NeonCyan else GoldPrimary,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis,
                                textAlign = TextAlign.End
                            )
                            Text(
                                text = "总年费: $currency ${String.format("%,.0f", totalFee)}",
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                textAlign = TextAlign.End
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(30.dp))
    }
}

// =============================================================================
// ⚙️ Tab 2 子组件: WebDAV 配置大盾牌已连接折叠卡片与系统高级运维
// =============================================================================

private enum class SettingsMode {
    MAIN,
    WEBDAV,
    HELP,
    ABOUT,
    PRIVACY,
    STORAGE
}

@Composable
private fun SettingsPanel(
    isDark: Boolean,
    settingsMode: SettingsMode,
    onSettingsModeChange: (SettingsMode) -> Unit
) {
    when (settingsMode) {
        SettingsMode.MAIN -> {
            SettingsMainPanel(
                isDark = isDark,
                onOpenWebDAV = { onSettingsModeChange(SettingsMode.WEBDAV) },
                onOpenHelp = { onSettingsModeChange(SettingsMode.HELP) },
                onOpenAbout = { onSettingsModeChange(SettingsMode.ABOUT) },
                onOpenPrivacy = { onSettingsModeChange(SettingsMode.PRIVACY) },
                onOpenStorage = { onSettingsModeChange(SettingsMode.STORAGE) }
            )
        }
        SettingsMode.WEBDAV -> {
            SettingsWebDAVPanel(
                isDark = isDark,
                onBack = { onSettingsModeChange(SettingsMode.MAIN) }
            )
        }
        SettingsMode.HELP -> {
            SettingsHelpPanel(
                isDark = isDark,
                onBack = { onSettingsModeChange(SettingsMode.MAIN) }
            )
        }
        SettingsMode.ABOUT -> {
            SettingsAboutPanel(
                isDark = isDark,
                onBack = { onSettingsModeChange(SettingsMode.MAIN) }
            )
        }
        SettingsMode.PRIVACY -> {
            SettingsPrivacyPanel(
                isDark = isDark,
                onBack = { onSettingsModeChange(SettingsMode.MAIN) }
            )
        }
        SettingsMode.STORAGE -> {
            SettingsStoragePanel(
                isDark = isDark,
                onBack = { onSettingsModeChange(SettingsMode.MAIN) }
            )
        }
    }
}

@Composable
fun SettingsMainPanel(
    isDark: Boolean,
    onOpenWebDAV: () -> Unit,
    onOpenHelp: () -> Unit,
    onOpenAbout: () -> Unit,
    onOpenPrivacy: () -> Unit,
    onOpenStorage: () -> Unit
) {
    val context = LocalContext.current
    val loadedConfig = remember { SyncCoordinator.loadConfig(context) }
    val isConfigured = remember(loadedConfig) { loadedConfig.url.isNotEmpty() && loadedConfig.user.isNotEmpty() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            text = "设置",
            fontSize = 26.sp,
            fontWeight = FontWeight.Black,
            color = MaterialTheme.colorScheme.onBackground
        )
        Text(
            text = "管理云备份连接参数、偏好设置与敏感数据重设。",
            fontSize = 13.sp,
            color = if (isDark) TextGray else TextMuted
        )

        // 1. WebDAV 云备份二级菜单入口卡片
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(MaterialTheme.colorScheme.surface)
                .border(
                    width = 1.dp,
                    color = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.22f),
                    shape = RoundedCornerShape(14.dp)
                )
                .clickable { onOpenWebDAV() }
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background((if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.16f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.CloudQueue,
                    contentDescription = "WebDAV云备份",
                    tint = if (isDark) NeonCyan else GoldPrimary,
                    modifier = Modifier.size(26.dp)
                )
            }
            Spacer(modifier = Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "WebDAV 云备份设置",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onBackground
                )
                Spacer(modifier = Modifier.height(3.dp))
                Text(
                    text = if (isConfigured) "服务正常连接，云端同步已开启" else "未配置，点击开启云端备份与数据恢复",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.64f)
                )
            }
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = "进入 WebDAV 设置",
                tint = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.45f)
            )
        }

        // 2. 个性外观 Section
        DetailSection(title = "🎨 个性外观") {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (isDark) DarkBg else LightBg)
                    .clickable { ThemeManager.toggleTheme(context) }
                    .padding(horizontal = 14.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector = if (isDark) Icons.Filled.LightMode else Icons.Filled.NightlightRound,
                        contentDescription = "外观主题",
                        tint = if (isDark) NeonCyan else GoldPrimary,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = "外观主题",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }
                Text(
                    text = if (isDark) "深色模式" else "浅色模式",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isDark) NeonCyan else GoldPrimary
                )
            }
        }

        // 🌟 使用帮助与关于我们 Section
        DetailSection(title = "📖 帮助与支持") {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (isDark) DarkBg else LightBg)
                    .padding(vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                // 1. 使用帮助
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpenHelp() }
                        .padding(horizontal = 14.dp, vertical = 14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Filled.HelpOutline,
                            contentDescription = "使用帮助",
                            tint = if (isDark) NeonCyan else GoldPrimary,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = "使用帮助",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                    }
                    Icon(
                        imageVector = Icons.Filled.ChevronRight,
                        contentDescription = "进入使用帮助",
                        tint = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.4f),
                        modifier = Modifier.size(16.dp)
                    )
                }

                // 分割线，纯 Box 渲染防 API 冲突
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp)
                        .height(0.5.dp)
                        .background((if (isDark) TextGray else TextMuted).copy(alpha = 0.12f))
                )

                // 2. 关于软件
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpenAbout() }
                        .padding(horizontal = 14.dp, vertical = 14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Filled.Info,
                            contentDescription = "关于软件",
                            tint = if (isDark) NeonCyan else GoldPrimary,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = "关于软件",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                    }
                    Icon(
                        imageVector = Icons.Filled.ChevronRight,
                        contentDescription = "进入关于",
                        tint = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.4f),
                        modifier = Modifier.size(16.dp)
                    )
                }

                // 分割线，纯 Box 渲染防 API 冲突
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp)
                        .height(0.5.dp)
                        .background((if (isDark) TextGray else TextMuted).copy(alpha = 0.12f))
                )

                // 3. 隐私管理
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpenPrivacy() }
                        .padding(horizontal = 14.dp, vertical = 14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Filled.Security,
                            contentDescription = "隐私管理",
                            tint = if (isDark) NeonCyan else GoldPrimary,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = "隐私权限管理",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                    }
                    Icon(
                        imageVector = Icons.Filled.ChevronRight,
                        contentDescription = "进入隐私管理",
                        tint = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.4f),
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }

        DetailSection(title = "存储与重置") {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (isDark) DarkBg else LightBg)
                    .clickable { onOpenStorage() }
                    .padding(horizontal = 14.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector = Icons.Filled.Storage,
                        contentDescription = "存储管理",
                        tint = if (isDark) NeonCyan else GoldPrimary,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(
                            text = "存储管理",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                        Text(
                            text = "查看数据占用明细，或一键恢复初始状态",
                            fontSize = 11.sp,
                            color = if (isDark) TextGray else TextMuted,
                            lineHeight = 15.sp
                        )
                    }
                }
                Icon(
                    imageVector = Icons.Filled.ChevronRight,
                    contentDescription = "进入存储管理",
                    tint = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.4f),
                    modifier = Modifier.size(16.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(40.dp))
    }
}

@Composable
fun SettingsStoragePanel(
    isDark: Boolean,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var refreshSeed by remember { mutableIntStateOf(0) }
    var snapshot by remember { mutableStateOf<AppStorageSnapshot?>(null) }
    var showResetDialog by remember { mutableStateOf(false) }
    var isResetting by remember { mutableStateOf(false) }

    LaunchedEffect(refreshSeed) {
        snapshot = withContext(Dispatchers.IO) {
            AppStorageManager.inspect(context)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(if (isDark) DarkBg else LightBg)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val accent = if (isDark) NeonCyan else GoldPrimary
            AppBackButton(
                onClick = onBack,
                contentDescription = "返回设置",
                tint = accent,
                containerColor = MaterialTheme.colorScheme.surface,
                borderColor = accent.copy(alpha = 0.34f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "存储管理",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Black,
                    color = if (isDark) TextWhite else TextDark
                )
                Text(
                    text = "查看本机数据占用与重置应用",
                    fontSize = 12.sp,
                    color = if (isDark) NeonCyan else GoldPrimary,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                val current = snapshot
                if (current == null) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(160.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            color = if (isDark) NeonCyan else GoldPrimary
                        )
                    }
                } else {
                    StorageTotalCard(snapshot = current, isDark = isDark)
                }
            }

            snapshot?.let { current ->
                item {
                    DetailSection(title = "占用明细") {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(if (isDark) DarkCardBg else LightCardBg)
                                .padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            StorageUsageRow(
                                icon = Icons.Filled.Dataset,
                                title = "本地数据库",
                                description = "卡片资料、同步账本以及内嵌图片的实际数据库文件",
                                bytes = current.databaseBytes,
                                totalBytes = current.totalBytes,
                                isDark = isDark
                            )
                            StorageUsageRow(
                                icon = Icons.Filled.Image,
                                title = "卡片图片数据",
                                description = "${current.imageCount} 张图片，当前版本以内嵌方式保存在数据库中",
                                bytes = current.inlineImageBytes,
                                totalBytes = current.totalBytes,
                                isDark = isDark
                            )
                            StorageUsageRow(
                                icon = Icons.Filled.PhotoLibrary,
                                title = "旧版扫描图片",
                                description = "历史版本保存在私有目录的扫描裁剪图",
                                bytes = current.legacyImageBytes,
                                totalBytes = current.totalBytes,
                                isDark = isDark
                            )
                            StorageUsageRow(
                                icon = Icons.Filled.SettingsApplications,
                                title = "偏好与云同步配置",
                                description = "主题、工具菜单、WebDAV 配置及同步状态",
                                bytes = current.preferenceBytes,
                                totalBytes = current.totalBytes,
                                isDark = isDark
                            )
                            StorageUsageRow(
                                icon = Icons.Filled.Cached,
                                title = "临时缓存",
                                description = "扫描、图片处理和系统运行产生的临时文件",
                                bytes = current.cacheBytes,
                                totalBytes = current.totalBytes,
                                isDark = isDark
                            )
                            StorageUsageRow(
                                icon = Icons.Filled.Folder,
                                title = "其他私有文件",
                                description = "应用沙盒中除旧版扫描图片以外的私有文件",
                                bytes = current.privateFileBytes,
                                totalBytes = current.totalBytes,
                                isDark = isDark
                            )
                            StorageUsageRow(
                                icon = Icons.Filled.MoreHoriz,
                                title = "系统管理数据",
                                description = "系统为应用维护的目录、锁文件或运行残留",
                                bytes = current.otherBytes,
                                totalBytes = current.totalBytes,
                                isDark = isDark
                            )
                            Text(
                                text = "总占用按应用私有沙盒实际大小统计。卡片图片数据已包含在数据库文件中，仅用于说明图片本身的占用规模。",
                                fontSize = 10.sp,
                                lineHeight = 15.sp,
                                color = if (isDark) TextGray else TextMuted
                            )
                        }
                    }
                }
            }

            item {
                DetailSection(title = "一键重置") {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (isDark) DarkCardBg else LightCardBg)
                            .padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = "重置会清除本机卡片、卡片图片、同步账本、WebDAV 配置、主题偏好、工具菜单设置和临时缓存，恢复到首次安装后的本地初始状态。云端备份文件不会被删除。",
                            fontSize = 11.sp,
                            lineHeight = 17.sp,
                            color = (if (isDark) NeonRed else Color.Red).copy(alpha = 0.82f)
                        )
                        Button(
                            onClick = { showResetDialog = true },
                            enabled = !isResetting,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = (if (isDark) NeonRed else Color.Red).copy(alpha = 0.12f),
                                contentColor = if (isDark) NeonRed else Color.Red,
                                disabledContainerColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.12f),
                                disabledContentColor = if (isDark) TextGray else TextMuted
                            ),
                            border = BorderStroke(1.dp, (if (isDark) NeonRed else Color.Red).copy(alpha = 0.38f)),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Filled.DeleteForever,
                                contentDescription = "重置应用",
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = if (isResetting) "正在重置..." else "一键重置 App",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }

            item {
                Spacer(modifier = Modifier.height(20.dp))
            }
        }
    }

    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { if (!isResetting) showResetDialog = false },
            title = {
                Text(
                    text = "确认重置 App？",
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    color = if (isDark) NeonRed else Color.Red
                )
            },
            text = {
                Text(
                    text = "此操作会清除当前设备上的全部本地数据与配置，完成后会回到初始空白状态，无法在本机撤销。",
                    fontSize = 13.sp,
                    lineHeight = 19.sp
                )
            },
            confirmButton = {
                TextButton(
                    enabled = !isResetting,
                    onClick = {
                        showResetDialog = false
                        coroutineScope.launch {
                            isResetting = true
                            try {
                                AppStorageManager.resetApplicationData(context)
                                ThemeManager.resetToDefault(context)
                                SyncCoordinator.initLocalData(context)
                                refreshSeed += 1
                                Toast.makeText(context, "App 已重置为初始状态", Toast.LENGTH_LONG).show()
                            } catch (e: Exception) {
                                Toast.makeText(context, "重置失败：${e.message ?: "未知错误"}", Toast.LENGTH_LONG).show()
                            } finally {
                                isResetting = false
                            }
                        }
                    }
                ) {
                    Text("确认重置", color = if (isDark) NeonRed else Color.Red, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(
                    enabled = !isResetting,
                    onClick = { showResetDialog = false }
                ) {
                    Text("取消", color = if (isDark) TextGray else TextMuted)
                }
            }
        )
    }
}

@Composable
fun StorageTotalCard(
    snapshot: AppStorageSnapshot,
    isDark: Boolean
) {
    val accent = if (isDark) NeonCyan else GoldPrimary
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, accent.copy(alpha = 0.2f), RoundedCornerShape(14.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(accent.copy(alpha = 0.14f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Storage,
                    contentDescription = "总占用",
                    tint = accent,
                    modifier = Modifier.size(24.dp)
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "本机应用数据",
                    fontSize = 13.sp,
                    color = if (isDark) TextGray else TextMuted
                )
                Text(
                    text = formatStorageBytes(snapshot.totalBytes),
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Black,
                    color = if (isDark) TextWhite else TextDark
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            StorageMetricChip("卡片 ${snapshot.cardCount}", isDark)
            StorageMetricChip("图片 ${snapshot.imageCount}", isDark)
        }
    }
}

@Composable
fun StorageMetricChip(
    text: String,
    isDark: Boolean
) {
    val accent = if (isDark) NeonCyan else GoldPrimary
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(30.dp))
            .background(accent.copy(alpha = 0.1f))
            .border(0.5.dp, accent.copy(alpha = 0.32f), RoundedCornerShape(30.dp))
            .padding(horizontal = 10.dp, vertical = 5.dp)
    ) {
        Text(
            text = text,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = accent
        )
    }
}

@Composable
fun StorageUsageRow(
    icon: ImageVector,
    title: String,
    description: String,
    bytes: Long,
    totalBytes: Long,
    isDark: Boolean
) {
    val accent = if (isDark) NeonCyan else GoldPrimary
    val progress = if (totalBytes <= 0L) 0f else (bytes.toFloat() / totalBytes.toFloat()).coerceIn(0f, 1f)
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = icon,
                contentDescription = title,
                tint = accent,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = title,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (isDark) TextWhite else TextDark,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        text = formatStorageBytes(bytes),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = accent
                    )
                }
                Text(
                    text = description,
                    fontSize = 10.sp,
                    lineHeight = 14.sp,
                    color = if (isDark) TextGray else TextMuted
                )
            }
        }
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier
                .fillMaxWidth()
                .height(5.dp)
                .clip(RoundedCornerShape(4.dp)),
            color = accent,
            trackColor = accent.copy(alpha = 0.14f)
        )
    }
}

private fun formatStorageBytes(bytes: Long): String {
    if (bytes <= 0L) return "0 B"
    val units = listOf("B", "KB", "MB", "GB")
    var value = bytes.toDouble()
    var unitIndex = 0
    while (value >= 1024.0 && unitIndex < units.lastIndex) {
        value /= 1024.0
        unitIndex += 1
    }
    return if (unitIndex == 0) {
        "${bytes} ${units[unitIndex]}"
    } else {
        String.format(java.util.Locale.US, "%.1f %s", value, units[unitIndex])
    }
}

@Composable
fun SettingsWebDAVPanel(
    isDark: Boolean,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    // 1. 加载云同步参数
    val loadedConfig = remember { SyncCoordinator.loadConfig(context) }
    var url by remember { mutableStateOf(loadedConfig.url) }
    var user by remember { mutableStateOf(loadedConfig.user) }
    var pass by remember { mutableStateOf(loadedConfig.pass) }
    var isEnabled by remember { mutableStateOf(loadedConfig.isEnabled) }

    // 2. 状态监听
    var isTestingConnection by remember { mutableStateOf(false) }
    val syncStatus by SyncCoordinator.syncStatus.collectAsState()

    // 3. 配置模式控制
    val isConfigured = remember(loadedConfig) { loadedConfig.url.isNotEmpty() && loadedConfig.user.isNotEmpty() }
    var isEditingConfig by remember { mutableStateOf(!isConfigured) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val accent = if (isDark) NeonCyan else GoldPrimary
            AppBackButton(
                onClick = onBack,
                contentDescription = "返回设置",
                tint = accent,
                containerColor = MaterialTheme.colorScheme.surface,
                borderColor = accent.copy(alpha = 0.34f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text("WebDAV 设置", fontSize = 22.sp, fontWeight = FontWeight.Black)
                Text(
                    text = "WebDAV 云备份参数与状态",
                    fontSize = 12.sp,
                    color = if (isDark) NeonCyan else GoldPrimary,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        if (isConfigured && !isEditingConfig) {
            DetailSection(title = "🛡️ 云端防护已连接") {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (isDark) DarkBg else LightBg)
                        .padding(14.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Filled.CloudDone,
                        contentDescription = "云同步已连接",
                        tint = if (isDark) NeonGreen else ForestGreen,
                        modifier = Modifier.size(52.dp)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "WebDAV 云备份通道正常连接",
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        color = if (isDark) NeonGreen else ForestGreen,
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "同步云盘：${url.substringAfter("://").substringBefore("/")}\n同步账号：$user\n本机和云端会自动保持最新",
                        fontSize = 11.sp,
                        lineHeight = 15.sp,
                        textAlign = TextAlign.Center,
                        color = (if (isDark) TextGray else TextMuted).copy(alpha = 0.8f)
                    )
                    Spacer(modifier = Modifier.height(14.dp))
                    
                    // 双向自动同步开关
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text("开启双向自动同步", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Text("改动卡片时自动在后台执行静默同步备份", fontSize = 10.sp, color = if (isDark) TextGray else TextMuted)
                        }
                        Switch(
                            checked = isEnabled,
                            onCheckedChange = { 
                                isEnabled = it 
                                val newConfig = WebDAVConfig(url.trim(), user.trim(), pass.trim(), it)
                                SyncCoordinator.saveConfig(context, newConfig)
                                Toast.makeText(context, "自动同步状态已成功更新", Toast.LENGTH_SHORT).show()
                            },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = if (isDark) NeonCyan else GoldPrimary,
                                checkedTrackColor = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.3f)
                            )
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))
                    HorizontalDivider(color = (if (isDark) TextGray else TextMuted).copy(alpha = 0.15f), thickness = 1.dp)
                    Spacer(modifier = Modifier.height(12.dp))

                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Button(
                            onClick = {
                                coroutineScope.launch {
                                    SyncCoordinator.synchronize(context, publishLocalChanges = true)
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !syncStatus.isSyncing,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (isDark) NeonCyan else GoldPrimary,
                                contentColor = if (isDark) DarkBg else Color.White
                            )
                        ) {
                            if (syncStatus.isSyncing) {
                                CircularProgressIndicator(modifier = Modifier.size(14.dp), color = if (isDark) DarkBg else Color.White, strokeWidth = 2.dp)
                            } else {
                                Icon(imageVector = Icons.Filled.CloudSync, contentDescription = "立即同步", modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("立即同步", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        }

                        if (syncStatus.isSyncing) {
                            Button(
                                onClick = {
                                    SyncCoordinator.cancelCurrentSync(context)
                                    Toast.makeText(context, "已请求终止当前同步", Toast.LENGTH_SHORT).show()
                                },
                                modifier = Modifier.fillMaxWidth(),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = (if (isDark) NeonRed else Color(0xFFD32F2F)).copy(alpha = 0.92f),
                                    contentColor = Color.White
                                )
                            ) {
                                Icon(imageVector = Icons.Filled.Cancel, contentDescription = "终止同步", modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("终止当前同步", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        }

                        Button(
                            onClick = { isEditingConfig = true },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.2f),
                                contentColor = MaterialTheme.colorScheme.onBackground
                            )
                        ) {
                            Icon(imageVector = Icons.Filled.Edit, contentDescription = "修改配置", modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("修改云配置", fontSize = 11.sp)
                        }
                    }
                }
            }
        } else {
            DetailSection(title = "⚙️ 配置 WebDAV 服务器参数") {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(
                        value = url,
                        onValueChange = { url = it },
                        label = { Text("WebDAV 服务器 URL (带 https://)") },
                        placeholder = { Text("https://dav.jianguoyun.com/dav") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        colors = getOutlinedTextFieldColors(isDark)
                    )

                    OutlinedTextField(
                        value = user,
                        onValueChange = { user = it },
                        label = { Text("用户名 (Email 账号)") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        colors = getOutlinedTextFieldColors(isDark)
                    )

                    OutlinedTextField(
                        value = pass,
                        onValueChange = { pass = it },
                        label = { Text("应用独立安全密码") },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth(),
                        colors = getOutlinedTextFieldColors(isDark)
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text("开启双向自动同步", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Text("改动卡片时自动在后台同步", fontSize = 10.sp, color = if (isDark) TextGray else TextMuted)
                        }
                        Switch(
                            checked = isEnabled,
                            onCheckedChange = { isEnabled = it },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = if (isDark) NeonCyan else GoldPrimary,
                                checkedTrackColor = (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.3f)
                            )
                        )
                    }

                    Spacer(modifier = Modifier.height(4.dp))
                    HorizontalDivider(color = (if (isDark) TextGray else TextMuted).copy(alpha = 0.15f), thickness = 1.dp)
                    Spacer(modifier = Modifier.height(4.dp))

                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Button(
                            onClick = {
                                if (url.trim().isEmpty() || user.trim().isEmpty() || pass.trim().isEmpty()) {
                                    Toast.makeText(context, "请先填齐所有 WebDAV 配置参数", Toast.LENGTH_SHORT).show()
                                    return@Button
                                }
                                isTestingConnection = true
                                coroutineScope.launch(Dispatchers.IO) {
                                    val (success, message) = WebDAVClient.testConnection(url, user, pass)
                                    withContext(Dispatchers.Main) {
                                        isTestingConnection = false
                                        Toast.makeText(context, "测试结果: $message", Toast.LENGTH_LONG).show()
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !isTestingConnection && !syncStatus.isSyncing,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (isDark) NeonCyan else GoldPrimary,
                                contentColor = if (isDark) DarkBg else Color.White
                            )
                        ) {
                            if (isTestingConnection) {
                                CircularProgressIndicator(modifier = Modifier.size(14.dp), color = if (isDark) DarkBg else Color.White, strokeWidth = 2.dp)
                            } else {
                                Icon(imageVector = Icons.Filled.NetworkCheck, contentDescription = "测试", modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("测试", fontSize = 11.sp)
                            }
                        }

                        Button(
                            onClick = {
                                if (isEnabled && (url.trim().isEmpty() || user.trim().isEmpty() || pass.trim().isEmpty())) {
                                    Toast.makeText(context, "开启同步时，必须填齐所有云参数", Toast.LENGTH_SHORT).show()
                                    return@Button
                                }
                                
                                val newConfig = WebDAVConfig(url.trim(), user.trim(), pass.trim(), isEnabled)
                                SyncCoordinator.saveConfig(context, newConfig)
                                Toast.makeText(context, "配置已保存，网络通道畅通", Toast.LENGTH_SHORT).show()
                                isEditingConfig = false
                                
                                if (isEnabled) {
                                    coroutineScope.launch {
                                        SyncCoordinator.synchronize(context, publishLocalChanges = false)
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !syncStatus.isSyncing,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (isDark) NeonGreen else ForestGreen,
                                contentColor = Color.White
                            )
                        ) {
                            Icon(imageVector = Icons.Filled.Save, contentDescription = "保存配置", modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("应用并保存", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }

                        if (isConfigured) {
                            Button(
                                onClick = { isEditingConfig = false },
                                modifier = Modifier.fillMaxWidth(),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.15f),
                                    contentColor = MaterialTheme.colorScheme.onBackground
                                )
                            ) {
                                Text("取消", fontSize = 11.sp)
                            }
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}

@Composable
fun SyncProgressBlock(
    statusMessage: String,
    isSyncing: Boolean,
    pending: Boolean,
    phase: String,
    step: Int,
    total: Int,
    detail: String,
    isDark: Boolean,
    onCancel: (() -> Unit)? = null,
    onRetry: (() -> Unit)? = null
) {
    val accent = if (isDark) NeonCyan else GoldPrimary
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(if (isDark) DarkBg else LightBg)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = if (isSyncing) Icons.Filled.Sync else Icons.Filled.CloudQueue,
                contentDescription = "同步状态",
                tint = accent,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = if (isSyncing) phase else if (pending) "有待同步变更" else "同步空闲",
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f)
            )
            if (total > 0) {
                Text(
                    text = "$step/$total",
                    fontSize = 11.sp,
                    color = if (isDark) TextGray else TextMuted
                )
            }
        }
        if (total > 0) {
            LinearProgressIndicator(
                progress = { (step.toFloat() / total.toFloat()).coerceIn(0f, 1f) },
                modifier = Modifier.fillMaxWidth().height(5.dp).clip(RoundedCornerShape(4.dp)),
                color = accent,
                trackColor = accent.copy(alpha = 0.18f)
            )
        }
        Text(
            text = detail.ifBlank { statusMessage },
            fontSize = 12.sp,
            lineHeight = 17.sp,
            color = if (isDark) TextGray else TextMuted
        )
        if (isSyncing && onCancel != null) {
            Button(
                onClick = onCancel,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = (if (isDark) NeonRed else Color(0xFFD32F2F)).copy(alpha = 0.92f),
                    contentColor = Color.White
                )
            ) {
                Icon(imageVector = Icons.Filled.Cancel, contentDescription = "终止同步", modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("终止当前同步", fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        } else if (!isSyncing && onRetry != null) {
            Button(
                onClick = onRetry,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = accent,
                    contentColor = if (isDark) DarkBg else Color.White
                )
            ) {
                Icon(imageVector = Icons.Filled.CloudSync, contentDescription = "重新同步", modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = if (pending) "立即同步未同步修改" else "立即重试同步",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
fun SyncHistoryCard(
    entry: SyncHistoryEntry,
    expanded: Boolean,
    isDark: Boolean,
    onToggle: () -> Unit
) {
    val statusColor = when (entry.status) {
        "success" -> if (isDark) NeonGreen else ForestGreen
        "warning" -> if (isDark) Color(0xFFFFB74D) else WarmOrange
        "error" -> if (isDark) NeonRed else Color.Red
        else -> if (isDark) NeonCyan else GoldPrimary
    }
    val localCount = entry.localChanges.size
    val remoteCount = entry.remoteChanges.size
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(if (isDark) DarkBg else LightBg)
            .clickable { onToggle() }
            .padding(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(9.dp)
                    .clip(CircleShape)
                    .background(statusColor)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = formatSyncTime(entry.finishedAt),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = entry.message,
                    fontSize = 11.sp,
                    lineHeight = 15.sp,
                    color = if (isDark) TextGray else TextMuted,
                    maxLines = if (expanded) Int.MAX_VALUE else 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = "本机 $localCount / 云端 $remoteCount",
                    fontSize = 10.sp,
                    color = statusColor,
                    fontWeight = FontWeight.SemiBold
                )
                Icon(
                    imageVector = if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                    contentDescription = "展开同步记录",
                    tint = if (isDark) TextGray else TextMuted,
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        AnimatedVisibility(
            visible = expanded,
            enter = expandVertically() + fadeIn(),
            exit = shrinkVertically() + fadeOut()
        ) {
            Column(
                modifier = Modifier.padding(top = 10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                if (entry.downloadedFiles.isNotEmpty()) {
                    SyncFileLine("读取的备份", entry.downloadedFiles.joinToString("、"), isDark)
                }
                if (entry.uploadedFile.isNotBlank()) {
                    SyncFileLine("保存的备份", entry.uploadedFile, isDark)
                }
                ChangeGroup(title = "本机修改", changes = entry.localChanges, isDark = isDark)
                ChangeGroup(title = "云端更新", changes = entry.remoteChanges, isDark = isDark)
            }
        }
    }
}

@Composable
fun SyncFileLine(label: String, value: String, isDark: Boolean) {
    Column {
        Text(
            text = label,
            fontSize = 10.sp,
            color = if (isDark) NeonCyan else GoldPrimary,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = value,
            fontSize = 10.sp,
            lineHeight = 14.sp,
            color = if (isDark) TextGray else TextMuted
        )
    }
}

@Composable
fun ChangeGroup(title: String, changes: List<CardChangeDetail>, isDark: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = "$title (${changes.size})",
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )
        if (changes.isEmpty()) {
            Text(
                text = "无",
                fontSize = 10.sp,
                color = if (isDark) TextGray else TextMuted
            )
        } else {
            changes.forEach { change ->
                ChangeItem(change = change, isDark = isDark)
            }
        }
    }
}

@Composable
fun ChangeItem(change: CardChangeDetail, isDark: Boolean) {
    val color = when (change.kind) {
        "added" -> if (isDark) NeonGreen else ForestGreen
        "deleted" -> if (isDark) NeonRed else Color.Red
        else -> if (isDark) NeonCyan else GoldPrimary
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.08f))
            .padding(8.dp)
    ) {
        Text(
            text = "${changeKindText(change.kind)}：${change.cardName}",
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = color,
            lineHeight = 15.sp
        )
        change.fields.forEach { field ->
            Text(
                text = "${field.label}: ${field.oldValue.ifBlank { "空" }} -> ${field.newValue.ifBlank { "空" }}",
                fontSize = 10.sp,
                lineHeight = 14.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.82f)
            )
        }
    }
}

fun changeKindText(kind: String): String = when (kind) {
    "added" -> "新增"
    "deleted" -> "删除"
    "modified" -> "修改"
    else -> "变更"
}

fun formatSyncTime(value: String): String {
    if (value.isBlank()) return "未知时间"
    return value.replace("T", " ").replace("Z", "").take(19)
}

// =============================================================================
// 🎨 公用卡片 Section 容器与配置
// =============================================================================

@Composable
fun DetailSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    val isDark by ThemeManager.isDarkTheme.collectAsState()
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = if (isDark) 4.dp else 1.5.dp,
                shape = RoundedCornerShape(14.dp),
                spotColor = if (isDark) Color.Black else NavySecondary.copy(alpha = 0.15f)
            )
            .clip(RoundedCornerShape(14.dp))
            .background(if (isDark) DarkCardBg else Color.White)
            .padding(14.dp)
    ) {
        Text(
            text = title,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = if (isDark) NeonCyan else GoldPrimary
        )
        Spacer(modifier = Modifier.height(12.dp))
        content()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun getOutlinedTextFieldColors(isDark: Boolean) = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = if (isDark) NeonCyan else GoldPrimary,
    focusedLabelColor = if (isDark) NeonCyan else GoldPrimary,
    unfocusedBorderColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.3f),
    focusedContainerColor = if (isDark) DarkBg else Color.White,
    unfocusedContainerColor = if (isDark) DarkBg else Color.White,
    focusedTextColor = MaterialTheme.colorScheme.onSurface,
    unfocusedTextColor = MaterialTheme.colorScheme.onSurface,
    focusedPlaceholderColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.75f),
    unfocusedPlaceholderColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.75f),
    cursorColor = if (isDark) NeonCyan else GoldPrimary
)

// =============================================================================
// 🛡️ 智能高保真卡组织徽标与安全芯片绘制系统
// =============================================================================

/**
 * 智能判定卡组织
 */
fun getCardBrand(cardNumber: String): String {
    val clean = cardNumber.replace(" ", "")
    return when {
        clean.startsWith("4") -> "Visa"
        clean.startsWith("5") -> "Mastercard"
        clean.startsWith("62") || clean.startsWith("81") -> "UnionPay"
        clean.startsWith("34") || clean.startsWith("37") -> "Amex"
        clean.startsWith("35") -> "JCB"
        clean.startsWith("6011") || clean.startsWith("64") || clean.startsWith("65") -> "Discover"
        else -> "Unknown"
    }
}

/**
 * 实时卡号遮罩格式化（显示末四位，其余星号遮罩，用于主列表防窥）
 */
fun formatMaskedCardNumber(rawNum: String): String {
    val clean = rawNum.replace(" ", "")
    if (clean.length < 4) return "••••  ••••  ••••  ••••"
    val lastFour = clean.takeLast(4)
    return "••••  ••••  ••••  $lastFour"
}

/**
 * 完整卡号分段格式化（每4位加两个空格，用于表单或详情显示）
 */
fun formatSpacingCardNumber(rawNum: String): String {
    val clean = rawNum.replace(" ", "")
    return clean.chunked(4).joinToString("  ")
}

/**
 * 安全芯片 (EMV Chip) 的高保真精细绘制
 */
@Composable
fun EMVChip(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .width(28.dp)
            .height(22.dp)
            .shadow(2.dp, RoundedCornerShape(4.dp))
            .clip(RoundedCornerShape(4.dp))
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        Color(0xFFF4D068), // 亮金色
                        Color(0xFFC89532)  // 暗金色
                    )
                )
            )
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            val lineColor = Color(0x60000000) // 触点线条颜色
            val strokeW = 1.dp.toPx()

            // 绘制精密触点十字细线
            drawLine(color = lineColor, start = Offset(w * 0.5f, 0f), end = Offset(w * 0.5f, h), strokeWidth = strokeW)
            drawLine(color = lineColor, start = Offset(0f, h * 0.5f), end = Offset(w, h * 0.5f), strokeWidth = strokeW)

            // 左右两侧的竖线
            drawLine(color = lineColor, start = Offset(w * 0.25f, h * 0.15f), end = Offset(w * 0.25f, h * 0.85f), strokeWidth = strokeW)
            drawLine(color = lineColor, start = Offset(w * 0.75f, h * 0.15f), end = Offset(w * 0.75f, h * 0.85f), strokeWidth = strokeW)

            // 上下连结小横线
            drawLine(color = lineColor, start = Offset(w * 0.25f, h * 0.15f), end = Offset(w * 0.75f, h * 0.15f), strokeWidth = strokeW)
            drawLine(color = lineColor, start = Offset(w * 0.25f, h * 0.85f), end = Offset(w * 0.75f, h * 0.85f), strokeWidth = strokeW)
            
            // 内部小微处理器核心方块
            drawRoundRect(
                color = Color(0xFFE5A93B).copy(alpha = 0.5f),
                topLeft = Offset(w * 0.35f, h * 0.3f),
                size = Size(w * 0.3f, h * 0.4f),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(1.dp.toPx(), 1.dp.toPx())
            )
        }
    }
}

/**
 * 顶级像素级精美高保真卡组织徽标渲染器
 */
@Composable
fun CardBrandBadge(brand: String, modifier: Modifier = Modifier) {
    when (brand) {
        "Visa" -> VisaLogo(modifier)
        "Mastercard" -> MastercardLogo(modifier)
        "UnionPay" -> UnionPayLogo(modifier)
        "Amex" -> AmexLogo(modifier)
        "JCB" -> JcbLogo(modifier)
        "Discover" -> DiscoverLogo(modifier)
        else -> UnknownLogo(modifier)
    }
}

@Composable
fun VisaLogo(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .width(42.dp)
            .height(22.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(Color(0xFF1A1F71)), // Visa 经典蓝
        contentAlignment = Alignment.Center
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "V",
                color = Color(0xFFF7B600), // Visa 金色撇
                fontWeight = FontWeight.ExtraBold,
                fontSize = 11.sp,
                fontFamily = FontFamily.SansSerif,
                style = TextStyle(fontStyle = androidx.compose.ui.text.font.FontStyle.Italic)
            )
            Text(
                text = "ISA",
                color = Color.White,
                fontWeight = FontWeight.ExtraBold,
                fontSize = 11.sp,
                fontFamily = FontFamily.SansSerif,
                style = TextStyle(fontStyle = androidx.compose.ui.text.font.FontStyle.Italic)
            )
        }
    }
}

@Composable
fun MastercardLogo(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .width(36.dp)
            .height(22.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(16.dp)
                .clip(CircleShape)
                .background(Color(0xFFEB001B)) // 经典万事达红圆
        )
        Spacer(modifier = Modifier.width(-6.dp)) // 负的 Margin 产生完美的物理相交重叠
        Box(
            modifier = Modifier
                .size(16.dp)
                .clip(CircleShape)
                .background(Color(0xFFFF5F00).copy(alpha = 0.9f)) // 经典万事达橙黄圆
        )
    }
}

@Composable
fun UnionPayLogo(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .width(44.dp)
            .height(22.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        Color(0xFFC00F1A), // 经典银联红
                        Color(0xFF003876), // 经典银联深蓝
                        Color(0xFF007A48)  // 经典银联绿
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "银联",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 9.sp,
            letterSpacing = 0.5.sp
        )
    }
}

@Composable
fun AmexLogo(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .width(36.dp)
            .height(22.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(Color(0xFF007BC1)), // 经典运通蓝
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "AMEX",
            color = Color.White,
            fontWeight = FontWeight.Black,
            fontSize = 9.sp,
            letterSpacing = 0.5.sp
        )
    }
}

@Composable
fun JcbLogo(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .width(42.dp)
            .height(22.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(Color.White.copy(alpha = 0.1f))
            .padding(1.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        val colors = listOf(Color(0xFF004481), Color(0xFFD0112B), Color(0xFF008542))
        val letters = listOf("J", "C", "B")
        for (i in 0..2) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .padding(horizontal = 0.5.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(colors[i]),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = letters[i],
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 10.sp
                )
            }
        }
    }
}

@Composable
fun DiscoverLogo(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .width(46.dp)
            .height(22.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(Color(0xFF231F20)), // 经典Discover暗黑背景
        contentAlignment = Alignment.Center
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "DISC",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 8.sp
            )
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFFF6600)) // 经典 Discover 橙色圆形O
            )
            Text(
                text = "VER",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 8.sp
            )
        }
    }
}

@Composable
fun UnknownLogo(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .width(36.dp)
            .height(22.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(Color.White.copy(alpha = 0.2f))
            .border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(4.dp)),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Filled.CreditCard,
            contentDescription = "未知卡组织",
            tint = Color.White,
            modifier = Modifier.size(12.dp)
        )
    }
}

// =============================================================================
// 🥇 优惠用卡核心算法与面板渲染组件追加区
// =============================================================================

/**
 * 智能计算信用卡的免息期天数。
 *
 * @param card 信用卡数据
 * @param today 今天日期，方便进行单体测试或多边界检验（默认为 LocalDate.now()）
 * @return 免息天数；如果卡片账单日或还款日未设置/非法，则返回 -1
 */
fun calculateInterestFreeDays(card: SharedCard, today: LocalDate = LocalDate.now()): Int {
    val billDay = card.accountBillDate.toIntOrNull() ?: return -1
    val dueDay = card.dueDate.toIntOrNull() ?: return -1

    if (billDay !in 1..31 || dueDay !in 1..31) return -1

    val spendDay = today.dayOfMonth

    // 1. 确定消费会计入哪个月的账单日
    val isNextBill = if (card.billingDaySpendingToNextBill) {
        spendDay >= billDay
    } else {
        spendDay > billDay
    }

    val targetBillMonth = if (isNextBill) today.plusMonths(1) else today
    val lengthOfBillMonth = targetBillMonth.lengthOfMonth()
    
    // 目标账单日对齐该月最大天数
    val targetBillDate = LocalDate.of(
        targetBillMonth.year,
        targetBillMonth.month,
        min(billDay, lengthOfBillMonth)
    )

    // 2. 计算对应的还款日
    // 如果还款日天数 <= 账单日天数，说明在下个月还款
    val isNextMonthDue = dueDay <= billDay
    val targetDueMonth = if (isNextMonthDue) targetBillDate.plusMonths(1) else targetBillDate
    val lengthOfDueMonth = targetDueMonth.lengthOfMonth()

    val targetDueDate = LocalDate.of(
        targetDueMonth.year,
        targetDueMonth.month,
        min(dueDay, lengthOfDueMonth)
    )

    // 3. 计算免息天数
    val days = ChronoUnit.DAYS.between(today, targetDueDate).toInt()
    return if (days >= 0) days else 0
}

@Composable
fun BestUsagePanel(
    cards: List<SharedCard>,
    isDark: Boolean,
    onConfigureCard: (String) -> Unit,
    onBack: () -> Unit
) {
    val today = LocalDate.now()
    
    // 过滤出能够计算免息期的信用卡并按天数降序排序
    val validCards = cards.map { card ->
        card to calculateInterestFreeDays(card, today)
    }.filter { it.second != -1 }
     .sortedByDescending { it.second }

    // 过滤出未配置账单信息的卡片
    val invalidCards = cards.filter { card ->
        calculateInterestFreeDays(card, today) == -1
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(if (isDark) DarkBg else LightBg)
    ) {
        // 精致扁平化零顶栏返回区域
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val accent = if (isDark) NeonCyan else GoldPrimary
            AppBackButton(
                onClick = onBack,
                contentDescription = "返回工具",
                tint = accent,
                containerColor = MaterialTheme.colorScheme.surface,
                borderColor = accent.copy(alpha = 0.34f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "优惠用卡",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Black,
                    color = if (isDark) TextWhite else TextDark
                )
                Text(
                    text = "智能账单周期演算与首选决策",
                    fontSize = 12.sp,
                    color = if (isDark) NeonCyan else GoldPrimary,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        // 核心滚动区域
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            if (cards.isEmpty()) {
                item {
                    EmptyCardsState(isDark = isDark)
                }
            } else if (validCards.isEmpty() && invalidCards.isNotEmpty()) {
                item {
                    NoConfiguredCardsState(isDark = isDark)
                }
            } else {
                itemsIndexed(validCards, key = { _, pair -> pair.first.id }) { index, (card, days) ->
                    BestUsageCardTile(
                        card = card,
                        days = days,
                        rank = index + 1,
                        isDark = isDark,
                        onClick = { onConfigureCard(card.id) }
                    )
                }
            }

            // 待配置折叠区域
            if (invalidCards.isNotEmpty()) {
                item {
                    InvalidCardsCollapseSection(
                        invalidCards = invalidCards,
                        isDark = isDark,
                        onConfigureCard = onConfigureCard
                    )
                }
            }
        }
    }
}

@Composable
fun BestUsageCardTile(
    card: SharedCard,
    days: Int,
    rank: Int,
    isDark: Boolean,
    onClick: () -> Unit
) {
    val brand = getCardBrand(card.cardNumber)
    val gradientBrush = when (brand) {
        "Visa" -> Brush.linearGradient(listOf(Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)))
        "Mastercard" -> Brush.linearGradient(listOf(Color(0xFF373B44), Color(0xFF4286f4)))
        "Amex" -> Brush.linearGradient(listOf(Color(0xFF11998e), Color(0xFF38ef7d)))
        "UnionPay" -> Brush.linearGradient(listOf(Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)))
        "JCB" -> Brush.linearGradient(listOf(Color(0xFF1F1C2C), Color(0xFF928DAB)))
        "Discover" -> Brush.linearGradient(listOf(Color(0xFFF000FF), Color(0xFF7B00FF)))
        else -> Brush.linearGradient(listOf(Color(0xFF1F1C2C), Color(0xFF928DAB)))
    }

    val borderStroke = when (rank) {
        1 -> BorderStroke(
            2.5.dp, 
            Brush.linearGradient(
                listOf(
                    if (isDark) NeonCyan else GoldPrimary, 
                    if (isDark) NeonPurple else NavySecondary
                )
            )
        )
        2 -> BorderStroke(
            1.5.dp, 
            Brush.linearGradient(
                listOf(
                    if (isDark) NeonPurple else NavySecondary,
                    if (isDark) NeonCyan else Color(0xFFB6C2CF)
                )
            )
        )
        3 -> BorderStroke(
            1.5.dp, 
            Brush.linearGradient(
                listOf(
                    if (isDark) NeonGreen else ForestGreen,
                    if (isDark) NeonCyan else Color(0xFFE2E8F0)
                )
            )
        )
        else -> null
    }

    val containerShape = RoundedCornerShape(18.dp)
    
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .let {
                if (borderStroke != null) {
                    it.border(borderStroke, containerShape)
                } else {
                    it
                }
            }
            .clip(containerShape)
            .background(if (isDark) DarkCardBg.copy(alpha = 0.85f) else LightCardBg)
            .clickable { onClick() }
            .padding(14.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    val badgeColor = when (rank) {
                        1 -> if (isDark) NeonCyan else GoldPrimary
                        2 -> if (isDark) NeonPurple else NavySecondary
                        3 -> if (isDark) NeonGreen else ForestGreen
                        else -> if (isDark) TextGray else TextMuted
                    }
                    val badgeText = when (rank) {
                        1 -> "🥇 今日首选"
                        2 -> "🥈 备选方案"
                        3 -> "🥉 推荐刷卡"
                        else -> "第 $rank 名"
                    }
                    
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(30.dp))
                            .background(badgeColor.copy(alpha = 0.15f))
                            .border(1.dp, badgeColor.copy(alpha = 0.4f), RoundedCornerShape(30.dp))
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = badgeText,
                            color = badgeColor,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    Text(
                        text = "免息期",
                        fontSize = 11.sp,
                        color = if (isDark) TextGray else TextMuted,
                        modifier = Modifier.padding(bottom = 2.dp)
                    )
                    Text(
                        text = days.toString(),
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Black,
                        color = when (rank) {
                            1 -> if (isDark) NeonCyan else GoldPrimary
                            2 -> if (isDark) NeonPurple else NavySecondary
                            3 -> if (isDark) NeonGreen else ForestGreen
                            else -> if (isDark) TextWhite else TextDark
                        }
                    )
                    Text(
                        text = "天",
                        fontSize = 11.sp,
                        color = if (isDark) TextGray else TextMuted,
                        modifier = Modifier.padding(bottom = 2.dp)
                    )
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(84.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(gradientBrush)
                    .padding(12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.SpaceBetween
                ) {
                    Column {
                        Text(
                            text = card.bank.ifEmpty { "信用银行" },
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            text = card.alias.ifEmpty { "未命名别名" },
                            color = Color.White.copy(alpha = 0.7f),
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Light,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    Text(
                        text = formatSpacingCardNumber(card.cardNumber),
                        color = Color.White,
                        fontSize = 12.sp,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.SemiBold,
                        letterSpacing = 0.8.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                
                Column(
                    horizontalAlignment = Alignment.End,
                    verticalArrangement = Arrangement.SpaceBetween
                ) {
                    CardBrandBadge(brand = brand)
                    Spacer(modifier = Modifier.height(6.dp))
                    EMVChip()
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (isDark) Color.White.copy(alpha = 0.04f) else Color.Black.copy(alpha = 0.02f))
                    .padding(8.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column(horizontalAlignment = Alignment.Start) {
                    Text("账单日", fontSize = 10.sp, color = if (isDark) TextGray else TextMuted)
                    Text("每月 ${card.accountBillDate} 号", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = if (isDark) TextWhite else TextDark)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("还款日", fontSize = 10.sp, color = if (isDark) TextGray else TextMuted)
                    Text("每月 ${card.dueDate} 号", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = if (isDark) TextWhite else TextDark)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("入账规则", fontSize = 10.sp, color = if (isDark) TextGray else TextMuted)
                    Text(
                        text = if (card.billingDaySpendingToNextBill) "账单日消费计入下期" else "账单日消费计入本期",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = if (isDark) NeonCyan else GoldPrimary
                    )
                }
            }

            if (rank == 1) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background((if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.08f))
                        .border(0.5.dp, (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.25f), RoundedCornerShape(8.dp))
                        .padding(10.dp)
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Lightbulb,
                            contentDescription = "黄金提示",
                            tint = if (isDark) NeonCyan else GoldPrimary,
                            modifier = Modifier.size(16.dp).padding(top = 1.dp)
                        )
                        Column {
                            Text(
                                text = "💡 用卡黄金提示",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (isDark) NeonCyan else GoldPrimary
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = "今日刷卡处于最拉长周转账单期！本次消费款项将享受长达 $days 天的免息缓冲。建议优先在此卡额度内大额支出，最大化周转您的闲置资金。",
                                fontSize = 10.sp,
                                color = if (isDark) TextGray else TextMuted,
                                lineHeight = 14.sp
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun EmptyCardsState(isDark: Boolean) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(if (isDark) DarkCardBg else LightCardBg)
            .border(1.dp, (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.18f), RoundedCornerShape(14.dp))
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.CreditCardOff,
                contentDescription = "暂无卡片",
                tint = if (isDark) NeonCyan else GoldPrimary,
                modifier = Modifier.size(36.dp)
            )
            Text(
                text = "暂无信用卡",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = if (isDark) TextWhite else TextDark
            )
            Text(
                text = "请先在首页卡包中添加您的信用卡数据",
                fontSize = 12.sp,
                color = if (isDark) TextGray else TextMuted,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
fun NoConfiguredCardsState(isDark: Boolean) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(if (isDark) DarkCardBg else LightCardBg)
            .border(1.dp, (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.18f), RoundedCornerShape(14.dp))
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.Tune,
                contentDescription = "待完善账单配置",
                tint = if (isDark) NeonCyan else GoldPrimary,
                modifier = Modifier.size(36.dp)
            )
            Text(
                text = "未检测到已配置的信用卡账单",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = if (isDark) TextWhite else TextDark
            )
            Text(
                text = "请先在下方“未配置账单信息的卡片”中配置“账单日”和“还款日”",
                fontSize = 12.sp,
                color = if (isDark) TextGray else TextMuted,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
fun InvalidCardsCollapseSection(
    invalidCards: List<SharedCard>,
    isDark: Boolean,
    onConfigureCard: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(if (isDark) DarkCardBg.copy(alpha = 0.5f) else LightCardBg.copy(alpha = 0.8f))
            .border(
                0.5.dp, 
                (if (isDark) TextGray else TextMuted).copy(alpha = 0.15f), 
                RoundedCornerShape(14.dp)
            )
            .padding(14.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = !expanded },
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.ErrorOutline,
                    contentDescription = "待配置信息",
                    tint = if (isDark) NeonPurple else NavySecondary,
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = "待配置账单信息的卡片 (${invalidCards.size}张)",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isDark) TextWhite else TextDark
                )
            }
            Icon(
                imageVector = if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                contentDescription = "展开折叠",
                tint = if (isDark) TextGray else TextMuted,
                modifier = Modifier.size(18.dp)
            )
        }

        if (expanded) {
            Spacer(modifier = Modifier.height(10.dp))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                invalidCards.forEach { card ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (isDark) Color.White.copy(alpha = 0.03f) else Color.Black.copy(alpha = 0.01f))
                            .padding(8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = card.bank.ifEmpty { "信用银行" },
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (isDark) TextWhite else TextDark,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                text = card.alias.ifEmpty { "未命名别名" },
                                fontSize = 10.sp,
                                color = if (isDark) TextGray else TextMuted,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                        
                        Button(
                            onClick = { onConfigureCard(card.id) },
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 2.dp),
                            modifier = Modifier.height(28.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = (if (isDark) NeonPurple else NavySecondary).copy(alpha = 0.15f),
                                contentColor = if (isDark) NeonPurple else NavySecondary
                            ),
                            border = BorderStroke(
                                0.5.dp, 
                                (if (isDark) NeonPurple else NavySecondary).copy(alpha = 0.5f)
                            )
                        ) {
                            Text("去配置", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SettingsHelpPanel(
    isDark: Boolean,
    onBack: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(if (isDark) DarkBg else LightBg)
    ) {
        // 顶部导航栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val accent = if (isDark) NeonCyan else GoldPrimary
            AppBackButton(
                onClick = onBack,
                contentDescription = "返回设置",
                tint = accent,
                containerColor = MaterialTheme.colorScheme.surface,
                borderColor = accent.copy(alpha = 0.34f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "使用帮助",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Black,
                    color = if (isDark) TextWhite else TextDark
                )
                Text(
                    text = "信用卡管理与同步常见问题解答",
                    fontSize = 12.sp,
                    color = if (isDark) NeonCyan else GoldPrimary,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        // FAQ 列表
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                FAQItem(
                    question = "1. NFC 快速验卡或刷卡感应录入时没有反应怎么办？",
                    answer = "常见排查方法如下：\n" +
                            "• 芯片安全性屏蔽：部分高安全级别或防克隆的信用卡（包括特定的万事达和高安银联卡）对离线明文读取进行了芯片级保护，暂无法通过 NFC 感应读取明文卡号。本应用已支持智能兜底，对此类卡片将友好提示“暂不支持该卡片”，建议使用相机扫描或手动录入。\n" +
                            "• 天线感应区偏离：NFC感应线圈通常位于手机背面的中上部（摄像头附近），贴卡时请将卡片正中对准此区域。\n" +
                            "• 交互静止要求：贴卡感应时，请将卡片紧贴手机背部并保持静止 1-2 秒，请勿快速晃动或移开卡片，待提示“读取成功”后再行拿开。",
                    isDark = isDark
                )
            }
            item {
                FAQItem(
                    question = "2. 相机扫描卡面无法自动识别提取？",
                    answer = "相机扫描识别要领：\n" +
                            "• 避免强光反射：信用卡表面材质光滑，强光反射会导致卡面数字反光甚至失真。请在光线温和且均匀的室内环境下扫描。\n" +
                            "• 推荐手动拍照：若自动扫描无法触发，推荐点击我们新设计的“手动拍照”按钮。在对齐框后按下拍照，系统会在后台以高精度本地 OCR 自动识别、智能提取卡片数字，并自动裁剪保存高保真的卡片大图。\n" +
                            "• 磨损降级：对于表面磨损、字迹脱漆或无凹凸感印刷的卡片，可能导致本地分析率下降，此时建议一键切换为手动输入，极简完成录入。",
                    isDark = isDark
                )
            }
            item {
                FAQItem(
                    question = "3. WebDAV 备份的服务器地址和应用密码怎么填写？",
                    answer = "三步快速配置指南：\n" +
                            "• 服务器地址：根据您所用的云盘填写其 WebDAV 终结点。如坚果云为 `https://dav.jianguoyun.com/dav/`。\n" +
                            "• 账号：填写您在该云盘的注册电子邮箱地址。\n" +
                            "• 应用密码：**请注意，这绝对不是您的云盘登录密码**。您需要登录坚果云等云盘网页端，在“安全选项 -> 第三方应用密码”中点击“添加应用”来生成一个独立的 16 位专属应用密码。\n" +
                            "• 安全原则：本应用为纯单机端到端直连，所有同步密码仅在本地设备沙箱加密保存，数据直接以 HTTPS 加密传输至您的私人云盘，绝无第三方中转。",
                    isDark = isDark
                )
            }
            item {
                FAQItem(
                    question = "4. 多张信用卡“共享额度”的算法规则是怎样的？",
                    answer = "多卡合并与资产计算规则：\n" +
                            "• 同行共享机制：许多银行对同一持卡人名下的多张信用卡实施“额度共享”（以额度最高的那张卡作为共享额度上限）。\n" +
                            "• 额度合并算法：在系统中，若您将某几张卡勾选了“共享额度”开关，系统将自动激活共享资产合并算法——在财富统计和总额度中，这组卡片将仅取其中的额度最大值计入总额度，而非简单物理累加，从而实现百分之百真实科学的财务数据统计与额度预警。",
                    isDark = isDark
                )
            }
        }
    }
}

@Composable
fun FAQItem(
    question: String,
    answer: String,
    isDark: Boolean
) {
    var expanded by remember { mutableStateOf(false) }
    val accent = if (isDark) NeonCyan else GoldPrimary
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (isDark) DarkCardBg else LightCardBg)
            .border(
                0.5.dp, 
                (if (expanded) accent else (if (isDark) TextGray else TextMuted)).copy(alpha = 0.22f), 
                RoundedCornerShape(12.dp)
            )
            .clickable { expanded = !expanded }
            .padding(14.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = question,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = if (isDark) TextWhite else TextDark,
                modifier = Modifier.weight(1f)
            )
            Icon(
                imageVector = if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                contentDescription = "展开FAQ回答",
                tint = if (expanded) accent else (if (isDark) TextGray else TextMuted),
                modifier = Modifier.size(18.dp)
            )
        }
        
        if (expanded) {
            Spacer(modifier = Modifier.height(10.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background((if (isDark) Color.White else Color.Black).copy(alpha = 0.03f))
                    .padding(10.dp)
            ) {
                Text(
                    text = answer,
                    fontSize = 12.sp,
                    color = if (isDark) TextGray else TextMuted,
                    lineHeight = 18.sp
                )
            }
        }
    }
}

@Composable
fun SettingsAboutPanel(
    isDark: Boolean,
    onBack: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(if (isDark) DarkBg else LightBg)
    ) {
        // 顶部导航
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val accent = if (isDark) NeonCyan else GoldPrimary
            AppBackButton(
                onClick = onBack,
                contentDescription = "返回设置",
                tint = accent,
                containerColor = MaterialTheme.colorScheme.surface,
                borderColor = accent.copy(alpha = 0.34f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "关于软件",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Black,
                    color = if (isDark) TextWhite else TextDark
                )
                Text(
                    text = "版本规约与隐私安全透明度声明",
                    fontSize = 12.sp,
                    color = if (isDark) NeonCyan else GoldPrimary,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        // 关于我们主体文字
        Column(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Spacer(modifier = Modifier.height(6.dp))
            
            // 软件卡片
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(if (isDark) DarkCardBg else LightCardBg)
                    .border(1.dp, (if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.18f), RoundedCornerShape(16.dp))
                    .padding(20.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.AutoAwesome,
                        contentDescription = "卡包卫士",
                        tint = if (isDark) NeonCyan else GoldPrimary,
                        modifier = Modifier.size(44.dp)
                    )
                    Text(
                        text = "卡包卫士 Premium",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Black,
                        color = if (isDark) TextWhite else TextDark
                    )
                    Text(
                        text = "版本号：v2.2.0 Premium (2026)",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (isDark) NeonCyan else GoldPrimary
                    )
                }
            }

            // 软件简介
            DetailSection(title = "📝 软件简介") {
                Text(
                    text = "卡包卫士 Premium 是一款专注安全、精细拟真的信用卡智能账单与资产健康管理助手。应用通过完全离线的本地沙盒数据库以及高规格的本地 NFC 读卡、相机识别技术，让您能够轻松归集多行信用卡。同时支持科学推算共享额度、可用免息期，并通过端到端加密的 WebDAV 私人同步通道，给您的账单与财富管理筑起一道坚不可摧的隐私安全防护盾。",
                    fontSize = 12.sp,
                    color = if (isDark) TextGray else TextMuted,
                    lineHeight = 18.sp,
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                )
            }

            // 隐私与权限说明
            DetailSection(title = "🛡️ 权限与隐私声明") {
                Column(
                    modifier = Modifier.padding(horizontal = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    PrivacyPermissionRow(
                        name = "NFC 读卡权限 (感应刷卡)",
                        description = "仅在您主动使用 NFC 靠近验卡或雷达读卡时唤醒硬件，通过读取公开的非接触式 IC 卡标准指令，解析脱敏的卡号与有效期。本应用绝不也无权保存任何交易密码或敏感安全码。",
                        isDark = isDark
                    )
                    PrivacyPermissionRow(
                        name = "相机扫描权限 (卡号提取)",
                        description = "用于启动拍摄镜头读取卡面数字及手动拍照备份。识别及卡片裁剪保存等分析处理全部发生在本机设备本地，绝对不会将您的卡面图像或数字向任何远端服务器进行传输或收集。",
                        isDark = isDark
                    )
                    PrivacyPermissionRow(
                        name = "本地存储空间 (沙盒隔离)",
                        description = "用于加密存储本地卡包信息、卡片裁剪后的大图资源。数据严格储存在系统沙盒中，其他第三方应用无权读取，且会随着应用的卸载自动清除，保障物理隔离隐私。",
                        isDark = isDark
                    )
                    PrivacyPermissionRow(
                        name = "端到端网络同步 (WebDAV)",
                        description = "仅在您配置了私人 WebDAV 云备份账号后，在本地与您的私人网盘之间进行直连备份。我们绝不架设中间服务器，没有任何广告、统计以及追踪 SDK 驻留，保证 100% 纯净度。",
                        isDark = isDark
                    )
                }
            }

            // 条款与免责声明
            DetailSection(title = "⚖️ 服务与免责条款") {
                Text(
                    text = "1. 数据免责：本应用提供的免息期天数推算、账单日与还款日提醒以及负债统计等结果，均根据您所录入的参数进行日历学与日期的数学映射推导，仅供个人合理消费规划参考。由于各行信用卡章程可能存在临时修订、国定假期顺延还款等细微差异，请务必以各发卡银行官方公告及账单信息为准。\n" +
                            "2. 财务安全：用户应妥善管理个人手机密码以及 WebDAV 应用同步密码，由于设备丢失或泄露密码引发的数据损毁，需自行承担相应责任。本软件在任何情况下均不对由于依赖本计算结果产生的滞纳金或信用受损等任何直接与间接损失负责。",
                    fontSize = 11.sp,
                    color = if (isDark) TextGray else TextMuted,
                    lineHeight = 16.sp,
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                )
            }

            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}

@Composable
fun PrivacyPermissionRow(
    name: String,
    description: String,
    isDark: Boolean
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(if (isDark) Color.White.copy(alpha = 0.03f) else Color.Black.copy(alpha = 0.01f))
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(if (isDark) NeonCyan else GoldPrimary)
            )
            Text(
                text = name,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = if (isDark) TextWhite else TextDark
            )
        }
        Text(
            text = description,
            fontSize = 10.sp,
            color = if (isDark) TextGray else TextMuted,
            lineHeight = 15.sp
        )
    }
}

@Composable
fun SettingsPrivacyPanel(
    isDark: Boolean,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current

    var hasCamera by remember { mutableStateOf(isPermissionGranted(context, Manifest.permission.CAMERA)) }
    var hasNotification by remember { mutableStateOf(isNotificationPermissionGranted(context)) }

    fun refreshPermissionStates() {
        hasCamera = isPermissionGranted(context, Manifest.permission.CAMERA)
        hasNotification = isNotificationPermissionGranted(context)
    }

    DisposableEffect(lifecycleOwner, context) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
                refreshPermissionStates()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        hasCamera = isGranted
        if (!isGranted) {
            Toast.makeText(context, "相机权限被拒绝，无法使用扫描功能", Toast.LENGTH_LONG).show()
        }
    }

    val notificationLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        hasNotification = isNotificationPermissionGranted(context) || isGranted
        if (!isGranted) {
            Toast.makeText(context, "消息通知权限被拒绝，无法使用提醒功能", Toast.LENGTH_LONG).show()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(if (isDark) DarkBg else LightBg)
    ) {
        // 顶部零顶栏导航
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val accent = if (isDark) NeonCyan else GoldPrimary
            AppBackButton(
                onClick = onBack,
                contentDescription = "返回设置",
                tint = accent,
                containerColor = MaterialTheme.colorScheme.surface,
                borderColor = accent.copy(alpha = 0.34f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "隐私权限管理",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Black,
                    color = if (isDark) TextWhite else TextDark
                )
                Text(
                    text = "应用所需核心功能授权与透明度公示",
                    fontSize = 12.sp,
                    color = if (isDark) NeonCyan else GoldPrimary,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        // 核心滚动列表
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 权限列表介绍
            item {
                Text(
                    text = "卡包卫士 Premium 承诺严格保护持卡人资产与数据隐私。本软件为纯本地单机沙盒数据库运行，所有敏感权限仅在您激活对应场景（如贴卡、扫码）时在本地起效，绝无任何远端个人隐私收集行为。",
                    fontSize = 12.sp,
                    color = if (isDark) TextGray else TextMuted,
                    lineHeight = 18.sp,
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp)
                )
            }

            // 1. 相机权限
            item {
                PermissionItem(
                    name = "📷 相机扫描权限 (android.permission.CAMERA)",
                    description = "用于启动后置摄像头对准实体信用卡进行高精准本地 OCR 扫描，或手动拍照备份大图。图像数据严格在本机内存中进行分析并智能裁剪保存，绝不上报。",
                    isGranted = hasCamera,
                    isDark = isDark,
                    onRequestPermission = {
                        cameraLauncher.launch(Manifest.permission.CAMERA)
                    },
                    onRevokePermission = {
                        if (revokeSelfPermissionOrOpenSettings(context, Manifest.permission.CAMERA, "相机权限")) {
                            hasCamera = false
                        }
                    }
                )
            }

            // 2. 消息通知权限
            item {
                PermissionItem(
                    name = "🔔 消息通知权限 (android.permission.POST_NOTIFICATIONS)",
                    description = "主要用于在您的信用卡“还款日”或“年费产生”临近时，在系统后台为您推送还款警报提醒（仅当开启后台提醒并录入时间时生效）。",
                    isGranted = hasNotification,
                    isDark = isDark,
                    onRequestPermission = {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else {
                            openNotificationSettings(context)
                        }
                    },
                    onRevokePermission = {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            if (revokeSelfPermissionOrOpenSettings(context, Manifest.permission.POST_NOTIFICATIONS, "消息通知权限")) {
                                hasNotification = false
                            }
                        } else {
                            openNotificationSettings(context)
                        }
                    }
                )
            }

            // 3. NFC 感应权限
            item {
                PermissionItem(
                    name = "📡 NFC 射频感应权限 (android.permission.NFC)",
                    description = "用于非接触式物理刷卡交互，当信用卡靠近手机 NFC 天线区域时自动感应读取芯片公开的明文卡号及有效期。属于安卓系统普通级权限，安装时默认授予。",
                    isGranted = true,
                    isDark = isDark
                )
            }

            // 4. 振动回馈权限
            item {
                PermissionItem(
                    name = "📳 本地振动权限 (android.permission.VIBRATE)",
                    description = "当您的卡片通过 NFC 感应读卡成功、或相机扫描出结果的一瞬间，驱动手机马达进行轻微振动反馈。属于系统普通权限，默认授予。",
                    isGranted = true,
                    isDark = isDark
                )
            }

            // 5. 网络连接权限
            item {
                PermissionItem(
                    name = "🌐 网络访问权限 (android.permission.INTERNET)",
                    description = "本应用不架设中转服务器，网络访问仅用于加密对接您在设置中自行配置的私人 WebDAV 服务器进行卡片数据库文件的端到端安全云备份与恢复。",
                    isGranted = true,
                    isDark = isDark
                )
            }
        }
    }
}

@Composable
fun PermissionItem(
    name: String,
    description: String,
    isGranted: Boolean,
    isDark: Boolean,
    onRequestPermission: (() -> Unit)? = null,
    onRevokePermission: (() -> Unit)? = null
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(if (isDark) DarkCardBg else LightCardBg)
            .border(
                0.5.dp, 
                (if (isGranted) (if (isDark) NeonGreen else ForestGreen) else (if (isDark) NeonRed else WarmOrange)).copy(alpha = 0.22f), 
                RoundedCornerShape(14.dp)
            )
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = name,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = if (isDark) TextWhite else TextDark,
                modifier = Modifier.weight(1f)
            )
            
            // 荧光绿或警示红的授权状态标签
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(30.dp))
                    .background(
                        (if (isGranted) (if (isDark) NeonGreen else ForestGreen) else (if (isDark) NeonRed else WarmOrange)).copy(alpha = 0.12f)
                    )
                    .border(
                        0.5.dp, 
                        (if (isGranted) (if (isDark) NeonGreen else ForestGreen) else (if (isDark) NeonRed else WarmOrange)).copy(alpha = 0.4f), 
                        RoundedCornerShape(30.dp)
                    )
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text(
                    text = if (isGranted) "已授权" else "未授权",
                    color = if (isGranted) (if (isDark) NeonGreen else ForestGreen) else (if (isDark) NeonRed else WarmOrange),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        Text(
            text = description,
            fontSize = 11.sp,
            color = if (isDark) TextGray else TextMuted,
            lineHeight = 16.sp
        )

        if (isGranted && onRevokePermission != null) {
            OutlinedButton(
                onClick = onRevokePermission,
                modifier = Modifier.fillMaxWidth().height(32.dp),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 2.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = if (isDark) NeonRed else Color.Red
                ),
                border = BorderStroke(
                    0.5.dp,
                    (if (isDark) NeonRed else Color.Red).copy(alpha = 0.5f)
                ),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("收回授权", fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        } else if (!isGranted && onRequestPermission != null) {
            Button(
                onClick = onRequestPermission,
                modifier = Modifier.fillMaxWidth().height(32.dp),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 2.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = (if (isDark) NeonRed else WarmOrange).copy(alpha = 0.1f),
                    contentColor = if (isDark) NeonRed else WarmOrange
                ),
                border = BorderStroke(
                    0.5.dp, 
                    (if (isDark) NeonRed else WarmOrange).copy(alpha = 0.5f)
                ),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("申请取得授权", fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

private fun isPermissionGranted(context: Context, permission: String): Boolean {
    return androidx.core.content.ContextCompat.checkSelfPermission(
        context,
        permission
    ) == PackageManager.PERMISSION_GRANTED
}

private fun isNotificationPermissionGranted(context: Context): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        isPermissionGranted(context, Manifest.permission.POST_NOTIFICATIONS)
    } else {
        androidx.core.app.NotificationManagerCompat.from(context).areNotificationsEnabled()
    }
}

private fun revokeSelfPermissionOrOpenSettings(
    context: Context,
    permission: String,
    label: String
): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        return try {
            context.revokeSelfPermissionOnKill(permission)
            Toast.makeText(
                context,
                "$label 已收回；系统会在应用退出后正式取消，再次使用时会重新申请授权",
                Toast.LENGTH_LONG
            ).show()
            true
        } catch (e: Exception) {
            Toast.makeText(context, "无法自动收回$label，请在系统设置中关闭", Toast.LENGTH_LONG).show()
            openAppDetailsSettings(context)
            false
        }
    }

    Toast.makeText(context, "当前系统版本不支持应用内自动收回$label，请在系统设置中关闭", Toast.LENGTH_LONG).show()
    openAppDetailsSettings(context)
    return false
}

private fun openNotificationSettings(context: Context) {
    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        }
    } else {
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
        }
    }
    runCatching {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }.onFailure {
        openAppDetailsSettings(context)
    }
}

private fun openAppDetailsSettings(context: Context) {
    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
        data = Uri.fromParts("package", context.packageName, null)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    runCatching {
        context.startActivity(intent)
    }
}
