package com.example.creditcard.ui.security

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockReset
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Security
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.creditcard.theme.DarkBg
import com.example.creditcard.theme.DarkCardBg
import com.example.creditcard.theme.GoldPrimary
import com.example.creditcard.theme.LightBg
import com.example.creditcard.theme.NeonCyan
import com.example.creditcard.theme.NeonGreen
import com.example.creditcard.theme.NeonRed
import com.example.creditcard.theme.TextGray
import com.example.creditcard.theme.TextMuted
import com.example.creditcard.utils.BiometricAuthHelper
import com.example.creditcard.utils.SecurityLockManager
import com.example.creditcard.utils.SecurityRecoveryQuestion
import com.example.creditcard.utils.findFragmentActivity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class LockScreenMode {
    UNLOCK,
    RECOVERY,
    RESET_PASSWORD
}

@Composable
fun SecurityLockScreen(
    isDark: Boolean,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val state by SecurityLockManager.state.collectAsState()
    var mode by remember { mutableStateOf(LockScreenMode.UNLOCK) }
    var recoveryVerified by remember { mutableStateOf(false) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(20.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 420.dp)
                .padding(horizontal = 4.dp, vertical = 24.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            SecurityHeroIcon(isDark = isDark)
            Spacer(modifier = Modifier.height(14.dp))

            when (mode) {
                LockScreenMode.UNLOCK -> UnlockContent(
                    isDark = isDark,
                    failedAttempts = state.failedAttempts,
                    biometricEnabled = state.biometricEnabled,
                    onForgotPassword = {
                        mode = LockScreenMode.RECOVERY
                    }
                )
                LockScreenMode.RECOVERY -> RecoveryContent(
                    isDark = isDark,
                    onBack = { mode = LockScreenMode.UNLOCK },
                    onVerified = {
                        recoveryVerified = true
                        mode = LockScreenMode.RESET_PASSWORD
                    }
                )
                LockScreenMode.RESET_PASSWORD -> ResetPasswordContent(
                    isDark = isDark,
                    title = if (recoveryVerified) "设置新数字密码" else "设置数字密码",
                    subtitle = if (recoveryVerified) "身份验证已通过，请设置新的应用解锁密码" else "请设置应用解锁密码",
                    onDone = {
                        Toast.makeText(context, "密码已更新", Toast.LENGTH_SHORT).show()
                        recoveryVerified = false
                        mode = LockScreenMode.UNLOCK
                    },
                    onCancel = { mode = LockScreenMode.UNLOCK }
                )
            }
        }
    }
}

@Composable
private fun SecurityHeroIcon(isDark: Boolean) {
    Box(
        modifier = Modifier
            .size(72.dp)
            .clip(CircleShape)
            .background((if (isDark) NeonCyan else GoldPrimary).copy(alpha = 0.13f)),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Filled.Security,
            contentDescription = "安全锁",
            tint = if (isDark) NeonCyan else GoldPrimary,
            modifier = Modifier.size(34.dp)
        )
    }
}

@Composable
private fun UnlockContent(
    isDark: Boolean,
    failedAttempts: Int,
    biometricEnabled: Boolean,
    onForgotPassword: () -> Unit
) {
    val context = LocalContext.current
    var password by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val biometricLabel = remember(biometricEnabled) { BiometricAuthHelper.modalityLabel(context) }
    val biometricUnlockLabel = remember(biometricEnabled) { BiometricAuthHelper.unlockLabel(context) }
    val biometricAvailable = remember(biometricEnabled) {
        biometricEnabled && BiometricAuthHelper.canAuthenticate(context)
    }

    Text("应用已锁定", style = MaterialTheme.typography.headlineSmall)
    Spacer(modifier = Modifier.height(4.dp))
    Text(
        text = "请输入数字密码，或使用${biometricLabel}解锁",
        fontSize = 13.sp,
        color = if (isDark) TextGray else TextMuted,
        textAlign = TextAlign.Center
    )
    Spacer(modifier = Modifier.height(18.dp))

    OutlinedTextField(
        value = password,
        onValueChange = { password = it.filter(Char::isDigit).take(12) },
        label = { Text("数字密码") },
        singleLine = true,
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
        modifier = Modifier.fillMaxWidth(),
        colors = securityTextFieldColors(isDark)
    )
    if (failedAttempts > 0) {
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "密码错误 $failedAttempts 次${if (failedAttempts >= 5) "，请稍后再试" else ""}",
            color = if (isDark) NeonRed else Color(0xFFD32F2F),
            fontSize = 12.sp,
            modifier = Modifier.fillMaxWidth()
        )
    }

    Spacer(modifier = Modifier.height(16.dp))
    Button(
        onClick = {
            val result = SecurityLockManager.verifyPassword(context, password)
            Toast.makeText(context, result.message, Toast.LENGTH_SHORT).show()
            if (result.success) {
                password = ""
            }
        },
        enabled = password.isNotBlank() && !busy,
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(
            containerColor = if (isDark) NeonCyan else GoldPrimary,
            contentColor = if (isDark) DarkBg else Color.White
        )
    ) {
        Icon(Icons.Filled.Lock, contentDescription = "解锁", modifier = Modifier.size(17.dp))
        Spacer(modifier = Modifier.width(6.dp))
        Text("解锁", fontWeight = FontWeight.Bold)
    }

    if (biometricEnabled) {
        Spacer(modifier = Modifier.height(10.dp))
        OutlinedButton(
            onClick = {
                val activity = context.findFragmentActivity()
                if (activity == null) {
                    Toast.makeText(context, "当前页面无法调起生物识别解锁", Toast.LENGTH_SHORT).show()
                    return@OutlinedButton
                }
                if (!biometricAvailable) {
                    Toast.makeText(context, BiometricAuthHelper.availabilityMessage(context), Toast.LENGTH_SHORT).show()
                    return@OutlinedButton
                }
                busy = true
                BiometricAuthHelper.authenticate(
                    activity = activity,
                    title = "${biometricLabel}解锁",
                    subtitle = "验证通过后解锁卡包",
                    onSuccess = {
                        busy = false
                        SecurityLockManager.unlock(context)
                        Toast.makeText(context, "解锁成功", Toast.LENGTH_SHORT).show()
                    },
                    onError = { message ->
                        busy = false
                        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                    }
                )
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = !busy
        ) {
            if (busy) {
                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
            } else {
                Icon(Icons.Filled.Fingerprint, contentDescription = biometricLabel, modifier = Modifier.size(18.dp))
            }
            Spacer(modifier = Modifier.width(6.dp))
            Text(if (biometricAvailable) biometricUnlockLabel else "${biometricLabel}不可用")
        }
    }

    Spacer(modifier = Modifier.height(12.dp))
    TextButton(onClick = onForgotPassword) {
        Icon(Icons.Filled.LockReset, contentDescription = "找回密码", modifier = Modifier.size(17.dp))
        Spacer(modifier = Modifier.width(5.dp))
        Text("忘记密码？重新设置")
    }
}

@Composable
private fun RecoveryContent(
    isDark: Boolean,
    onBack: () -> Unit,
    onVerified: () -> Unit
) {
    val context = LocalContext.current
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var questions by remember { mutableStateOf<List<SecurityRecoveryQuestion>>(emptyList()) }
    var answers by remember { mutableStateOf<List<String>>(emptyList()) }
    var results by remember { mutableStateOf<List<Boolean?>>(emptyList()) }
    val scope = rememberCoroutineScope()

    suspend fun loadQuestions() {
        loading = true
        error = null
        runCatching {
            withContext(Dispatchers.IO) {
                SecurityLockManager.generateRecoveryQuestions(context)
            }
        }.onSuccess { generated ->
            questions = generated
            answers = List(generated.size) { "" }
            results = List(generated.size) { null }
        }.onFailure {
            error = it.message ?: "无法生成找回问题"
        }
        loading = false
    }

    LaunchedEffect(Unit) {
        loadQuestions()
    }

    Text("找回密码", style = MaterialTheme.typography.headlineSmall)
    Spacer(modifier = Modifier.height(4.dp))
    Text(
        text = "请回答 3 个已保存卡片相关问题，全部正确后可设置新密码",
        fontSize = 12.sp,
        lineHeight = 17.sp,
        color = if (isDark) TextGray else TextMuted,
        textAlign = TextAlign.Center
    )
    Spacer(modifier = Modifier.height(16.dp))

    when {
        loading -> {
            CircularProgressIndicator(
                modifier = Modifier.size(26.dp),
                color = if (isDark) NeonCyan else GoldPrimary,
                strokeWidth = 3.dp
            )
        }
        error != null -> {
            Text(
                text = error.orEmpty(),
                color = if (isDark) NeonRed else Color(0xFFD32F2F),
                fontSize = 13.sp,
                textAlign = TextAlign.Center
            )
        }
        else -> {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                questions.forEachIndexed { index, question ->
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(if (isDark) DarkBg else LightBg)
                            .padding(12.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "问题 ${index + 1}",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (isDark) NeonCyan else GoldPrimary
                            )
                            results.getOrNull(index)?.let { ok ->
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = if (ok) "回答正确" else "回答错误",
                                    fontSize = 11.sp,
                                    color = if (ok) {
                                        if (isDark) NeonGreen else Color(0xFF2E7D32)
                                    } else {
                                        if (isDark) NeonRed else Color(0xFFD32F2F)
                                    }
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(5.dp))
                        Text(question.question, fontSize = 13.sp, lineHeight = 18.sp)
                        Spacer(modifier = Modifier.height(8.dp))
                        OutlinedTextField(
                            value = answers.getOrNull(index).orEmpty(),
                            onValueChange = { value ->
                                answers = answers.toMutableList().also { it[index] = value }
                                results = results.toMutableList().also { it[index] = null }
                            },
                            placeholder = { Text(question.placeholder) },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                            colors = securityTextFieldColors(isDark)
                        )
                    }
                }
            }
        }
    }

    Spacer(modifier = Modifier.height(16.dp))
    HorizontalDivider(color = (if (isDark) TextGray else TextMuted).copy(alpha = 0.14f))
    Spacer(modifier = Modifier.height(12.dp))

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.weight(1f)
        ) {
            Text("返回")
        }
        OutlinedButton(
            onClick = {
                scope.launch { loadQuestions() }
            },
            modifier = Modifier.weight(1f),
            enabled = !loading
        ) {
            Icon(Icons.Filled.Refresh, contentDescription = "刷新问题", modifier = Modifier.size(16.dp))
            Spacer(modifier = Modifier.width(4.dp))
            Text("刷新")
        }
        Button(
            onClick = {
                if (answers.any { it.trim().isBlank() }) {
                    Toast.makeText(context, "请回答所有问题", Toast.LENGTH_SHORT).show()
                    return@Button
                }
                val verifyResults = SecurityLockManager.verifyRecoveryAnswers(questions, answers)
                results = verifyResults
                if (verifyResults.all { it }) {
                    Toast.makeText(context, "验证成功，请设置新密码", Toast.LENGTH_SHORT).show()
                    onVerified()
                } else {
                    Toast.makeText(context, "有问题回答错误，请修改后重试", Toast.LENGTH_SHORT).show()
                }
            },
            modifier = Modifier.weight(1.15f),
            enabled = !loading && error == null && questions.isNotEmpty(),
            colors = ButtonDefaults.buttonColors(
                containerColor = if (isDark) NeonCyan else GoldPrimary,
                contentColor = if (isDark) DarkBg else Color.White
            )
        ) {
            Text("验证")
        }
    }
}

@Composable
private fun ResetPasswordContent(
    isDark: Boolean,
    title: String,
    subtitle: String,
    onDone: () -> Unit,
    onCancel: () -> Unit
) {
    val context = LocalContext.current
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }

    Text(title, style = MaterialTheme.typography.headlineSmall)
    Spacer(modifier = Modifier.height(4.dp))
    Text(
        text = subtitle,
        fontSize = 12.sp,
        color = if (isDark) TextGray else TextMuted,
        textAlign = TextAlign.Center
    )
    Spacer(modifier = Modifier.height(16.dp))

    PasswordInput(
        value = password,
        onValueChange = { password = it },
        label = "新数字密码",
        isDark = isDark
    )
    Spacer(modifier = Modifier.height(10.dp))
    PasswordInput(
        value = confirmPassword,
        onValueChange = { confirmPassword = it },
        label = "确认数字密码",
        isDark = isDark
    )
    Spacer(modifier = Modifier.height(16.dp))

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        OutlinedButton(
            onClick = onCancel,
            modifier = Modifier.weight(1f)
        ) {
            Text("取消")
        }
        Button(
            onClick = {
                if (password != confirmPassword) {
                    Toast.makeText(context, "两次输入的密码不一致", Toast.LENGTH_SHORT).show()
                    return@Button
                }
                val result = SecurityLockManager.setPassword(context, password)
                Toast.makeText(context, result.message, Toast.LENGTH_SHORT).show()
                if (result.success) {
                    SecurityLockManager.unlock(context)
                    onDone()
                }
            },
            modifier = Modifier.weight(1.2f),
            colors = ButtonDefaults.buttonColors(
                containerColor = if (isDark) NeonCyan else GoldPrimary,
                contentColor = if (isDark) DarkBg else Color.White
            )
        ) {
            Text("保存新密码")
        }
    }
}

@Composable
private fun PasswordInput(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    isDark: Boolean
) {
    OutlinedTextField(
        value = value,
        onValueChange = { onValueChange(it.filter(Char::isDigit).take(12)) },
        label = { Text(label) },
        singleLine = true,
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
        modifier = Modifier.fillMaxWidth(),
        colors = securityTextFieldColors(isDark)
    )
}

@Composable
private fun securityTextFieldColors(isDark: Boolean) = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = if (isDark) NeonCyan else GoldPrimary,
    focusedLabelColor = if (isDark) NeonCyan else GoldPrimary,
    cursorColor = if (isDark) NeonCyan else GoldPrimary,
    focusedContainerColor = if (isDark) DarkBg else Color.White,
    unfocusedContainerColor = if (isDark) DarkBg else Color.White,
    focusedTextColor = MaterialTheme.colorScheme.onSurface,
    unfocusedTextColor = MaterialTheme.colorScheme.onSurface,
    unfocusedBorderColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.32f),
    focusedPlaceholderColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.7f),
    unfocusedPlaceholderColor = (if (isDark) TextGray else TextMuted).copy(alpha = 0.7f)
)
