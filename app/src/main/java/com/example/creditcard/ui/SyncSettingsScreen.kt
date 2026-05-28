package com.example.creditcard.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CloudSync
import androidx.compose.material.icons.filled.NetworkCheck
import androidx.compose.material.icons.filled.Save
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.graphics.Color
import com.example.creditcard.theme.*
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager
import com.example.creditcard.utils.WebDAVClient
import com.example.creditcard.utils.WebDAVConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SyncSettingsScreen(
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val isDark by ThemeManager.isDarkTheme.collectAsState()

    // 加载已有配置
    val loadedConfig = remember { SyncCoordinator.loadConfig(context) }

    var url by remember { mutableStateOf(loadedConfig.url) }
    var user by remember { mutableStateOf(loadedConfig.user) }
    var pass by remember { mutableStateOf(loadedConfig.pass) }
    var isEnabled by remember { mutableStateOf(loadedConfig.isEnabled) }

    // 测试连接与立即同步的加载状态
    var isTestingConnection by remember { mutableStateOf(false) }
    val syncStatus by SyncCoordinator.syncStatus.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("云同步备份设置", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(imageVector = Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
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
            // Section 1: 📡 WebDAV 配置填报
            // ==========================================
            DetailSection(title = "📡 WebDAV 云配置参数") {
                OutlinedTextField(
                    value = url,
                    onValueChange = { url = it },
                    label = { Text("WebDAV 服务器 URL (带 https://)") },
                    placeholder = { Text("https://dav.jianguoyun.com/dav") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = getOutlinedTextFieldColors(isDark)
                )

                Spacer(modifier = Modifier.height(10.dp))

                OutlinedTextField(
                    value = user,
                    onValueChange = { user = it },
                    label = { Text("用户名 (Email 账号)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = getOutlinedTextFieldColors(isDark)
                )

                Spacer(modifier = Modifier.height(10.dp))

                OutlinedTextField(
                    value = pass,
                    onValueChange = { pass = it },
                    label = { Text("应用独立安全密码") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth(),
                    colors = getOutlinedTextFieldColors(isDark)
                )

                Spacer(modifier = Modifier.height(16.dp))

                // 是否启用云同步开关
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("开启双向自动同步", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(
                            "开启后应用将在启动、改动卡片时自动在后台执行 LWW CRDT 双向无冲突合流，保留最近 5 次快照",
                            fontSize = 11.sp,
                            color = if (isDark) TextGray else TextMuted
                        )
                    }
                    Switch(
                        checked = isEnabled,
                        onCheckedChange = { isEnabled = it },
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = if (isDark) NeonCyan else GoldPrimary,
                            checkedTrackColor = if (isDark) NeonCyan.copy(alpha = 0.3f) else GoldPrimary.copy(alpha = 0.3f)
                        )
                    )
                }
            }

            // ==========================================
            // Section 2: ⚙️ 同步工具与状态面板
            // ==========================================
            DetailSection(title = "⚙️ 控制台与状态") {
                // 当前状态文本
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (isDark) DarkBg else LightBg)
                        .padding(12.dp)
                ) {
                    Column {
                        Text(
                            text = "当前同步状态：",
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp,
                            color = if (isDark) TextGray else TextMuted
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = syncStatus.message,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onBackground
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // 1. 测试连接按钮
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
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), color = if (isDark) DarkBg else Color.White, strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("正在进行线路检测...")
                    } else {
                        Icon(imageVector = Icons.Filled.NetworkCheck, contentDescription = "测试连接")
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("连接测试 (PROPFIND)")
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // 2. 立即双向同步按钮
                Button(
                    onClick = {
                        if (!isEnabled) {
                            Toast.makeText(context, "请先开启云同步开关并保存配置", Toast.LENGTH_SHORT).show()
                            return@Button
                        }
                        coroutineScope.launch {
                            SyncCoordinator.synchronize(context, publishLocalChanges = true)
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = isEnabled && !syncStatus.isSyncing,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isDark) NeonCyan else GoldPrimary,
                        contentColor = if (isDark) DarkBg else Color.White
                    )
                ) {
                    if (syncStatus.isSyncing) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), color = if (isDark) DarkBg else Color.White, strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("双向合流中...")
                    } else {
                        Icon(imageVector = Icons.Filled.CloudSync, contentDescription = "立即同步")
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("立即强制双向同步 (Force Sync)")
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // 3. 保存配置按钮
                Button(
                    onClick = {
                        if (isEnabled && (url.trim().isEmpty() || user.trim().isEmpty() || pass.trim().isEmpty())) {
                            Toast.makeText(context, "开启同步时，必须填齐所有云参数", Toast.LENGTH_SHORT).show()
                            return@Button
                        }
                        
                        val newConfig = WebDAVConfig(url.trim(), user.trim(), pass.trim(), isEnabled)
                        SyncCoordinator.saveConfig(context, newConfig)
                        Toast.makeText(context, "同步配置已成功应用并保存", Toast.LENGTH_SHORT).show()
                        
                        // 保存配置后，若开启了同步，立刻触发后台静默合流，极致爽滑！
                        if (isEnabled) {
                            coroutineScope.launch {
                                SyncCoordinator.synchronize(context, publishLocalChanges = false)
                            }
                        }
                        onBack()
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !syncStatus.isSyncing,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isDark) NeonGreen else ForestGreen,
                        contentColor = Color.White
                    )
                ) {
                    Icon(imageVector = Icons.Filled.Save, contentDescription = "保存配置")
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("保存并应用云配置")
                }
            }

            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}
