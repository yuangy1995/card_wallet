package com.example.creditcard.ui.main

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material.icons.filled.LockReset
import androidx.compose.material.icons.filled.Password
import androidx.compose.material.icons.filled.Security
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.creditcard.theme.DarkBg
import com.example.creditcard.theme.ForestGreen
import com.example.creditcard.theme.GoldPrimary
import com.example.creditcard.theme.LightBg
import com.example.creditcard.theme.NeonCyan
import com.example.creditcard.theme.NeonGreen
import com.example.creditcard.theme.NeonRed
import com.example.creditcard.theme.TextGray
import com.example.creditcard.theme.TextMuted
import com.example.creditcard.ui.components.AppBackButton
import com.example.creditcard.utils.BiometricAuthHelper
import com.example.creditcard.utils.SecurityLockManager
import com.example.creditcard.utils.findFragmentActivity

@Composable
fun SettingsSecurityPanel(
    isDark: Boolean,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val state by SecurityLockManager.state.collectAsState()
    val biometricAvailable = remember(state.enabled, state.biometricEnabled) {
        BiometricAuthHelper.canAuthenticate(context)
    }
    val biometricLabel = remember(state.enabled, state.biometricEnabled) {
        BiometricAuthHelper.modalityLabel(context)
    }
    val biometricUnlockLabel = remember(state.enabled, state.biometricEnabled) {
        BiometricAuthHelper.unlockLabel(context)
    }
    val accent = if (isDark) NeonCyan else GoldPrimary
    var newPassword by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var disableDialogVisible by remember { mutableStateOf(false) }
    var disablePassword by remember { mutableStateOf("") }

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
            AppBackButton(
                onClick = onBack,
                contentDescription = "返回设置",
                tint = accent,
                containerColor = MaterialTheme.colorScheme.surface,
                borderColor = accent.copy(alpha = 0.34f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text("安全设置", style = MaterialTheme.typography.headlineSmall)
                Text(
                    text = "数字密码、生物识别解锁与找回密码",
                    fontSize = 12.sp,
                    color = accent,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        DetailSection(title = "安全锁状态") {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (isDark) DarkBg else LightBg)
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = if (state.enabled) Icons.Filled.Lock else Icons.Filled.LockOpen,
                    contentDescription = "安全锁状态",
                    tint = if (state.enabled) {
                        if (isDark) NeonGreen else ForestGreen
                    } else {
                        if (isDark) TextGray else TextMuted
                    },
                    modifier = Modifier.size(28.dp)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (state.enabled) "安全锁已开启" else "安全锁未开启",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = if (state.enabled) {
                            if (state.biometricEnabled) "可使用数字密码或${biometricLabel}解锁" else "可使用数字密码解锁"
                        } else {
                            "默认关闭，设置数字密码后才会启用"
                        },
                        fontSize = 11.sp,
                        color = if (isDark) TextGray else TextMuted,
                        lineHeight = 15.sp
                    )
                }
            }
        }

        if (!state.enabled) {
            DetailSection(title = "开启安全锁") {
                Text(
                    text = "设置至少 6 位数字密码后，应用会在再次进入时要求解锁。找回密码会从已保存卡片数据中随机出题。",
                    fontSize = 12.sp,
                    lineHeight = 17.sp,
                    color = if (isDark) TextGray else TextMuted
                )
                Spacer(modifier = Modifier.height(12.dp))
                SecurityPasswordField(
                    value = newPassword,
                    onValueChange = { newPassword = it },
                    label = "数字密码",
                    isDark = isDark
                )
                Spacer(modifier = Modifier.height(10.dp))
                SecurityPasswordField(
                    value = confirmPassword,
                    onValueChange = { confirmPassword = it },
                    label = "确认数字密码",
                    isDark = isDark
                )
                Spacer(modifier = Modifier.height(14.dp))
                Button(
                    onClick = {
                        if (newPassword != confirmPassword) {
                            Toast.makeText(context, "两次输入的密码不一致", Toast.LENGTH_SHORT).show()
                            return@Button
                        }
                        val result = SecurityLockManager.setPassword(context, newPassword)
                        Toast.makeText(context, result.message, Toast.LENGTH_SHORT).show()
                        if (result.success) {
                            newPassword = ""
                            confirmPassword = ""
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = accent,
                        contentColor = if (isDark) DarkBg else Color.White
                    )
                ) {
                    Icon(Icons.Filled.Security, contentDescription = "开启安全锁", modifier = Modifier.size(17.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("开启安全锁", fontWeight = FontWeight.Bold)
                }
            }
        } else {
            DetailSection(title = "修改数字密码") {
                SecurityPasswordField(
                    value = newPassword,
                    onValueChange = { newPassword = it },
                    label = "新数字密码",
                    isDark = isDark
                )
                Spacer(modifier = Modifier.height(10.dp))
                SecurityPasswordField(
                    value = confirmPassword,
                    onValueChange = { confirmPassword = it },
                    label = "确认新密码",
                    isDark = isDark
                )
                Spacer(modifier = Modifier.height(14.dp))
                Button(
                    onClick = {
                        if (newPassword != confirmPassword) {
                            Toast.makeText(context, "两次输入的密码不一致", Toast.LENGTH_SHORT).show()
                            return@Button
                        }
                        val result = SecurityLockManager.setPassword(context, newPassword)
                        Toast.makeText(context, if (result.success) "密码已更新" else result.message, Toast.LENGTH_SHORT).show()
                        if (result.success) {
                            newPassword = ""
                            confirmPassword = ""
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = accent,
                        contentColor = if (isDark) DarkBg else Color.White
                    )
                ) {
                    Icon(Icons.Filled.Password, contentDescription = "修改密码", modifier = Modifier.size(17.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("保存新密码", fontWeight = FontWeight.Bold)
                }
            }

            DetailSection(title = "${biometricLabel}解锁") {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(if (isDark) DarkBg else LightBg)
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Filled.Fingerprint,
                        contentDescription = "${biometricLabel}解锁",
                        tint = accent,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(biometricUnlockLabel, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                        Text(
                            text = BiometricAuthHelper.availabilityMessage(context),
                            fontSize = 11.sp,
                            lineHeight = 15.sp,
                            color = if (biometricAvailable) {
                                if (isDark) TextGray else TextMuted
                            } else {
                                if (isDark) NeonRed else Color(0xFFD32F2F)
                            }
                        )
                    }
                    Switch(
                        checked = state.biometricEnabled,
                        enabled = biometricAvailable,
                        onCheckedChange = { enabled ->
                            if (!enabled) {
                                SecurityLockManager.setBiometricEnabled(context, false)
                                Toast.makeText(context, "${biometricLabel}解锁已关闭", Toast.LENGTH_SHORT).show()
                                return@Switch
                            }
                            val activity = context.findFragmentActivity()
                            if (activity == null) {
                                Toast.makeText(context, "当前页面无法调起生物识别验证", Toast.LENGTH_SHORT).show()
                                return@Switch
                            }
                            BiometricAuthHelper.authenticate(
                                activity = activity,
                                title = "开启${biometricLabel}解锁",
                                subtitle = "请验证本机身份，验证通过后启用",
                                negativeButtonText = "取消",
                                onSuccess = {
                                    SecurityLockManager.setBiometricEnabled(context, true)
                                    Toast.makeText(context, "${biometricLabel}解锁已开启", Toast.LENGTH_SHORT).show()
                                },
                                onError = { message ->
                                    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                                }
                            )
                        },
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = accent,
                            checkedTrackColor = accent.copy(alpha = 0.3f)
                        )
                    )
                }
            }

            DetailSection(title = "安全操作") {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedButton(
                        onClick = {
                            SecurityLockManager.lock(context)
                            Toast.makeText(context, "应用已锁定", Toast.LENGTH_SHORT).show()
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Filled.Lock, contentDescription = "立即锁定", modifier = Modifier.size(17.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("立即锁定")
                    }
                    OutlinedButton(
                        onClick = { disableDialogVisible = true },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = if (isDark) NeonRed else Color(0xFFD32F2F)
                        )
                    ) {
                        Icon(Icons.Filled.LockReset, contentDescription = "关闭安全锁", modifier = Modifier.size(17.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("关闭安全锁")
                    }
                    HorizontalDivider(color = (if (isDark) TextGray else TextMuted).copy(alpha = 0.14f))
                    Text(
                        text = "忘记密码时，可在解锁界面点击“忘记密码？重新设置”，通过已保存卡片数据随机问题验证后设置新密码。",
                        fontSize = 11.sp,
                        lineHeight = 16.sp,
                        color = if (isDark) TextGray else TextMuted,
                        textAlign = TextAlign.Start
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(36.dp))
    }

    if (disableDialogVisible) {
        AlertDialog(
            onDismissRequest = {
                disableDialogVisible = false
                disablePassword = ""
            },
            title = { Text("关闭安全锁") },
            text = {
                Column {
                    Text("请输入当前数字密码确认关闭。关闭后应用不会再显示解锁界面。")
                    Spacer(modifier = Modifier.height(12.dp))
                    SecurityPasswordField(
                        value = disablePassword,
                        onValueChange = { disablePassword = it },
                        label = "当前数字密码",
                        isDark = isDark
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val result = SecurityLockManager.verifyPassword(context, disablePassword)
                        if (!result.success) {
                            Toast.makeText(context, result.message, Toast.LENGTH_SHORT).show()
                            return@TextButton
                        }
                        SecurityLockManager.clearSecurityData(context)
                        Toast.makeText(context, "安全锁已关闭", Toast.LENGTH_SHORT).show()
                        disablePassword = ""
                        disableDialogVisible = false
                    }
                ) {
                    Text("确认关闭", color = if (isDark) NeonRed else Color(0xFFD32F2F))
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        disableDialogVisible = false
                        disablePassword = ""
                    }
                ) {
                    Text("取消")
                }
            }
        )
    }
}

@Composable
private fun SecurityPasswordField(
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
        colors = getOutlinedTextFieldColors(isDark)
    )
}
