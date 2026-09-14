package com.example.creditcard.ui.wallet

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.creditcard.R

/** A scrolling, three-row toolbar. No full-width mode switch or permanent alert banner. */
@Composable
internal fun WalletHomeHeader(
    total: Int,
    search: String,
    onSearchChange: (String) -> Unit,
    category: String,
    onCategoryChange: (String) -> Unit,
    allCount: Int,
    creditCount: Int,
    debitCount: Int,
    isList: Boolean,
    onListModeChange: (Boolean) -> Unit,
    favoritesOnly: Boolean,
    favoriteCount: Int,
    onFavoritesChange: (Boolean) -> Unit,
    isSyncing: Boolean,
    syncType: String,
    syncReady: Boolean,
    onSync: () -> Unit,
    onManage: () -> Unit,
    onAddCredit: () -> Unit,
    onAddDebit: () -> Unit
) {
    var addMenu by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().testTag("wallet_header").padding(horizontal = 16.dp)) {
        Row(Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.wallet_title), style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(stringResource(R.string.cards_count, total), style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            IconButton(onClick = onSync, modifier = Modifier.size(48.dp)) {
                if (isSyncing) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                else Icon(when {
                    !syncReady -> Icons.Default.CloudQueue
                    syncType == "error" -> Icons.Default.CloudOff
                    syncType == "success" -> Icons.Default.CloudDone
                    else -> Icons.Default.CloudQueue
                }, stringResource(R.string.settings_sync), modifier = Modifier.size(22.dp),
                    tint = if (syncType == "error") MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant)
            }
            IconButton(onClick = onManage, modifier = Modifier.size(48.dp)) {
                Icon(Icons.Default.Tune, stringResource(R.string.manage_cards), Modifier.size(22.dp))
            }
            if (total > 0) Box {
                FilledTonalIconButton(onClick = { addMenu = true }, modifier = Modifier.size(48.dp)) {
                    Icon(Icons.Default.Add, stringResource(R.string.add_card))
                }
                DropdownMenu(expanded = addMenu, onDismissRequest = { addMenu = false }) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.add_credit)) },
                        onClick = { addMenu = false; onAddCredit() }, leadingIcon = { Icon(Icons.Default.CreditCard, null) })
                    DropdownMenuItem(text = { Text(stringResource(R.string.add_debit)) },
                        onClick = { addMenu = false; onAddDebit() }, leadingIcon = { Icon(Icons.Default.AccountBalanceWallet, null) })
                }
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Surface(modifier = Modifier.weight(1f), shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.surfaceVariant) {
                BasicTextField(
                    value = search, onValueChange = onSearchChange, singleLine = true,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("wallet_search"),
                    textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.colorScheme.onSurface),
                    cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    decorationBox = { field ->
                        Row(Modifier.padding(start = 12.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Search, null, Modifier.size(19.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.width(8.dp))
                            Box(Modifier.weight(1f).padding(vertical = 12.dp)) {
                                if (search.isEmpty()) Text(stringResource(R.string.wallet_search_short),
                                    style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                                field()
                            }
                            if (search.isNotEmpty()) IconButton(onClick = { onSearchChange("") }, modifier = Modifier.size(40.dp)) {
                                Icon(Icons.Default.Close, stringResource(R.string.clear_search), Modifier.size(18.dp))
                            }
                        }
                    }
                )
            }
            WalletModeSwitch(isList, onListModeChange)
        }
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(top = 4.dp, bottom = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically
        ) {
            listOf(Triple("all", R.string.all_cards, allCount), Triple("credit", R.string.credit_cards, creditCount),
                Triple("debit", R.string.debit_cards, debitCount)).forEach { (key, title, count) ->
                FilterChip(selected = category == key, onClick = { onCategoryChange(key) },
                    label = { Text("${stringResource(title)} $count", maxLines = 1, style = MaterialTheme.typography.labelMedium) },
                    shape = CircleShape, modifier = Modifier.testTag("wallet_category_$key"))
            }
            WalletFavoritesChip(favoritesOnly, favoriteCount, onFavoritesChange)
        }
    }
}

@Composable
internal fun WalletReminderButton(count: Int, onClick: () -> Unit) {
    SmallFloatingActionButton(onClick = onClick, containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
        contentColor = MaterialTheme.colorScheme.onSurface, modifier = Modifier.testTag("wallet_reminders")) {
        BadgedBox(badge = { Badge { Text(if (count > 99) "99+" else count.toString()) } }) {
            Icon(Icons.Default.NotificationsNone, stringResource(R.string.wallet_reminders_count, count))
        }
    }
}

@Composable
internal fun WalletEmptyState(hasCards: Boolean, favoritesOnly: Boolean, onReset: () -> Unit, onAdd: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 32.dp).testTag("wallet_empty"),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Icon(if (favoritesOnly) Icons.Default.StarBorder else Icons.Default.Wallet, null,
            Modifier.size(48.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(stringResource(when { !hasCards -> R.string.wallet_empty_title
            favoritesOnly -> R.string.wallet_no_favorites
            else -> R.string.wallet_no_results }), style = MaterialTheme.typography.titleMedium)
        Text(stringResource(if (!hasCards) R.string.wallet_empty_body else if (favoritesOnly) R.string.wallet_favorites_body
            else R.string.wallet_reset_hint), style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
        Button(onClick = if (hasCards) onReset else onAdd) {
            Text(stringResource(if (hasCards) R.string.wallet_show_all else R.string.add_card))
        }
    }
}
