package com.example.creditcard.ui

import android.app.DatePickerDialog
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Save
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.font.FontFamily
import com.example.creditcard.ui.main.getCardBrand
import com.example.creditcard.ui.main.CardBrandBadge
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.theme.*
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CardFormScreen(
    cardId: String?,
    onBack: () -> Unit
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isEditMode) "修改信用卡" else "添加信用卡", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
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
                            // 直接保存
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
