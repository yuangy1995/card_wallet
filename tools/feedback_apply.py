"""Guarded Android-only integration for fix/android-wallet-preview-feedback."""
from pathlib import Path
import subprocess

assert subprocess.check_output(['git', 'branch', '--show-current'], text=True).strip() == 'fix/android-wallet-preview-feedback'
ROOT = Path('apps/android')
J = 'app/src/main/java/com/example/creditcard/'

def replace(path, old, new):
    p = ROOT / path
    s = p.read_text()
    assert s.count(old) == 1, (path, s.count(old), old[:60])
    p.write_text(s.replace(old, new))

replace(J+'utils/ThemeManager.kt', 'MutableStateFlow(AppThemeMode.DARK)', 'MutableStateFlow(AppThemeMode.SYSTEM)')
replace(J+'utils/ThemeManager.kt', 'MutableStateFlow(true)', 'MutableStateFlow(false)')
replace(J+'utils/ThemeManager.kt', 'prefs.getString("theme_mode", AppThemeMode.DARK.name) ?: AppThemeMode.DARK.name', 'prefs.getString("theme_mode", AppThemeMode.SYSTEM.name) ?: AppThemeMode.SYSTEM.name')
replace(J+'utils/ThemeManager.kt', 'catch (e: Exception) { AppThemeMode.DARK }', 'catch (e: IllegalArgumentException) { AppThemeMode.SYSTEM }')
replace(J+'utils/ThemeManager.kt', 'setThemeMode(context, AppThemeMode.DARK)\n    }\n}', 'setThemeMode(context, AppThemeMode.SYSTEM)\n    }\n}')

replace(J+'ui/wallet/WalletComponents.kt', '''else Text(name.trim().take(2).ifBlank { "CW" },
            color = if (onCard) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1)''', '''else Icon(Icons.Default.CreditCard, stringResource(R.string.wallet_bank_fallback),
            modifier = Modifier.size(28.dp).testTag("wallet_bank_fallback"),
            tint = if (onCard) Color.White else MaterialTheme.colorScheme.onSurfaceVariant)''')
replace(J+'ui/wallet/WalletHomeHeader.kt', 'modifier = Modifier.size(48.dp)) {\n                    Icon(Icons.Default.Add', 'modifier = Modifier.size(48.dp).testTag("wallet_add_header")) {\n                    Icon(Icons.Default.Add')
replace(J+'ui/wallet/WalletHomeHeader.kt', 'onReset: () -> Unit, onAdd: () -> Unit)', 'onReset: () -> Unit)')
replace(J+'ui/wallet/WalletHomeHeader.kt', '''        Button(onClick = if (hasCards) onReset else onAdd) {
            Text(stringResource(if (hasCards) R.string.wallet_show_all else R.string.add_card))
        }''', '''        if (hasCards) Button(onClick = onReset) {
            Text(stringResource(R.string.wallet_show_all))
        }''')
replace(J+'ui/main/MainScreen.kt', '''            if (selectedTab == 0 && !selectionMode && count > 0) {
                WalletReminderButton(count) { onItemClick(CardReminders) }
            }''', '''            if (selectedTab == 0 && !selectionMode) {
                if (cards.isEmpty()) {
                    WalletAddFab(
                        onAddCredit = { onItemClick(CardForm(cardId = null, cardCategory = "credit")) },
                        onAddDebit = { onItemClick(CardForm(cardId = null, cardCategory = "debit")) }
                    )
                } else if (count > 0) {
                    WalletReminderButton(count) { onItemClick(CardReminders) }
                }
            }''')
replace(J+'ui/main/MainScreen.kt', '''                                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
                                    WalletEmptyState(
                                        hasCards = cards.isNotEmpty(), favoritesOnly = favoritesOnly,
                                        onReset = { searchQuery = ""; cardCategoryFilter = "all"; favoritesOnly = false },
                                        onAdd = { showAddMenu = true }
                                    )
                                    DropdownMenu(expanded = showAddMenu, onDismissRequest = { showAddMenu = false }) {
                                        DropdownMenuItem(text = { Text(stringResource(R.string.add_credit)) }, onClick = {
                                            showAddMenu = false; onItemClick(CardForm(cardId = null, cardCategory = "credit"))
                                        })
                                        DropdownMenuItem(text = { Text(stringResource(R.string.add_debit)) }, onClick = {
                                            showAddMenu = false; onItemClick(CardForm(cardId = null, cardCategory = "debit"))
                                        })
                                    }
                                }''', '''                                WalletEmptyState(
                                    hasCards = cards.isNotEmpty(), favoritesOnly = favoritesOnly,
                                    onReset = { searchQuery = ""; cardCategoryFilter = "all"; favoritesOnly = false }
                                )''')
p = ROOT / (J+'ui/main/MainScreen.kt')
s = p.read_text()
s = '\n'.join(line for line in s.split('\n') if 'var showAddMenu by remember' not in line)
p.write_text(s)

# Reuse the same authenticated/retrying WebDAV path; the file-backed body owns no snapshot bytes.
replace(J+'utils/WebDAVClient.kt', '        val request = Request.Builder()\n            .url(fileUrl)\n            .put(requestBody)', '''        return uploadRequest(fileUrl, credential, requestBody)
    }

    internal fun uploadSyncSnapshot(
        url: String, user: String, pass: String, filename: String,
        upload: SyncUpload, onProgress: ((Long) -> Unit)? = null
    ): Boolean {
        val cleanUrl = sanitizeUrl(url)
        val credential = Credentials.basic(user, pass)
        ensureBackupDirExists(cleanUrl, credential)
        return uploadRequest(backupFileUrl(cleanUrl, filename), credential, upload.requestBody(onProgress))
    }

    private fun uploadRequest(fileUrl: String, credential: String, requestBody: RequestBody): Boolean {
        val request = Request.Builder()
            .url(fileUrl)
            .put(requestBody)''')

p = ROOT / (J+'utils/SyncCoordinator.kt')
s = p.read_text()
s = s.replace('import java.io.IOException', 'import java.io.File\nimport java.io.IOException')
start = s.index('                    val snapshotJson = AppJson.json.encodeToString(SyncSnapshot.serializer(), snapshot)')
end = s.index('                    ensureSyncNotCancelled()\n                    if (uploadSuccess)', start)
new = '''                    val timeFilename = isoNow.replace(":", "-").replace(".", "-")
                    val activeCount = activeCards.size
                    val filename = "${timeFilename}---($activeCount)[SyncV4][Android][自].json"
                    val uploadSuccess = SyncUpload.prepare(
                        File(appContext.cacheDir, "sync-upload"), snapshot, config.syncPassword,
                        checkpoint = ::ensureSyncNotCancelled
                    ).use { upload ->
                        val uploadBytes = upload.size
                        updateProgress("保存云端", 5, 6, "正在写入 WebDAV 加密快照",
                            totalBytes = uploadBytes, transferredBytes = 0L)
                        var lastUploadProgressReportAt = 0L
                        WebDAVClient.uploadSyncSnapshot(
                            config.url, config.user, config.pass, filename, upload,
                            onProgress = { bytesSent ->
                                ensureSyncNotCancelled()
                                val currentBytes = bytesSent.coerceIn(0L, uploadBytes)
                                val now = SyncTime.nowMillis()
                                if (currentBytes == uploadBytes || now - lastUploadProgressReportAt >= PROGRESS_UI_INTERVAL_MS) {
                                    lastUploadProgressReportAt = now
                                    updateProgress("保存云端", 5, 6, "正在写入 WebDAV 加密快照",
                                        totalBytes = uploadBytes, transferredBytes = currentBytes)
                                }
                            }
                        )
                    }
'''
s = s[:start] + new + s[end:]
# Do not retain five decoded, attachment-heavy snapshots through serialization/upload.
start = s.index('                val readResults = coroutineScope {')
end = s.index('\n                withContext(Dispatchers.Main) {\n                    updateProgress("合并数据"', start)
old = s[start:end]
a = old.index('                            ensureSyncNotCancelled()')
b = old.index('\n                        }\n                    }.awaitAll()')
body = old[a:b]
body = '\n'.join(line[8:] if line.startswith('        ') else line for line in body.splitlines())
body = body.replace('return@async ', 'return ')
body = body.replace('                    if (snapshot.schemaVersion ==', '                    return if (snapshot.schemaVersion ==')
new = '''                suspend fun readSnapshot(index: Int, file: BackupFile): SnapshotReadResult {
''' + body + '''
                }
                var remoteRecords = emptyList<CardSyncRecord>()
                filesToRead.forEachIndexed { index, file ->
                    val result = readSnapshot(index, file)
                    if (index == 0 && result.failed) {
                        throw IllegalArgumentException(result.failureMessage ?: "最新云同步文件读取失败，请稍后重试")
                    }
                    result.snapshot?.let { remote ->
                        remoteRecords = SyncMergeEngine.merge(remoteRecords, remote.records)
                    }
                }
'''
s = s[:start] + new + s[end:]
s = s.replace('正在并发下载 ${filesToRead.size} 份云同步文件', '正在逐份下载 ${filesToRead.size} 份云同步文件')
s = s.replace('正在并发读取 ${index + 1}/${filesToRead.size}', '正在读取 ${index + 1}/${filesToRead.size}')
p.write_text(s)

replace('app/build.gradle.kts', 'applicationIdSuffix = ".preview"', 'applicationIdSuffix = providers.gradleProperty("walletPreviewSuffix").orElse(".preview").get()')
replace('app/build.gradle.kts', 'versionNameSuffix = "-ui-v2-preview"', 'versionNameSuffix = "-ui-v3-preview"')
replace('app/build.gradle.kts', '"@string/wallet_preview_name"', '"@string/wallet_preview_feedback_name"')
replace('app/build.gradle.kts', '  testImplementation(libs.junit)', '  testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")\n  testImplementation(libs.junit)')
print('Applied only the reviewed Android feedback changes.')
