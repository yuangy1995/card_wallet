package com.example.creditcard.ui.main

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CloudQueue
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.NightlightRound
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation3.runtime.NavKey
import com.example.creditcard.CardDetail
import com.example.creditcard.CardForm
import com.example.creditcard.SyncSettings
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.*
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(
    onItemClick: (NavKey) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    
    // 监听全局卡包数据与同步状态
    val cards by SyncCoordinator.cardsFlow.collectAsState()
    val syncStatus by SyncCoordinator.syncStatus.collectAsState()
    val isDark by ThemeManager.isDarkTheme.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "我的信用卡包",
                        fontWeight = FontWeight.Bold,
                        fontSize = 20.sp,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                },
                actions = {
                    // 主题切换按钮
                    IconButton(onClick = { ThemeManager.toggleTheme(context) }) {
                        Icon(
                            imageVector = if (isDark) Icons.Filled.LightMode else Icons.Filled.NightlightRound,
                            contentDescription = "切换主题",
                            tint = if (isDark) NeonCyan else GoldPrimary
                        )
                    }
                    // 云备份设置按钮
                    IconButton(onClick = { onItemClick(SyncSettings) }) {
                        Icon(
                            imageVector = Icons.Filled.CloudQueue,
                            contentDescription = "云同步设置",
                            tint = if (isDark) NeonCyan else GoldPrimary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { onItemClick(CardForm(null)) },
                containerColor = if (isDark) NeonCyan else GoldPrimary,
                contentColor = if (isDark) DarkBg else Color.White,
                shape = CircleShape,
                modifier = Modifier.padding(bottom = 16.dp, end = 8.dp)
            ) {
                Icon(imageVector = Icons.Filled.Add, contentDescription = "新增信用卡")
            }
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { innerPadding ->
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // 1. 发光云同步状态条
            SyncStatusBar(
                statusMessage = syncStatus.message,
                statusType = syncStatus.type,
                isSyncing = syncStatus.isSyncing,
                isDark = isDark,
                onSyncClick = {
                    coroutineScope.launch {
                        SyncCoordinator.synchronize(context, publishLocalChanges = true)
                    }
                }
            )

            Spacer(modifier = Modifier.height(8.dp))

            // 2. 信用卡卡包列表
            if (cards.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "暂无信用卡，点击右下角新增卡片",
                        color = if (isDark) TextGray else TextMuted,
                        fontSize = 14.sp
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(cards, key = { it.id }) { card ->
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
}

/**
 * 精美半透明同步状态栏
 */
@Composable
fun SyncStatusBar(
    statusMessage: String,
    statusType: String,
    isSyncing: Boolean,
    isDark: Boolean,
    onSyncClick: () -> Unit
) {
    val barColor = when (statusType) {
        "success" -> if (isDark) NeonGreen.copy(alpha = 0.15f) else ForestGreen.copy(alpha = 0.1f)
        "warning" -> if (isDark) Color(0xFFFF9100).copy(alpha = 0.15f) else WarmOrange.copy(alpha = 0.1f)
        "error" -> if (isDark) NeonRed.copy(alpha = 0.15f) else Color.Red.copy(alpha = 0.1f)
        else -> if (isDark) NeonCyan.copy(alpha = 0.15f) else NavySecondary.copy(alpha = 0.05f)
    }

    val textColor = when (statusType) {
        "success" -> if (isDark) NeonGreen else ForestGreen
        "warning" -> if (isDark) Color(0xFFFF9100) else WarmOrange
        "error" -> if (isDark) NeonRed else Color.Red
        else -> if (isDark) NeonCyan else NavySecondary
    }

    val glowModifier = if (isDark) {
        Modifier.shadow(4.dp, shape = RoundedCornerShape(12.dp), spotColor = textColor)
    } else {
        Modifier
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .then(glowModifier)
            .clip(RoundedCornerShape(12.dp))
            .background(barColor)
            .clickable(enabled = !isSyncing) { onSyncClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
            modifier = Modifier.fillMaxWidth()
        ) {
            if (isSyncing) {
                CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    color = textColor,
                    strokeWidth = 2.dp
                )
                Spacer(modifier = Modifier.width(8.dp))
            } else {
                Icon(
                    imageVector = Icons.Filled.Sync,
                    contentDescription = "同步",
                    tint = textColor,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
            }
            Text(
                text = statusMessage,
                color = textColor,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
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
    // 自动判定卡组织，挑选相应的矢量配色和卡标
    val brand = getCardBrand(card.cardNumber)
    
    // 自定义卡片背景渐变
    val gradientBrush = when (brand) {
        "Visa" -> Brush.linearGradient(listOf(Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)))
        "Mastercard" -> Brush.linearGradient(listOf(Color(0xFF373B44), Color(0xFF4286f4)))
        "Amex" -> Brush.linearGradient(listOf(Color(0xFF11998e), Color(0xFF38ef7d)))
        "UnionPay" -> Brush.linearGradient(listOf(Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)))
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
        // 卡面结构
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // 第一行：银行名与卡组织
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
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

                // 矢量渲染的卡标
                CardBrandBadge(brand = brand)
            }

            // 第二行：遮罩卡号
            Text(
                text = formatMaskedCardNumber(card.cardNumber),
                color = Color.White,
                fontSize = 18.sp,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.5.sp
            )

            // 第三行：额度与还款信息
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

/**
 * 实时卡号格式化（显示末四位，其余星号遮罩）
 */
fun formatMaskedCardNumber(rawNum: String): String {
    val clean = rawNum.replace(" ", "")
    if (clean.length < 4) return "•••• •••• •••• ••••"
    val lastFour = clean.takeLast(4)
    return "••••  ••••  ••••  $lastFour"
}

/**
 * 智能判定卡组织
 */
fun getCardBrand(cardNumber: String): String {
    val clean = cardNumber.replace(" ", "")
    return when {
        clean.startsWith("4") -> "Visa"
        clean.startsWith("5") -> "Mastercard"
        clean.startsWith("62") -> "UnionPay"
        clean.startsWith("34") || clean.startsWith("37") -> "Amex"
        clean.startsWith("35") -> "JCB"
        else -> "Unknown"
    }
}

/**
 * 渲染精美的卡组织矢量徽标
 */
@Composable
fun CardBrandBadge(brand: String) {
    val badgeColor = when (brand) {
        "Visa" -> Color(0xFF1A1F71)
        "Mastercard" -> Color(0xFFEB001B)
        "Amex" -> Color(0xFF007BC1)
        "UnionPay" -> Color(0xFF007078)
        else -> Color.White.copy(alpha = 0.2f)
    }

    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(badgeColor)
            .padding(horizontal = 8.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = brand.uppercase(),
            color = Color.White,
            fontWeight = FontWeight.ExtraBold,
            fontSize = 10.sp,
            letterSpacing = 0.5.sp
        )
    }
}
