package com.example.creditcard.ui.wallet

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.creditcard.R
import com.example.creditcard.data.SharedCard

@Composable
internal fun WalletViewControls(
    isList: Boolean,
    onListModeChange: (Boolean) -> Unit,
    favoritesOnly: Boolean,
    favoriteCount: Int,
    onFavoritesChange: (Boolean) -> Unit
) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 6.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            Modifier.fillMaxWidth().clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.65f))
                .padding(4.dp).selectableGroup(),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            listOf(false, true).forEach { listMode ->
                val active = isList == listMode
                val label = stringResource(if (listMode) R.string.view_list else R.string.view_cards)
                Row(
                    Modifier.weight(1f).clip(CircleShape)
                        .background(if (active) MaterialTheme.colorScheme.primary else Color.Transparent)
                        .selectable(active, role = Role.Tab, onClick = { onListModeChange(listMode) })
                        .testTag(if (listMode) "wallet_mode_list" else "wallet_mode_cards")
                        .heightIn(min = 48.dp).padding(horizontal = 12.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val tint = if (active) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                    Icon(if (listMode) Icons.AutoMirrored.Filled.List else Icons.Default.CreditCard,
                        null, Modifier.size(19.dp), tint = tint)
                    Spacer(Modifier.width(8.dp))
                    Text(label, color = tint, style = MaterialTheme.typography.labelLarge)
                }
            }
        }
        FilterChip(
            selected = favoritesOnly,
            onClick = { onFavoritesChange(!favoritesOnly) },
            label = { Text(stringResource(R.string.wallet_favorites_count, favoriteCount)) },
            leadingIcon = { Icon(Icons.Default.Star, null, Modifier.size(18.dp)) },
            shape = CircleShape,
            modifier = Modifier.heightIn(min = 48.dp).testTag("wallet_favorites_filter")
        )
    }
}

@Composable
internal fun WalletFavoriteButton(
    favorite: Boolean,
    cardName: String,
    onClick: () -> Unit,
    onCard: Boolean = false
) {
    IconToggleButton(
        checked = favorite,
        onCheckedChange = { onClick() },
        modifier = Modifier.size(48.dp),
        colors = IconButtonDefaults.iconToggleButtonColors(
            contentColor = if (onCard) Color.White.copy(alpha = 0.9f) else MaterialTheme.colorScheme.onSurfaceVariant,
            checkedContentColor = if (onCard) Color(0xFFFFD379) else Color(0xFF95620A)
        )
    ) {
        Icon(
            if (favorite) Icons.Default.Star else Icons.Default.StarBorder,
            contentDescription = stringResource(
                if (favorite) R.string.wallet_remove_favorite else R.string.wallet_add_favorite, cardName
            ),
            modifier = Modifier.size(22.dp)
        )
    }
}

@Composable
private fun WalletBankLogo(bank: WalletBank, name: String, modifier: Modifier = Modifier) {
    val asset = WalletBrandAssets.bank(bank)
    Box(modifier.size(44.dp).clip(RoundedCornerShape(14.dp)).background(Color.White),
        contentAlignment = Alignment.Center) {
        if (asset != null) {
            Image(painterResource(asset), contentDescription = name,
                modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
        } else {
            Text(name.trim().take(2).ifBlank { "CW" }, color = Color(bank.accent),
                fontWeight = FontWeight.Bold, fontSize = 16.sp, maxLines = 1)
        }
    }
}

@Composable
private fun WalletNetworkLogo(network: WalletNetwork, onCard: Boolean = false) {
    val asset = WalletBrandAssets.network(network)
    if (asset != null) {
        Image(painterResource(asset), contentDescription = network.label,
            modifier = Modifier.width(48.dp).height(30.dp).clip(RoundedCornerShape(5.dp)),
            contentScale = ContentScale.Fit)
    } else {
        Icon(Icons.Default.CreditCard, stringResource(R.string.wallet_network_unknown),
            Modifier.size(24.dp),
            tint = if (onCard) Color.White.copy(alpha = 0.7f) else MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Overlap only the decorative bottom margin. All buttons remain above the next card. */
private fun Modifier.walletStackOverlap(enabled: Boolean): Modifier = if (!enabled) this else layout { measurable, constraints ->
    val placeable = measurable.measure(constraints)
    val overlap = 14.dp.roundToPx().coerceAtMost(placeable.height)
    layout(placeable.width, placeable.height - overlap) { placeable.placeRelative(0, 0) }
}

@Composable
internal fun WalletCardFace(
    card: SharedCard,
    favorite: Boolean,
    onFavoriteClick: () -> Unit,
    selectionMode: Boolean = false,
    selected: Boolean = false,
    collapsed: Boolean = false,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val bank = remember(card.bank) { WalletBank.fromName(card.bank) }
    val network = remember(card.cardNumber) { WalletNetwork.fromNumber(card.cardNumber) }
    val bankName = card.bank.ifBlank { stringResource(R.string.bank_unset) }
    val cardName = card.alias.ifBlank { bankName }
    val category = stringResource(if (card.cardCategory == "debit") R.string.debit_cards else R.string.credit_cards)
    val accent = Color(bank.accent)
    val brush = remember(accent) {
        Brush.linearGradient(listOf(lerp(accent, Color.White, 0.10f), accent, lerp(accent, Color.Black, 0.22f)))
    }
    Surface(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().walletStackOverlap(collapsed)
            .testTag("wallet_card_${card.id}").semantics { if (selectionMode) this.selected = selected },
        shape = RoundedCornerShape(24.dp),
        color = Color.Transparent,
        contentColor = Color.White,
        shadowElevation = 3.dp,
        border = BorderStroke(if (selected) 2.dp else 1.dp,
            if (selected) MaterialTheme.colorScheme.primary else Color.White.copy(alpha = 0.28f))
    ) {
        Box(Modifier.fillMaxWidth().background(brush)) {
            Canvas(Modifier.matchParentSize()) {
                for (index in 0..3) {
                    drawOval(Color.White.copy(alpha = 0.075f),
                        topLeft = Offset(size.width * 0.35f + index * 22.dp.toPx(), size.height * 0.18f),
                        size = Size(size.width * 1.25f, size.height * 1.5f),
                        style = Stroke(1.dp.toPx()))
                }
            }
            Column(
                Modifier.fillMaxWidth().padding(start = 16.dp, end = 12.dp, top = 12.dp,
                    bottom = if (collapsed) 26.dp else 20.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    WalletBankLogo(bank, bankName)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(bankName, style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(card.alias.ifBlank { category }, style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.85f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    if (selectionMode) {
                        Icon(if (selected) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                            stringResource(if (selected) R.string.selected else R.string.not_selected), Modifier.padding(12.dp).size(24.dp))
                    } else {
                        WalletFavoriteButton(favorite, cardName, onFavoriteClick, onCard = true)
                    }
                }
                if (!collapsed) Spacer(Modifier.height(22.dp))
                Row(Modifier.fillMaxWidth().padding(start = if (collapsed) 56.dp else 0.dp, end = 8.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Text("••••  ${walletLastFour(card.cardNumber)}",
                        style = if (collapsed) MaterialTheme.typography.bodyMedium else MaterialTheme.typography.headlineSmall,
                        fontFamily = FontFamily.Monospace, letterSpacing = if (collapsed) 1.sp else 2.sp,
                        maxLines = 1, modifier = Modifier.weight(1f))
                    WalletNetworkLogo(network, onCard = true)
                }
                if (!collapsed) {
                    Spacer(Modifier.height(16.dp))
                    HorizontalDivider(color = Color.White.copy(alpha = 0.18f))
                    Row(Modifier.fillMaxWidth().padding(top = 8.dp, end = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(category, style = MaterialTheme.typography.labelMedium)
                        Text(stringResource(R.string.wallet_valid_through, card.valid.ifBlank { "--/--" }),
                            style = MaterialTheme.typography.labelMedium, color = Color.White.copy(alpha = 0.85f))
                    }
                }
            }
        }
    }
}

@Composable
internal fun WalletListRow(
    card: SharedCard,
    favorite: Boolean,
    onFavoriteClick: () -> Unit,
    selectionMode: Boolean = false,
    selected: Boolean = false,
    first: Boolean = true,
    last: Boolean = true,
    onClick: () -> Unit
) {
    val bank = remember(card.bank) { WalletBank.fromName(card.bank) }
    val network = remember(card.cardNumber) { WalletNetwork.fromNumber(card.cardNumber) }
    val bankName = card.bank.ifBlank { stringResource(R.string.bank_unset) }
    val cardName = card.alias.ifBlank { bankName }
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().testTag("wallet_list_${card.id}")
            .semantics { if (selectionMode) this.selected = selected },
        color = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(topStart = if (first) 22.dp else 0.dp,
            topEnd = if (first) 22.dp else 0.dp,
            bottomStart = if (last) 22.dp else 0.dp, bottomEnd = if (last) 22.dp else 0.dp)
    ) {
        Column {
            Row(Modifier.fillMaxWidth().heightIn(min = 86.dp).padding(start = 14.dp, end = 6.dp, top = 10.dp, bottom = 10.dp),
                verticalAlignment = Alignment.CenterVertically) {
                WalletBankLogo(bank, bankName)
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(cardName, style = MaterialTheme.typography.titleSmall,
                        maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("•••• ${walletLastFour(card.cardNumber)}", style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, fontFamily = FontFamily.Monospace)
                }
                Spacer(Modifier.width(8.dp))
                WalletNetworkLogo(network)
                if (selectionMode) {
                    Icon(if (selected) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                        stringResource(if (selected) R.string.selected else R.string.not_selected),
                        Modifier.padding(12.dp).size(24.dp), tint = MaterialTheme.colorScheme.primary)
                } else WalletFavoriteButton(favorite, cardName, onFavoriteClick)
            }
            if (!last) HorizontalDivider(Modifier.padding(start = 70.dp, end = 16.dp),
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f))
        }
    }
}
