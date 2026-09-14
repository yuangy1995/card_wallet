#!/usr/bin/env python3
"""One-off, guarded integration on feat/android-wallet-card-list-favorites only."""
from pathlib import Path
import hashlib
import io
import json
import subprocess
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / 'apps/android'
JAVA = ANDROID / 'app/src/main/java/com/example/creditcard'
RES = ANDROID / 'app/src/main/res'

def replace_once(text, old, new):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'Expected exactly one integration anchor, got {count}: {old[:100]!r}')
    return text.replace(old, new, 1)

def read_url(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'CardWallet-brand-assets'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()

branch = subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip()
if branch != 'feat/android-wallet-card-list-favorites':
    raise RuntimeError('This one-off integration must not run on another branch')

main_file = JAVA / 'ui/main/MainScreen.kt'
main = main_file.read_text()
if 'import com.example.creditcard.ui.wallet.*' not in main:
    main = replace_once(main, 'import com.example.creditcard.ui.components.WalletSection',
        'import com.example.creditcard.ui.wallet.*\nimport com.example.creditcard.ui.components.WalletSection')
    main = replace_once(main,
        'fun from(value: String?): CardListGroupOption = entries.firstOrNull { it.storedValue == value } ?: BANK',
        'fun from(value: String?): CardListGroupOption = entries.firstOrNull { it.storedValue == value } ?: NONE')
    main = replace_once(main, '''    var isCompactView by remember {
        mutableStateOf(cardListPrefs.getBoolean("card_is_compact_view", false))
    }''', '''    val walletPreferences = rememberWalletPreferences()
    val isCompactView = walletPreferences.state.isList
    val favoriteCardIDs = walletPreferences.state.favorites
    var favoritesOnly by rememberSaveable { mutableStateOf(false) }''')
    main = replace_once(main, '''    LaunchedEffect(isCompactView) {
        cardListPrefs.edit().putBoolean("card_is_compact_view", isCompactView).apply()
    }
''', '')
    main = replace_once(main, '''    val filteredCards = remember(searchFilteredCards, cardCategoryFilter) {
        when (cardCategoryFilter) {
            "credit" -> searchFilteredCards.filter { it.cardCategory != "debit" }
            "debit" -> searchFilteredCards.filter { it.cardCategory == "debit" }
            else -> searchFilteredCards
        }
    }''', '''    val categoryCards = remember(searchFilteredCards, cardCategoryFilter) {
        when (cardCategoryFilter) {
            "credit" -> searchFilteredCards.filter { it.cardCategory != "debit" }
            "debit" -> searchFilteredCards.filter { it.cardCategory == "debit" }
            else -> searchFilteredCards
        }
    }
    val favoriteCount = categoryCards.count { it.id in favoriteCardIDs }
    val filteredCards = remember(categoryCards, favoriteCardIDs, favoritesOnly) {
        if (favoritesOnly) categoryCards.filter { it.id in favoriteCardIDs } else categoryCards
    }''')
    begin = main.index('                    val syncConfig = remember(context) { SyncCoordinator.loadConfig(context) }')
    end = main.index('                // 🧰 Tab 1:', begin)
    wallet = main[begin:end]
    wallet = replace_once(wallet, 'contentPadding = PaddingValues(bottom = 80.dp)', 'contentPadding = PaddingValues(bottom = 96.dp)')
    wallet = replace_once(wallet, 'verticalArrangement = Arrangement.spacedBy(12.dp)', 'verticalArrangement = Arrangement.spacedBy(0.dp)')
    header_start = wallet.index('                        // 1. 极简顶栏')
    header_end = wallet.index('                        item(key = "search")', header_start)
    header = '''                        item(key = "clean_header") {
                            Row(
                                Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 20.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                                    Text("CARD WALLET", style = MaterialTheme.typography.labelSmall,
                                        letterSpacing = 2.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text(stringResource(R.string.wallet_title), style = MaterialTheme.typography.headlineMedium,
                                        fontWeight = FontWeight.Bold)
                                    Text(stringResource(R.string.cards_count, cards.size),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                DynamicSyncBadge(
                                    isSyncing = syncStatus.isSyncing,
                                    isSyncAvailable = syncConfig.isReadyForSync,
                                    statusType = syncStatus.type,
                                    isDark = isDark,
                                    onSyncClick = {
                                        val message = syncConfig.syncUnavailableMessage()
                                        if (message != null) Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                                        else SyncCoordinator.requestManualSync(context)
                                    },
                                    onSyncingClick = { selectedTab = 1; toolsMode = ToolsMode.SYNC_LOG }
                                )
                                IconButton(onClick = { showCardManagement = !showCardManagement }) {
                                    Icon(if (showCardManagement) Icons.Default.Close else Icons.Default.Tune,
                                        stringResource(if (showCardManagement) R.string.close_manage else R.string.manage_cards),
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }

'''
    wallet = wallet[:header_start] + header + wallet[header_end:]
    wallet = replace_once(wallet, '                        // 4. 提醒汇总预警条', '''                        item(key = "wallet_view_controls") {
                            WalletViewControls(
                                isList = isCompactView,
                                onListModeChange = walletPreferences::setListMode,
                                favoritesOnly = favoritesOnly,
                                favoriteCount = favoriteCount,
                                onFavoritesChange = { favoritesOnly = it }
                            )
                        }

                        // 4. 提醒汇总预警条''')
    wallet = replace_once(wallet, 'items(groupCards, key = { it.id }) { card ->',
        'itemsIndexed(groupCards, key = { _, card -> card.id }) { index, card ->')
    wallet = replace_once(wallet,
        '.padding(horizontal = 16.dp, vertical = if (isCompactView) 0.dp else 4.dp)',
        '''.padding(horizontal = 20.dp)
                                            .padding(top = if (index == 0) 8.dp else 0.dp,
                                                bottom = if (index == groupCards.lastIndex) 16.dp else 0.dp)
                                            .zIndex(index.toFloat())''')
    wallet = replace_once(wallet, '''                                            CompactCardRow(
                                                card = card,''', '''                                            WalletListRow(
                                                card = card,
                                                favorite = card.id in favoriteCardIDs,
                                                onFavoriteClick = { walletPreferences.toggleFavorite(card.id) },
                                                first = index == 0,
                                                last = index == groupCards.lastIndex,''')
    wallet = replace_once(wallet, '''                                            CreditCardTile(
                                                card = card,
                                                isDark = isDark,''', '''                                            WalletCardFace(
                                                card = card,
                                                favorite = card.id in favoriteCardIDs,
                                                onFavoriteClick = { walletPreferences.toggleFavorite(card.id) },
                                                collapsed = index != groupCards.lastIndex && !selectionMode,''')
    wallet = replace_once(wallet,
        'stringResource(if (cards.isEmpty()) R.string.wallet_empty_title else R.string.wallet_no_results)',
        'stringResource(if (cards.isEmpty()) R.string.wallet_empty_title else if (favoritesOnly && searchQuery.isBlank()) R.string.wallet_no_favorites else R.string.wallet_no_results)')
    wallet = replace_once(wallet,
        'text = if (cards.isEmpty()) stringResource(R.string.wallet_empty_body) else "",',
        'text = if (cards.isEmpty()) stringResource(R.string.wallet_empty_body) else if (favoritesOnly) stringResource(R.string.wallet_favorites_body) else "",')
    main = main[:begin] + wallet + main[end:]
    main_file.write_text(main)

    detail_file = JAVA / 'ui/CardDetailScreen.kt'
    detail = detail_file.read_text()
    detail = replace_once(detail, 'package com.example.creditcard.ui\n',
        'package com.example.creditcard.ui\n\nimport com.example.creditcard.ui.wallet.*\n')
    detail = replace_once(detail, '    val isDebitCard = card.cardCategory == "debit"',
        '    val walletPreferences = rememberWalletPreferences()\n    val isDebitCard = card.cardCategory == "debit"')
    detail = replace_once(detail, '            CreditCardTile(card = card, isDark = isDark, onClick = {})', '''            WalletCardFace(
                card = card,
                favorite = card.id in walletPreferences.state.favorites,
                onFavoriteClick = { walletPreferences.toggleFavorite(card.id) },
                onClick = {}
            )''')
    detail_file.write_text(detail)

    color_file = JAVA / 'theme/Color.kt'
    colors = color_file.read_text()
    replacements = {
        '111715':'141B24', '1B2421':'1D2631', '9AD6C2':'B4D6D0', 'BEC9BE':'C4CED9',
        'F1F5F1':'F2F5F8', 'B0BEB7':'B7C2CD', 'F5F5EF':'F6F8F8', '246653':'202D3A',
        '405C50':'49656B', '1B3027':'202D3A', '5C6C63':'62717E', 'DCE3DA':'E0E6EA',
        '35453D':'364451', 'EBEFE7':'EBF0F2', '26362D':'293643'
    }
    for old, new in replacements.items():
        colors = replace_once(colors, '0xFF'+old, '0xFF'+new)
    colors = colors.replace('暖白背景配合克制的青绿色强调色', '云白背景、深墨色强调与清晰信息层次')
    color_file.write_text(colors)
    theme_file = JAVA / 'theme/Theme.kt'
    theme = theme_file.read_text()
    for old, new in {'294D40':'304852', '81958A':'889BAA', 'D9EBDF':'E0EAEE',
                     '193D2E':'243C4B', '728579':'748795'}.items():
        theme = replace_once(theme, '0xFF'+old, '0xFF'+new)
    theme_file.write_text(theme)

strings = {
    'values': {
        'wallet_favorites_count': 'Starred %1$d',
        'wallet_add_favorite': 'Star %1$s',
        'wallet_remove_favorite': 'Unstar %1$s',
        'wallet_valid_through': 'Valid thru %1$s',
        'wallet_network_unknown': 'Card network not identified',
        'wallet_no_favorites': 'No starred cards in this view',
        'wallet_favorites_body': 'Tap the star on a card to keep it close at hand.'
    },
    'values-zh': {
        'wallet_favorites_count': '我的星标 %1$d',
        'wallet_add_favorite': '收藏%1$s',
        'wallet_remove_favorite': '取消收藏%1$s',
        'wallet_valid_through': '有效期 %1$s',
        'wallet_network_unknown': '未识别卡组织',
        'wallet_no_favorites': '当前分类还没有星标卡片',
        'wallet_favorites_body': '轻点卡片上的星标，方便下次快速找到。'
    }
}
for locale, entries in strings.items():
    root = ET.Element('resources')
    for name, value in entries.items():
        ET.SubElement(root, 'string', name=name).text = value
    ET.indent(root)
    (RES / locale / 'wallet_ui.xml').write_text('<?xml version="1.0" encoding="utf-8"?>\n' + ET.tostring(root, encoding='unicode') + '\n')

# Assets are downloaded only by this integration script and committed into the app.
# Neither a normal Gradle build nor the running application contacts a logo service.
import cairosvg
from PIL import Image
BANK_REPO = 'icongo/bank-logos'
BANK_REV = 'ffca539a043900fbf2a4fd6a5d32f1706ae5dfd1'
NETWORK_REPO = 'aaronfagan/svg-credit-card-payment-icons'
NETWORK_REV = '6dd023ae32415ed7b01bf809f15a25613a52098c'
BANK_CANDIDATES = {
    'CMB':['cmbchina'], 'BOC':['boc'], 'ICBC':['icbc'], 'ABC':['abchina'],
    'CCB':['ccb'], 'BOCOM':['bankcomm'], 'CITIC':['citicbank'], 'CGB':['cgbchina'],
    'PINGAN':['pingan'], 'SPDB':['spdb'], 'CIB':['cib'], 'CEB':['cebbank'],
    'CMBC':['cmbc'], 'PSBC':['psbc'], 'HXB':['hxb'], 'HSBC':['hsbc'],
    'BOA':['bankofamerica'], 'CITI':['citibank','citi'], 'CHASE':['chase','jpmorganchase','jpmorgan'],
    'SC':['sc'], 'HANGSENG':['hangseng'], 'DBS':['dbs']
}
NETWORKS = ['visa','mastercard','amex','unionpay','jcb','discover','diners']
brand_dir = ANDROID / 'branding'
source_dir = brand_dir / 'sources'
source_dir.mkdir(parents=True, exist_ok=True)
drawable_dir = RES / 'drawable-nodpi'
drawable_dir.mkdir(parents=True, exist_ok=True)
asset_file = JAVA / 'ui/wallet/WalletBrandAssets.kt'
if not asset_file.exists():
    tree = json.loads(read_url(f'https://api.github.com/repos/{BANK_REPO}/git/trees/{BANK_REV}?recursive=1'))
    available = {item['path'] for item in tree['tree']}
    records = []
    bank_resources = {}
    network_resources = {}
    def convert(repo, rev, source_path, resource, width, height):
        url = f'https://raw.githubusercontent.com/{repo}/{rev}/{source_path}'
        svg = read_url(url)
        (source_dir / f'{resource}.svg').write_bytes(svg)
        png = cairosvg.svg2png(bytestring=svg, output_width=width, output_height=height)
        image = Image.open(io.BytesIO(png)).convert('RGBA')
        image.save(drawable_dir / f'{resource}.webp', format='WEBP', lossless=True)
        records.append({'resource':resource, 'url':url, 'source_sha256':hashlib.sha256(svg).hexdigest()})
    for bank, names in BANK_CANDIDATES.items():
        path = next((f'logos/{name}-rect.svg' for name in names if f'logos/{name}-rect.svg' in available), None)
        if path is None:
            print(f'No packaged issuer mark for {bank}; use the documented monogram fallback.')
            continue
        resource = 'wallet_bank_' + bank.lower()
        convert(BANK_REPO, BANK_REV, path, resource, 192, 192)
        bank_resources[bank] = resource
    for network in NETWORKS:
        resource = 'wallet_network_' + network
        convert(NETWORK_REPO, NETWORK_REV, f'flat-rounded/{network}.svg', resource, 192, 120)
        network_resources[network.upper()] = resource
    bank_resources['AMEX'] = network_resources['AMEX']
    assert all(bank in bank_resources for bank in ['CMB','BOC','ICBC','ABC','CCB','BOCOM','CITIC','CGB'])
    code = 'package com.example.creditcard.ui.wallet\n\nimport com.example.creditcard.R\n\n'
    code += '// Offline resources; sources and licenses are recorded in apps/android/branding.\n'
    code += 'internal object WalletBrandAssets {\n    fun bank(bank: WalletBank): Int? = when (bank) {\n'
    for bank, resource in bank_resources.items():
        code += f'        WalletBank.{bank} -> R.drawable.{resource}\n'
    code += '        else -> null\n    }\n\n    fun network(network: WalletNetwork): Int? = when (network) {\n'
    for network, resource in network_resources.items():
        code += f'        WalletNetwork.{network} -> R.drawable.{resource}\n'
    code += '        else -> null\n    }\n}\n'
    asset_file.write_text(code)
    (brand_dir / 'sources.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
    license_dir = ANDROID / 'app/src/main/assets/licenses'
    license_dir.mkdir(parents=True, exist_ok=True)
    for repo, rev, label in [(BANK_REPO,BANK_REV,'bank-logos'),(NETWORK_REPO,NETWORK_REV,'payment-icons')]:
        license_text = read_url(f'https://raw.githubusercontent.com/{repo}/{rev}/LICENSE').decode()
        (license_dir / f'{label}.txt').write_text(f'Source: https://github.com/{repo}/tree/{rev}\n\n' + license_text)
    print(f'Bundled {len(bank_resources)} issuer mappings and {len(network_resources)} networks.')

(brand_dir / 'README.md').write_text('''# Android 卡包品牌资源

银行标识来源于 icongo/bank-logos（MIT）；卡组织标识来源于 aaronfagan/svg-credit-card-payment-icons（Apache-2.0）。固定版本、原始地址及 SHA-256 见 sources.json；原始 SVG 位于 sources/。转换为 192px 无损 WebP，保留原始颜色与比例，最终资源位于 drawable-nodpi。

完整许可证随应用打包在 assets/licenses。所有银行及卡组织商标仍归各自权利人；标识仅用于识别用户自行录入的卡片，不代表官方合作、授权或认证。未找到对应资产的银行使用名称缩写，不借用其他银行标识。

应用运行及常规 Gradle 构建均不下载标识，也不向第三方发送卡号、银行名称或用户卡片数据。卡组织识别只根据本地号码前缀提供显示提示，不是完整 BIN 验证；不能可靠识别时使用通用卡片图标。
''')
print('Android UI integration complete; existing sync, storage, NFC, scanner and updater code was not modified.')
