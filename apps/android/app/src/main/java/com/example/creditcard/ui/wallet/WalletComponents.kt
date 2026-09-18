package com.example.creditcard.ui.wallet

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
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
internal fun WalletModeSwitch(isList: Boolean, onListModeChange: (Boolean) -> Unit) {
    Row(Modifier.clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.surfaceVariant)
        .selectableGroup().padding(2.dp)) {
        listOf(false, true).forEach { listMode ->
            val active = isList == listMode
            Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp))
                .background(if (active) MaterialTheme.colorScheme.primary else Color.Transparent)
                .selectable(active, role = Role.Tab, onClick = { onListModeChange(listMode) })
                .testTag(if (listMode) "wallet_mode_list" else "wallet_mode_cards"), contentAlignment = Alignment.Center) {
                Icon(if (listMode) Icons.AutoMirrored.Filled.List else Icons.Default.CreditCard,
                    stringResource(if (listMode) R.string.wallet_mode_list else R.string.wallet_mode_cards), Modifier.size(21.dp),
                    tint = if (active) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
internal fun WalletFavoritesChip(selected: Boolean, count: Int, onSelectedChange: (Boolean) -> Unit) {
    FilterChip(selected = selected, onClick = { onSelectedChange(!selected) },
        label = { Text(count.toString(), style = MaterialTheme.typography.labelMedium, maxLines = 1) },
        leadingIcon = { Icon(if (selected) Icons.Default.Star else Icons.Default.StarBorder,
            stringResource(R.string.wallet_favorites_count, count), Modifier.size(17.dp)) },
        shape = CircleShape, modifier = Modifier.testTag("wallet_favorites_filter"))
}

/** Kept as a small standalone control for previews and interaction tests. */
@Composable
internal fun WalletViewControls(isList: Boolean, onListModeChange: (Boolean) -> Unit,
    favoritesOnly: Boolean, favoriteCount: Int, onFavoritesChange: (Boolean) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        WalletModeSwitch(isList, onListModeChange)
        WalletFavoritesChip(favoritesOnly, favoriteCount, onFavoritesChange)
    }
}

@Composable
internal fun WalletFavoriteButton(favorite: Boolean, cardName: String, onClick: () -> Unit, onCard: Boolean = false) {
    IconToggleButton(checked = favorite, onCheckedChange = { onClick() }, modifier = Modifier.size(48.dp),
        colors = IconButtonDefaults.iconToggleButtonColors(
            contentColor = if (onCard) Color.White.copy(alpha = 0.82f) else MaterialTheme.colorScheme.onSurfaceVariant,
            checkedContentColor = if (onCard) Color(0xFFFFD375) else MaterialTheme.colorScheme.primary)) {
        Icon(if (favorite) Icons.Default.Star else Icons.Default.StarBorder,
            stringResource(if (favorite) R.string.wallet_remove_favorite else R.string.wallet_add_favorite, cardName),
            Modifier.size(20.dp))
    }
}

@Composable
private fun WalletBankLogo(logo: WalletIssuerLogo?, name: String, onCard: Boolean) {
    val lightMark = onCard || MaterialTheme.colorScheme.surface.luminance() < 0.3f
    Box(Modifier.width(38.dp).height(34.dp), contentAlignment = Alignment.Center) {
        if (logo != null) Image(painterResource(if (lightMark) logo.cardDrawable else logo.drawable), name,
            modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
        else Icon(Icons.Default.CreditCard, stringResource(R.string.wallet_bank_fallback),
            modifier = Modifier.size(28.dp).testTag("wallet_bank_fallback"),
            tint = if (onCard) Color.White else MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun WalletNetworkLogo(network: WalletNetwork, onCard: Boolean = false) {
    val lightMark = onCard || MaterialTheme.colorScheme.surface.luminance() < 0.3f
    val asset = WalletBrandAssets.network(network)
    Box(Modifier.width(48.dp).height(28.dp), contentAlignment = Alignment.Center) {
        if (asset != null) Image(painterResource(asset), network.label,
            Modifier.fillMaxSize(), contentScale = ContentScale.Fit,
            colorFilter = if (lightMark && network in listOf(WalletNetwork.VISA, WalletNetwork.AMEX)) ColorFilter.tint(Color.White) else null)
        else Icon(Icons.Default.CreditCard, stringResource(R.string.wallet_network_unknown), Modifier.size(22.dp),
            tint = if (onCard) Color.White.copy(alpha = 0.7f) else MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** The lower extension is decoration only. It fills the next card's two top corners. */
private fun Modifier.walletStackOverlap(enabled: Boolean): Modifier = if (!enabled) this else layout { measurable, constraints ->
    val item = measurable.measure(constraints)
    layout(item.width, (item.height - 16.dp.roundToPx()).coerceAtLeast(0)) { item.placeRelative(0, 0) }
}

/** Covered cards are a top strip, not a miniature rounded card. Only the final card has bottom radii. */
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
    val issuer = remember(card.bank, card.country) { WalletLogoCatalog.match(card.bank, card.country) }
    val bank = remember(card.bank) { WalletBank.fromName(card.bank) }
    val network = remember(card.cardNumber, card.level) { WalletNetwork.fromCard(card.cardNumber, card.level) }
    val bankName = card.bank.ifBlank { stringResource(R.string.bank_unset) }
    val cardName = card.alias.ifBlank { bankName }
    val category = stringResource(if (card.cardCategory == "debit") R.string.debit_cards else R.string.credit_cards)
    val accent = Color(issuer?.accent ?: bank.accent)
    val brush = remember(accent) { Brush.linearGradient(listOf(lerp(accent, Color.White, 0.03f), accent, lerp(accent, Color.Black, 0.18f))) }
    val shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp,
        bottomStart = if (collapsed) 0.dp else 16.dp, bottomEnd = if (collapsed) 0.dp else 16.dp)
    Surface(onClick = onClick,
        modifier = modifier.fillMaxWidth().walletStackOverlap(collapsed).testTag("wallet_card_${card.id}")
            .semantics { if (selectionMode) this.selected = selected },
        shape = shape, color = Color.Transparent, contentColor = Color.White,
        border = if (selected) BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null) {
        BoxWithConstraints(Modifier.fillMaxWidth().background(brush)) {
            val fontScale = LocalDensity.current.fontScale.coerceAtLeast(1f)
            val faceHeight = maxOf(maxWidth / 1.586f, (164f * fontScale).dp)
            Column(Modifier.fillMaxWidth().then(if (collapsed) Modifier else Modifier.height(faceHeight))
                .padding(start = 14.dp, end = 8.dp, top = 8.dp, bottom = if (collapsed) 24.dp else 16.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    WalletBankLogo(issuer, bankName, onCard = true)
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(bankName, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold,
                            maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(card.alias.ifBlank { category }, modifier = Modifier.weight(1f, fill = false),
                                style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.85f),
                                maxLines = 1, overflow = TextOverflow.Ellipsis)
                            if (collapsed) Text(" · ${walletLastFour(card.cardNumber)}",
                                style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.85f),
                                maxLines = 1, softWrap = false)
                        }
                    }
                    Spacer(Modifier.width(6.dp))
                    WalletNetworkLogo(network, onCard = true)
                    if (selectionMode) Icon(if (selected) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                        stringResource(if (selected) R.string.selected else R.string.not_selected), Modifier.padding(12.dp).size(24.dp))
                    else WalletFavoriteButton(favorite, cardName, onFavoriteClick, onCard = true)
                }
                if (!collapsed) {
                    Spacer(Modifier.weight(1f))
                    Text("••••  ${walletLastFour(card.cardNumber)}", fontFamily = FontFamily.Monospace,
                        style = MaterialTheme.typography.headlineSmall, letterSpacing = 1.sp, maxLines = 1, softWrap = false,
                        modifier = Modifier.padding(start = 4.dp))
                    Spacer(Modifier.weight(1f))
                    Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(category, style = MaterialTheme.typography.labelMedium)
                        Text(card.valid.ifBlank { "--/--" }, style = MaterialTheme.typography.labelMedium,
                            color = Color.White.copy(alpha = 0.8f))
                    }
                }
            }
        }
    }
}

@Composable
internal fun WalletListRow(card: SharedCard, favorite: Boolean, onFavoriteClick: () -> Unit,
    selectionMode: Boolean = false, selected: Boolean = false, first: Boolean = true, last: Boolean = true, onClick: () -> Unit) {
    val issuer = remember(card.bank, card.country) { WalletLogoCatalog.match(card.bank, card.country) }
    val network = remember(card.cardNumber, card.level) { WalletNetwork.fromCard(card.cardNumber, card.level) }
    val bankName = card.bank.ifBlank { stringResource(R.string.bank_unset) }
    val cardName = card.alias.ifBlank { bankName }
    Surface(onClick = onClick,
        modifier = Modifier.fillMaxWidth().testTag("wallet_list_${card.id}").semantics { if (selectionMode) this.selected = selected },
        color = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(topStart = if (first) 16.dp else 0.dp, topEnd = if (first) 16.dp else 0.dp,
            bottomStart = if (last) 16.dp else 0.dp, bottomEnd = if (last) 16.dp else 0.dp)) {
        Column {
            Row(Modifier.fillMaxWidth().heightIn(min = 72.dp).padding(start = 14.dp, end = 4.dp, top = 8.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically) {
                WalletBankLogo(issuer, bankName, onCard = false)
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(cardName, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Text(bankName, modifier = Modifier.weight(1f, fill = false), style = MaterialTheme.typography.bodySmall,
                            maxLines = 1, overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(" · ${walletLastFour(card.cardNumber)}", style = MaterialTheme.typography.bodySmall,
                            maxLines = 1, softWrap = false, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                Spacer(Modifier.width(8.dp))
                WalletNetworkLogo(network)
                if (selectionMode) Icon(if (selected) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                    stringResource(if (selected) R.string.selected else R.string.not_selected), Modifier.padding(12.dp).size(24.dp),
                    tint = MaterialTheme.colorScheme.primary)
                else WalletFavoriteButton(favorite, cardName, onFavoriteClick)
            }
            if (!last) HorizontalDivider(Modifier.padding(start = 64.dp, end = 16.dp),
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
        }
    }
}
