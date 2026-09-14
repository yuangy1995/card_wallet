package com.example.creditcard.ui.wallet

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.creditcard.R
import com.example.creditcard.ui.components.WalletSection
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.SyncNetworkPreference
import com.example.creditcard.utils.WebDAVClient
import com.example.creditcard.utils.WebDAVConfig
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun WalletSyncSettings(onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var saved by remember { mutableStateOf(SyncCoordinator.loadConfig(context)) }
    // Do not persist plaintext passwords in a saved-instance-state Bundle.
    var draft by remember { mutableStateOf(saved.copy(isEnabled = true)) }
    var editing by remember { mutableStateOf(!saved.isReadyForSync) }
    var testing by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<Int?>(null) }
    var testPassed by remember { mutableStateOf<Boolean?>(null) }
    val status by SyncCoordinator.syncStatus.collectAsState()
    val progress by SyncCoordinator.syncProgress.collectAsState()
    fun cancelEdit() { draft = saved.copy(isEnabled = true); editing = false; error = null; testPassed = null }
    BackHandler(enabled = editing && saved.isReadyForSync) { cancelEdit() }

    Scaffold(topBar = {
        TopAppBar(title = { Text(stringResource(if (editing) R.string.wallet_sync_edit else R.string.settings_sync),
            style = MaterialTheme.typography.titleLarge, maxLines = 1) },
            navigationIcon = { IconButton(onClick = { if (editing && saved.isReadyForSync) cancelEdit() else onBack() }) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
            } }, colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background))
    }, contentWindowInsets = WindowInsets(0, 0, 0, 0)) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).imePadding().verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (!editing) {
                WalletSection("") {
                    Row(Modifier.fillMaxWidth().padding(top = 16.dp), verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(if (status.type == "error") Icons.Default.CloudOff else Icons.Default.CloudQueue,
                            null, Modifier.size(32.dp), tint = MaterialTheme.colorScheme.primary)
                        Column(Modifier.weight(1f)) {
                            Text(stringResource(when { status.isSyncing -> R.string.wallet_sync_busy
                                status.type == "error" -> R.string.wallet_sync_error
                                status.type == "success" && !status.pending -> R.string.wallet_sync_current
                                else -> R.string.wallet_sync_configured }), style = MaterialTheme.typography.titleMedium)
                            Text(stringResource(R.string.wallet_sync_always_on), style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                    SyncInfoRow(stringResource(R.string.wallet_sync_server), Uri.parse(saved.url).host.orEmpty())
                    SyncInfoRow(stringResource(R.string.wallet_sync_user), saved.user)
                    if (status.isSyncing) {
                        Spacer(Modifier.height(12.dp))
                        if (progress.total > 0) LinearProgressIndicator(progress = { progress.step.toFloat() / progress.total },
                            modifier = Modifier.fillMaxWidth())
                        else LinearProgressIndicator(Modifier.fillMaxWidth())
                        Text(status.message, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp))
                    } else if (status.type == "error" || status.pending) {
                        Text(status.message, style = MaterialTheme.typography.bodySmall,
                            color = if (status.type == "error") MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 12.dp))
                    }
                    Spacer(Modifier.height(16.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(onClick = { SyncCoordinator.requestManualSync(context) }, enabled = !status.isSyncing,
                            modifier = Modifier.weight(1f)) { Text(stringResource(R.string.wallet_sync_now), maxLines = 1) }
                        OutlinedButton(onClick = { draft = saved.copy(isEnabled = true); editing = true; testPassed = null },
                            enabled = !status.isSyncing, modifier = Modifier.weight(1f)) {
                            Text(stringResource(R.string.wallet_sync_edit), maxLines = 1)
                        }
                    }
                    if (status.isSyncing) TextButton(onClick = { SyncCoordinator.cancelCurrentSync(context) }) {
                        Text(stringResource(R.string.wallet_sync_cancel_run))
                    }
                }
                WalletSection(stringResource(R.string.wallet_sync_network)) {
                    WalletSyncNetworkSelector(saved.networkPreference) { choice ->
                        saved = saved.copy(networkPreference = choice, isEnabled = true)
                        SyncCoordinator.saveConfig(context, saved)
                    }
                }
            } else {
                WalletSection(stringResource(R.string.wallet_sync_server)) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        OutlinedTextField(draft.url, { draft = draft.copy(url = it); error = null; testPassed = null },
                            label = { Text(stringResource(R.string.wallet_sync_url)) }, singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Next),
                            enabled = !testing, modifier = Modifier.fillMaxWidth().testTag("sync_url"), shape = RoundedCornerShape(12.dp))
                        OutlinedTextField(draft.user, { draft = draft.copy(user = it); error = null; testPassed = null },
                            label = { Text(stringResource(R.string.wallet_sync_user)) }, singleLine = true,
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next), enabled = !testing,
                            modifier = Modifier.fillMaxWidth().testTag("sync_user"), shape = RoundedCornerShape(12.dp))
                        WalletSecretField(draft.pass, { draft = draft.copy(pass = it); error = null; testPassed = null },
                            stringResource(R.string.wallet_sync_password), enabled = !testing)
                    }
                }
                WalletSection(stringResource(R.string.wallet_sync_key)) {
                    WalletSecretField(draft.syncPassword, { draft = draft.copy(syncPassword = it); error = null },
                        stringResource(R.string.wallet_sync_key), enabled = !testing)
                    Text(stringResource(R.string.wallet_sync_key_hint), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
                }
                WalletSection(stringResource(R.string.wallet_sync_network)) {
                    WalletSyncNetworkSelector(draft.networkPreference) { draft = draft.copy(networkPreference = it) }
                    Text(stringResource(R.string.wallet_sync_always_on), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
                }
                error?.let { Text(stringResource(it), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium) }
                testPassed?.let { Text(stringResource(if (it) R.string.wallet_sync_test_success else R.string.wallet_sync_test_failed),
                    color = if (it) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error) }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedButton(onClick = {
                        val candidate = draft.copy(url = draft.url.trim(), user = draft.user.trim(), isEnabled = true)
                        val address = Uri.parse(candidate.url)
                        if (candidate.url.isBlank() || candidate.user.isBlank() || candidate.pass.isBlank() ||
                            address.scheme !in listOf("https", "http") || address.host.isNullOrBlank() || address.userInfo != null) {
                            error = R.string.wallet_sync_invalid; return@OutlinedButton
                        }
                        testing = true; testPassed = null
                        scope.launch {
                            try {
                                val outcome = withContext(Dispatchers.IO) { WebDAVClient.testConnection(candidate.url, candidate.user, candidate.pass) }
                                testPassed = outcome.first
                            } catch (cancelled: CancellationException) { throw cancelled
                            } catch (_: Exception) { testPassed = false
                            } finally { testing = false }
                        }
                    }, enabled = !testing && !status.isSyncing, modifier = Modifier.weight(1f)) {
                        if (testing) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                        else Text(stringResource(R.string.wallet_sync_test), maxLines = 1)
                    }
                    Button(onClick = {
                        val candidate = draft.copy(url = draft.url.trim(), user = draft.user.trim(), syncPassword = draft.syncPassword.trim(), isEnabled = true)
                        val address = Uri.parse(candidate.url)
                        if (!candidate.isReadyForSync || address.scheme !in listOf("https", "http") ||
                            address.host.isNullOrBlank() || address.userInfo != null) {
                            error = R.string.wallet_sync_invalid; return@Button
                        }
                        if (candidate.syncPassword.length < 10) { error = R.string.wallet_sync_short_key; return@Button }
                        SyncCoordinator.saveConfig(context, candidate)
                        saved = candidate; editing = false; error = null; testPassed = null
                        // Use the coordinator entry point, including mobile-data confirmation.
                        SyncCoordinator.requestManualSync(context)
                    }, enabled = !testing && !status.isSyncing, modifier = Modifier.weight(1f)) {
                        Text(stringResource(R.string.wallet_sync_save), maxLines = 1)
                    }
                }
                if (saved.isReadyForSync) TextButton(onClick = { cancelEdit() }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                    Text(stringResource(R.string.wallet_cancel))
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

@Composable
private fun SyncInfoRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.width(16.dp))
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f), maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun WalletSecretField(value: String, onChange: (String) -> Unit, title: String, enabled: Boolean) {
    var visible by remember { mutableStateOf(false) }
    OutlinedTextField(value, onChange, label = { Text(title) }, singleLine = true, enabled = enabled,
        visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Next),
        modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp),
        trailingIcon = { IconButton(onClick = { visible = !visible }) {
            Icon(if (visible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                stringResource(if (visible) R.string.wallet_hide_secret else R.string.wallet_show_secret))
        } })
}

@Composable
internal fun WalletSyncNetworkSelector(value: SyncNetworkPreference, onChange: (SyncNetworkPreference) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SyncNetworkPreference.entries.forEach { choice ->
            FilterChip(selected = value == choice, onClick = { onChange(choice) },
                label = { Text(stringResource(if (choice == SyncNetworkPreference.WIFI_ONLY) R.string.wallet_wifi_only else R.string.wallet_wifi_mobile), maxLines = 1) },
                modifier = Modifier.weight(1f))
        }
    }
    Text(stringResource(R.string.wallet_sync_network_hint), style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant)
}
