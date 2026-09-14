#!/usr/bin/env python3
"""One-time integration, limited to the reviewed feature branch and Android client."""
from pathlib import Path
import subprocess, sys
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'apps/android'; J=A/'app/src/main/java/com/example/creditcard'; R=A/'app/src/main/res'
def replace(text, old, new):
    if text.count(old)!=1: raise RuntimeError(f'Expected one anchor, found {text.count(old)}: {old[:100]}')
    return text.replace(old,new,1)
def section(text, start, end, replacement):
    a=text.index(start); b=text.index(end,a)
    return text[:a]+replacement+text[b:]
branch=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()
if branch!='feat/android-wallet-redesign-v2': raise RuntimeError('Feature branch required')
p=J/'ui/main/MainScreen.kt'; s=p.read_text()
if 'WalletHomeHeader(' not in s:
    s=replace(s,'    val favoriteCount = categoryCards.count { it.id in favoriteCardIDs }',
        '    val favoriteCount = remember(categoryCards, favoriteCardIDs) { categoryCards.count { it.id in favoriteCardIDs } }')
    s=section(s,'        floatingActionButton = {','        containerColor = MaterialTheme.colorScheme.background\n    ) { innerPadding ->', '''        floatingActionButton = {
            val count = billingReminderCount + annualReminderCount + expiryReminderCount
            if (selectedTab == 0 && !selectionMode && count > 0) {
                WalletReminderButton(count) { onItemClick(CardReminders) }
            }
        },
''')
    s=section(s,'                        item(key = "clean_header")','                        // 2. 搜寻与管理扩展面板', '''                        item(key = "clean_header", contentType = "header") {
                            WalletHomeHeader(
                                total = cards.size,
                                search = searchQuery,
                                onSearchChange = { searchQuery = it },
                                category = cardCategoryFilter,
                                onCategoryChange = { cardCategoryFilter = it },
                                allCount = searchFilteredCards.size,
                                creditCount = creditCardCount,
                                debitCount = debitCardCount,
                                isList = isCompactView,
                                onListModeChange = walletPreferences::setListMode,
                                favoritesOnly = favoritesOnly,
                                favoriteCount = favoriteCount,
                                onFavoritesChange = { favoritesOnly = it },
                                isSyncing = syncStatus.isSyncing,
                                syncType = syncStatus.type,
                                syncReady = syncConfig.isReadyForSync,
                                onSync = {
                                    if (syncStatus.isSyncing) { selectedTab = 1; toolsMode = ToolsMode.SYNC_LOG }
                                    else if (!syncConfig.isReadyForSync) { selectedTab = 2; settingsMode = SettingsMode.WEBDAV }
                                    else SyncCoordinator.requestManualSync(context)
                                },
                                onManage = { showCardManagement = !showCardManagement },
                                onAddCredit = { onItemClick(CardForm(cardId = null, cardCategory = "credit")) },
                                onAddDebit = { onItemClick(CardForm(cardId = null, cardCategory = "debit")) }
                            )
                        }
''')
    s=section(s,'                        // 3. 分类控制 Switcher','                        // 5. 空状态与展示','')
    a=s.index('                        if (filteredCards.isEmpty()) {'); b=s.index('                            groupedCards.forEach',a)
    s=s[:a]+'''                        if (filteredCards.isEmpty()) {
                            item(key = "empty_state", contentType = "empty") {
                                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
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
                                }
                            }
                        } else {
'''+s[b:]
    s=replace(s,'itemsIndexed(groupCards, key = { _, card -> card.id }) { index, card ->',
        'itemsIndexed(groupCards, key = { _, card -> card.id }, contentType = { _, _ -> if (isCompactView) "list" else "card" }) { index, card ->')
    s=replace(s,'.padding(horizontal = 20.dp)\n                                            .padding(top = if (index == 0) 8.dp else 0.dp,',
        '.padding(horizontal = 16.dp)\n                                            .padding(top = 0.dp,')
    s=replace(s,'bottom = if (index == groupCards.lastIndex) 16.dp else 0.dp)',
        'bottom = if (index == groupCards.lastIndex) 16.dp else if (selectionMode && !isCompactView) 8.dp else 0.dp)')
    s=section(s,'@Composable\nfun ModernThemeSelector(isDark: Boolean) {','@Composable\nfun SettingsStoragePanel(',
        '@Composable\nfun ModernThemeSelector(isDark: Boolean) {\n    WalletThemePicker()\n}\n\n')
    s=section(s,'@Composable\nfun SettingsWebDAVPanel(','@Composable\nfun SyncProgressBlock(',
        '@Composable\nfun SettingsWebDAVPanel(isDark: Boolean, onBack: () -> Unit) {\n    WalletSyncSettings(onBack)\n}\n\n')
    p.write_text(s)
p=J/'ui/CardDetailScreen.kt'; s=p.read_text()
if '                WalletCardNumber(' not in s:
    s=replace(s,'                CardNumberInfoRow(\n','                WalletCardNumber(\n')
    s=replace(s,'                    countdownProgress = countdownProgress,\n                    isDark = isDark,\n                    onToggleVisible',
        '                    countdownProgress = countdownProgress,\n                    onToggleVisible')
    s=replace(s,'.padding(horizontal = 20.dp)\n                .verticalScroll', '.padding(horizontal = 16.dp)\n                .verticalScroll')
    p.write_text(s)
# Always auto-sync once configured. The legacy field is retained for constructor compatibility.
p=J/'utils/SyncCoordinator.kt';s=p.read_text()
if 'val isEnabled: Boolean = false' in s:
    s=replace(s,'val isEnabled: Boolean = false','val isEnabled: Boolean = true')
    s=replace(s,'get() = isEnabled &&\n            url.isNotBlank()', 'get() = url.isNotBlank()')
    s=replace(s,'            !isEnabled -> "请先在 WebDAV 设置中配置并开启云同步"\n','')
    s=replace(s,'putBoolean(KEY_ENABLED, config.isEnabled)','putBoolean(KEY_ENABLED, true)')
    s=replace(s,'val isEnabled = prefs.getBoolean(KEY_ENABLED, false)', '''// Migrate an explicit old "off" value once; credentials and network policy are preserved.
        if (prefs.contains(KEY_ENABLED) && !prefs.getBoolean(KEY_ENABLED, true)) {
            prefs.edit().putBoolean(KEY_ENABLED, true).apply()
        }
        val isEnabled = true''')
    s=replace(s,'} else if (config.isEnabled) {\n            updateStatus(config.syncUnavailableMessage() ?: "WebDAV 配置不完整", "warning", isPending(context))\n        } else {\n            updateStatus("云同步已关闭，本机改动将仅保留于本地", "info", isPending(context))',
        '} else {\n            updateStatus(config.syncUnavailableMessage() ?: "WebDAV 配置不完整", "warning", isPending(context))')
    s=replace(s,'        connectivityManager.registerDefaultNetworkCallback(\n            object : ConnectivityManager.NetworkCallback() {',
        '        val callback = object : ConnectivityManager.NetworkCallback() {')
    s=replace(s,'            }\n        )\n    }\n\n    private fun requestBackgroundSync', '''            }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            connectivityManager.registerDefaultNetworkCallback(callback)
        } else {
            connectivityManager.registerNetworkCallback(
                android.net.NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build(), callback
            )
        }
    }

    private fun requestBackgroundSync''')
    p.write_text(s)
# Genuine minSdk compatibility fixes, not Lint suppressions.
p=A/'app/build.gradle.kts';s=p.read_text()
if 'walletPreview' not in s:
    s=replace(s,'    defaultConfig {', '    defaultConfig {\n        manifestPlaceholders["appLabel"] = "@string/app_name"')
    s=replace(s,'    buildTypes {', '''    buildTypes {
        debug {
            if (providers.gradleProperty("walletPreview").orNull == "true") {
                applicationIdSuffix = ".preview"
                versionNameSuffix = "-ui-v2-preview"
                manifestPlaceholders["appLabel"] = "@string/wallet_preview_name"
            }
        }''')
    s=replace(s,'    compileOptions {','    compileOptions {\n        isCoreLibraryDesugaringEnabled = true')
    s=replace(s,'dependencies {\n  val composeBom', 'dependencies {\n  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n  val composeBom')
    p.write_text(s)
p=A/'app/src/main/AndroidManifest.xml';s=p.read_text().replace('android:label="@string/app_name"','android:label="${appLabel}"');p.write_text(s)
p=J/'utils/CardSystemNotifier.kt';s=p.read_text()
if 'catch (_: SecurityException)' not in s:
    s=replace(s,'        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)', '''        // Permission may be revoked between checking and delivery.
        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            return false
        }''')
    p.write_text(s)
strings={
'wallet_mode_cards':('Cards','卡片'), 'wallet_mode_list':('List','列表'),
'wallet_search_short':('Search cards','搜索银行、卡名或尾号'),
'wallet_reminders_count':('%1$d card reminders','%1$d 项卡片提醒'),
'wallet_reset_hint':('Try a different search or view all cards.','可以更换搜索条件，或查看全部卡片。'),
'wallet_show_all':('Show all cards','查看全部卡片'),
'wallet_card_number':('Card number','银行卡号'), 'wallet_copy_number':('Copy full card number','复制完整卡号'),
'wallet_hide_number':('Hide card number','隐藏卡号'), 'wallet_show_number':('Show card number','显示卡号'),
'wallet_number_hint':('Tap to copy. Revealed details hide after 5 seconds.','轻点复制完整号码，显示后 5 秒自动隐藏。'),
'wallet_sync_edit':('Edit connection','修改配置'), 'wallet_sync_busy':('Syncing','正在同步'),
'wallet_sync_error':('Sync needs attention','同步需要处理'), 'wallet_sync_current':('Up to date','已同步'),
'wallet_sync_configured':('Ready to sync','已配置云同步'), 'wallet_sync_always_on':('Syncs automatically once configured','配置完成后自动同步'),
'wallet_sync_server':('Server','服务器'), 'wallet_sync_user':('Account','账号'),
'wallet_sync_now':('Sync now','立即同步'), 'wallet_sync_cancel_run':('Cancel this sync','停止本次同步'),
'wallet_sync_network':('Network','同步网络'), 'wallet_sync_url':('WebDAV address','WebDAV 地址'),
'wallet_sync_password':('App password','应用密码'), 'wallet_sync_key':('Encryption key','同步密钥'),
'wallet_sync_key_hint':('Use the same key on your other devices. Keep it safe: it is required to decrypt your cloud data.','与其他设备使用相同密钥。请妥善保存，遗失后将无法解密云端数据。'),
'wallet_sync_test_success':('Connection succeeded. This does not validate the encryption key.','连接测试成功；此测试不校验同步密钥。'),
'wallet_sync_test_failed':('Could not connect. Check the address and credentials.','连接失败，请检查地址、账号和应用密码。'),
'wallet_sync_invalid':('Enter a valid http(s) address, account, password and encryption key.','请填写有效的 http(s) 地址、账号、应用密码和同步密钥。'),
'wallet_sync_test':('Test connection','测试连接'), 'wallet_sync_save':('Save and sync','保存并同步'),
'wallet_sync_short_key':('Use an encryption key of at least 10 characters.','同步密钥至少需要 10 个字符。'),
'wallet_cancel':('Cancel','取消'), 'wallet_hide_secret':('Hide password','隐藏密码'), 'wallet_show_secret':('Show password','显示密码'),
'wallet_wifi_only':('Wi-Fi only','仅 Wi-Fi'), 'wallet_wifi_mobile':('Wi-Fi + mobile','Wi-Fi + 流量'),
'wallet_sync_network_hint':('Automatic sync follows this network choice. Manual sync on mobile data asks for confirmation.','自动同步遵循此网络限制，移动数据下手动同步仍会先征求确认。'),
'wallet_preview_name':('Wallet Preview','卡包预览'),
}
for folder,column in [('values',0),('values-zh',1)]:
    root=ET.Element('resources')
    for key,values in strings.items(): ET.SubElement(root,'string',name=key).text=values[column]
    ET.indent(root)
    (R/folder/'wallet_v2.xml').write_text('<?xml version="1.0" encoding="utf-8"?>\n'+ET.tostring(root,encoding='unicode')+'\n')
# Keep alias and tail separately accessible, with the original click/navigation semantics.
p=J/'ui/wallet/WalletComponents.kt'; s=p.read_text()
old='''                        Text(if (collapsed) "${card.alias.ifBlank { category }} · ${walletLastFour(card.cardNumber)}" else card.alias.ifBlank { category },
                            style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.85f),
                            maxLines = 1, overflow = TextOverflow.Ellipsis)'''
if old in s:
    s=replace(s,old,'''                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(card.alias.ifBlank { category }, modifier = Modifier.weight(1f, fill = false),
                                style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.85f),
                                maxLines = 1, overflow = TextOverflow.Ellipsis)
                            if (collapsed) Text(" · ${walletLastFour(card.cardNumber)}",
                                style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.85f),
                                maxLines = 1, softWrap = false)
                        }''')
    p.write_text(s)
p=J/'ui/wallet/WalletSyncSettings.kt'; s=p.read_text()
s=s.replace('syncPassword = draft.syncPassword.trim(), isEnabled = true', 'isEnabled = true')
s=s.replace('if (candidate.syncPassword.length < 10)', 'if (candidate.syncPassword != saved.syncPassword && candidate.syncPassword.length < 10)')
p.write_text(s)
p=A/'branding/build_catalog.py'; s=p.read_text()
s=s.replace('for key,names in extra.items(): aliases.setdefault(key,[]).extend(names)',
    'for key,names in extra.items(): aliases.setdefault({"americanexpress":"amex", "deutschebank":"deutsche"}.get(key,key),[]).extend(names)')
p.write_text(s)
p=A/'app/src/test/java/com/example/creditcard/ui/wallet/WalletV2VisualTest.kt'; s=p.read_text()
s=s.replace('getSharedPreferences("webdav_config",', 'getSharedPreferences("credit_card_sync_prefs",')
p.write_text(s)
# Only the maintenance runner downloads assets; normal builds/runtime are offline for logos.
if not (J/'ui/wallet/WalletLogoCatalogData.kt').exists():
    subprocess.run([sys.executable,str(A/'branding/build_catalog.py')],cwd=ROOT,check=True)
print('Wallet v2 integration complete.')
