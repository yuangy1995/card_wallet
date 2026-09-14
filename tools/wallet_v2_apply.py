#!/usr/bin/env python3
"""Final changes identified in native screenshots, limited to the feature branch."""
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'apps/android'; J=A/'app/src/main/java/com/example/creditcard'
if subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()!='feat/android-wallet-redesign-v2':
    raise RuntimeError('Feature branch required')
def once(s,old,new):
    if s.count(old)!=1: raise RuntimeError(f'Unexpected anchor count {s.count(old)}: {old[:80]}')
    return s.replace(old,new,1)
p=J/'ui/wallet/WalletComponents.kt';s=p.read_text()
if 'val lightMark =' not in s:
    s=once(s,'import androidx.compose.ui.graphics.lerp','import androidx.compose.ui.graphics.lerp\nimport androidx.compose.ui.graphics.luminance')
    s=once(s,'private fun WalletBankLogo(logo: WalletIssuerLogo?, name: String, onCard: Boolean) {',
        'private fun WalletBankLogo(logo: WalletIssuerLogo?, name: String, onCard: Boolean) {\n    val lightMark = onCard || MaterialTheme.colorScheme.surface.luminance() < 0.3f')
    s=once(s,'painterResource(if (onCard) logo.cardDrawable else logo.drawable)', 'painterResource(if (lightMark) logo.cardDrawable else logo.drawable)')
    s=once(s,'private fun WalletNetworkLogo(network: WalletNetwork, onCard: Boolean = false) {',
        'private fun WalletNetworkLogo(network: WalletNetwork, onCard: Boolean = false) {\n    val lightMark = onCard || MaterialTheme.colorScheme.surface.luminance() < 0.3f')
    s=once(s,'if (onCard && network in listOf(WalletNetwork.VISA, WalletNetwork.AMEX))',
        'if (lightMark && network in listOf(WalletNetwork.VISA, WalletNetwork.AMEX))')
    s=once(s,'''                    Text("$bankName · ${walletLastFour(card.cardNumber)}", style = MaterialTheme.typography.bodySmall,
                        maxLines = 1, overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurfaceVariant)''', '''                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Text(bankName, modifier = Modifier.weight(1f, fill = false), style = MaterialTheme.typography.bodySmall,
                            maxLines = 1, overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(" · ${walletLastFour(card.cardNumber)}", style = MaterialTheme.typography.bodySmall,
                            maxLines = 1, softWrap = false, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }''')
    p.write_text(s)
p=J/'ui/wallet/WalletHomeHeader.kt';s=p.read_text()
if 'Modifier.weight(1f).horizontalScroll' not in s:
    s=once(s,'''            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(top = 4.dp, bottom = 8.dp),''',
        '''            Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 8.dp),''')
    s=once(s,'''            listOf(Triple("all", R.string.all_cards, allCount),''', '''            Row(Modifier.weight(1f).horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            listOf(Triple("all", R.string.all_cards, allCount),''')
    s=once(s,'''            WalletFavoritesChip(favoritesOnly, favoriteCount, onFavoritesChange)''', '''            }
            WalletFavoritesChip(favoritesOnly, favoriteCount, onFavoritesChange)''')
    p.write_text(s)
p=A/'app/src/test/java/com/example/creditcard/ui/wallet/WalletV2VisualTest.kt';s=p.read_text()
s=s.replace('compose.onNodeWithTag("wallet_favorites_filter").performScrollTo().performClick()',
    'compose.onNodeWithTag("wallet_favorites_filter").assertIsDisplayed().performClick()')
if 'fun emptyWalletHasOneAddAction' not in s:
    s=once(s,'private fun home(dark: Boolean = false, count: Int = 115, fontScale: Float = 1f)',
        'private fun home(dark: Boolean = false, count: Int = 115, fontScale: Float = 1f, attention: Boolean = false)')
    s=once(s,'DatabaseHelper(context).use { db -> repeat(count) { db.saveCard(sample(it)) } }',
        'DatabaseHelper(context).use { db -> repeat(count) { db.saveCard(if (attention && it == 0) sample(it).copy(valid = "01/20") else sample(it)) } }')
    s=once(s,'        capture("v2-small-large-font")',
        '        compose.onNodeWithTag("wallet_favorites_filter").assertIsDisplayed()\n        capture("v2-small-large-font")')
    s=once(s,'    private fun capture(name: String) {', '''    @Test fun emptyWalletHasOneAddAction() {
        home(count = 0)
        compose.onNodeWithTag("wallet_empty").assertIsDisplayed()
        assertEquals(1, compose.onAllNodesWithText("添加卡片").fetchSemanticsNodes().size)
        compose.onNodeWithTag("wallet_reminders").assertDoesNotExist()
        capture("v2-empty-wallet")
        compose.onNodeWithText("添加卡片").performClick()
        compose.onNodeWithText("新增信用卡").assertExists()
        compose.onNodeWithText("新增储蓄卡").assertExists()
    }

    @Test fun remindersUseAFloatingBadgeInsteadOfABanner() {
        home(attention = true)
        compose.onNodeWithTag("wallet_reminders").assertIsDisplayed()
        compose.onNodeWithText("发现", substring = true).assertDoesNotExist()
        capture("v2-home-with-reminder")
    }

    private fun capture(name: String) {''')
    p.write_text(s)
else: p.write_text(s)
print('Native screenshot findings fixed: dark logos, readable tails and pinned favorites; empty/reminder regressions added.')
