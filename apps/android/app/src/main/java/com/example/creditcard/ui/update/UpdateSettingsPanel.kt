package com.example.creditcard.ui.update

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SystemUpdate
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.creditcard.R
import com.example.creditcard.ui.components.AppBackButton
import com.example.creditcard.ui.components.WalletSection
import com.example.creditcard.update.*
import java.util.Locale

// Activity 持有同一个更新器，设置页与提示窗共享下载状态。
val LocalAppUpdater = staticCompositionLocalOf<AppUpdater> { error("AppUpdater is not provided") }

@Composable
fun AppUpdateHost(locked: Boolean) {
    val updater = LocalAppUpdater.current
    val state by updater.state.collectAsStateWithLifecycle()
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { if (!locked) updater.checkAutomatically() }
    LaunchedEffect(locked) { if (!locked) updater.checkAutomatically() }
    if (locked || !state.showDialog || state.release == null) return
    val release = state.release!!
    AlertDialog(
        onDismissRequest = updater::dismissDialog,
        icon = { Icon(Icons.Default.SystemUpdate, null) },
        title = { Text(stringResource(R.string.update_available, release.versionName)) },
        text = {
            Column(Modifier.heightIn(max = 340.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(release.notes.ifBlank { stringResource(R.string.update_no_notes) },
                    style = MaterialTheme.typography.bodyMedium)
                Text(stringResource(R.string.update_size, String.format(Locale.getDefault(), "%.1f", release.asset.size / 1048576.0)),
                    style = MaterialTheme.typography.bodySmall)
                Text(stringResource(R.string.update_install_desc), style = MaterialTheme.typography.bodySmall)
                UpdateStatus(state)
            }
        },
        confirmButton = { UpdateAction(state, updater) },
        dismissButton = {
            TextButton(onClick = updater::dismissDialog) { Text(stringResource(R.string.update_later)) }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UpdateSettingsPanel(onBack: () -> Unit) {
    val updater = LocalAppUpdater.current
    val state by updater.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.update_title)) },
            navigationIcon = { AppBackButton(onBack) },
            windowInsets = WindowInsets(0, 0, 0, 0),
            colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background)
        )
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Surface(shape = MaterialTheme.shapes.large, color = MaterialTheme.colorScheme.primaryContainer) {
                Column(Modifier.fillMaxWidth().padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Icons.Default.SystemUpdate, null, Modifier.size(40.dp),
                        tint = MaterialTheme.colorScheme.onPrimaryContainer)
                    Text(stringResource(R.string.app_name), style = MaterialTheme.typography.headlineSmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer)
                    Text(stringResource(R.string.update_current, updater.currentVersion),
                        color = MaterialTheme.colorScheme.onPrimaryContainer)
                }
            }
            WalletSection(stringResource(R.string.update_auto)) {
                val automaticLabel = stringResource(R.string.update_auto)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.update_auto_desc), Modifier.weight(1f),
                        style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.width(12.dp))
                    Switch(checked = state.automatic, onCheckedChange = updater::setAutomatic,
                        modifier = Modifier.semantics { contentDescription = automaticLabel })
                }
            }
            WalletSection(stringResource(R.string.update_title)) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    UpdateStatus(state)
                    state.release?.let {
                        Text(stringResource(R.string.update_available, it.versionName),
                            style = MaterialTheme.typography.titleMedium)
                        Text(stringResource(R.string.update_size, String.format(Locale.getDefault(), "%.1f", it.asset.size / 1048576.0)),
                            style = MaterialTheme.typography.bodySmall)
                        Text(it.notes.ifBlank { stringResource(R.string.update_no_notes) },
                            style = MaterialTheme.typography.bodyMedium)
                    }
                    UpdateAction(state, updater)
                    Text(stringResource(R.string.update_source), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    TextButton(onClick = {
                        try {
                            context.startActivity(Intent(Intent.ACTION_VIEW,
                                Uri.parse("https://github.com/$UPDATE_REPOSITORY/releases")))
                        } catch (_: Exception) { updater.reportPermissionFailure() }
                    }) { Text(stringResource(R.string.update_release_page)) }
                }
            }
        }
    }
}

@Composable
private fun UpdateStatus(state: UpdateState) {
    when (state.phase) {
        UpdatePhase.CHECKING -> Row(verticalAlignment = Alignment.CenterVertically) {
            CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
            Spacer(Modifier.width(12.dp))
            Text(stringResource(R.string.update_checking))
        }
        UpdatePhase.CURRENT -> Text(stringResource(R.string.update_latest))
        UpdatePhase.DOWNLOADING -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(stringResource(R.string.update_downloading, state.progress))
            LinearProgressIndicator(progress = { state.progress / 100f }, modifier = Modifier.fillMaxWidth())
        }
        UpdatePhase.READY -> Text(stringResource(R.string.update_ready))
        else -> Unit
    }
    state.message?.let { Text(stringResource(it), color = MaterialTheme.colorScheme.error) }
}

@Composable
private fun UpdateAction(state: UpdateState, updater: AppUpdater) {
    val context = LocalContext.current
    var needsPermission by remember { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        // 返回权限页后仍保留明确的“安装更新”按钮，不在恢复前台时擅自拉起安装。
        needsPermission = !updater.canInstall()
    }
    when (state.phase) {
        UpdatePhase.CHECKING -> Unit
        UpdatePhase.DOWNLOADING -> TextButton(onClick = updater::cancelDownload) {
            Text(stringResource(R.string.update_cancel))
        }
        UpdatePhase.READY -> Column {
            if (needsPermission) Text(stringResource(R.string.update_permission_desc),
                style = MaterialTheme.typography.bodySmall)
            Button(onClick = {
                if (updater.canInstall()) {
                    needsPermission = false
                    updater.install(context)
                } else {
                    needsPermission = true
                    try { permissionLauncher.launch(updater.permissionIntent()) }
                    catch (_: Exception) { updater.reportPermissionFailure() }
                }
            }) { Text(stringResource(R.string.update_install)) }
        }
        else -> Button(onClick = {
            if (state.release != null) updater.download() else updater.check()
        }) {
            Text(stringResource(if (state.release != null) R.string.update_download else R.string.update_check))
        }
    }
}
