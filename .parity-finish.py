from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parent

def read(name):
    return (ROOT / name).read_text()

def write(name, value):
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value)

def edit(name, old, new, count=1):
    value = read(name)
    assert value.count(old) == count, (name, old[:80], value.count(old))
    write(name, value.replace(old, new))

# Fix the failing native SQLite regression without weakening or removing the test.
edit('apps/android/app/src/main/java/com/example/creditcard/data/DatabaseHelper.kt',
     'db.execSQL("PRAGMA secure_delete=ON")',
     'db.rawQuery("PRAGMA secure_delete=ON", null).use { cursor ->\n            check(cursor.moveToFirst() && cursor.getInt(0) == 1) { "无法启用本地数据清理保护" }\n        }')

# Shared offline artwork and provenance; no network request or new source of logos.
subprocess.run(['python3', 'scripts/sync-wallet-brand-assets.py'], cwd=ROOT, check=True)
write('apps/ios/Domain/WalletLogoCatalog.swift', read('apps/macos/Domain/WalletLogoCatalog.swift'))
logo = read('apps/macos/Features/WalletBankLogo.swift').replace('import AppKit', 'import UIKit')
logo = logo.replace('NSImage(named: NSImage.Name(resource))', 'UIImage(named: resource)')
write('apps/ios/Features/WalletBankLogo.swift', logo)
write('apps/ios/Features/CardBrandIcon.swift', '''import SwiftUI

/// Offline artwork; display hint only, preserving the existing iOS sizing API.
struct CardBrandIcon: View {
    let brand: CardBrand
    var size: CGFloat = 38
    var isForCardFace = false
    @Environment(\\.colorScheme) private var colorScheme
    var body: some View {
        WalletBrandImage(resource: brand.logoResource, label: NSLocalizedString(brand.displayName, comment: ""),
                         lightMark: isForCardFace,
                         whiteTemplate: (isForCardFace || colorScheme == .dark) && (brand == .visa || brand == .amex),
                         width: size * 1.65, height: size)
    }
}
extension CardBrand {
    var logoResource: String? {
        guard self != .unknown else { return nil }
        return "wallet_network_" + (self == .dinersClub ? "diners" : rawValue)
    }
}
''')

# Preserve Mac's explicit level hints; all fallback number boundaries follow the same rules.
mac_models = read('apps/macos/Domain/CardModels.swift')
start = mac_models.index('    public static func detect(')
end = mac_models.index('    /// 获取品牌', start)
detect = mac_models[start:end]
ios_models = read('apps/ios/Domain/CardModels.swift')
start = ios_models.index('    public static func detect(')
end = ios_models.index('    public var displayName:', start)
write('apps/ios/Domain/CardModels.swift', ios_models[:start] + detect + ios_models[end:])

for name in ['apps/ios/App/CreditCardIOSApp.swift', 'apps/ios/Features/SettingsView.swift']:
    value = read(name)
    value, count = re.subn(r'(@AppStorage\("app_appearance"\)[^\n]*= )"light"', r'\1"system"', value)
    assert count == 1, name
    write(name, value)

view = 'apps/ios/Features/CreditCardView.swift'
edit(view, '                HStack(alignment: .top) {\n                    VStack',
     '                HStack(alignment: .top) {\n                    WalletBankLogo(bank: card.bank, country: card.country, onCard: true, width: 32, height: 28).accessibilityHidden(true)\n                    VStack')
edit(view, '            CardBrandIcon(brand: brand, size: 26)\n                .frame(width: 52, height: 34)',
     '            WalletBankLogo(bank: card.bank, country: card.country, width: 38, height: 32).accessibilityHidden(true)')
edit(view, '            // 年费预警指示', '            CardBrandIcon(brand: brand, size: 20)\n\n            // 年费预警指示')
# Size against the parent, not the physical screen, for iPad split view and sheet presentations.
edit(view, '        let cardWidth = UIScreen.main.bounds.width - 40\n        let cardHeight = cardWidth / 1.586\n', '')
edit(view, '        .frame(width: cardWidth, height: cardHeight)', '        .frame(maxWidth: .infinity)\n        .aspectRatio(1.586, contentMode: .fit)')

network = 'apps/android/app/src/main/java/com/example/creditcard/ui/wallet/WalletBrand.kt'
value = read(network)
needle = '        /** Local display hint, not a BIN lookup or a validation of card ownership. */'
assert value.count(needle) == 1
value = value.replace(needle, '''        /** An unambiguous level hint wins; multiple hints fall back to the number. */
        fun fromCard(number: String, level: String = ""): WalletNetwork {
            val value = level.lowercase(Locale.ROOT)
            val words = value.split(Regex("[^\\\\p{L}\\\\p{N}]+")).filter { it.isNotEmpty() }.toSet()
            val hints = mutableSetOf<WalletNetwork>()
            if (value.contains("银联") || value.contains("銀聯") || "unionpay" in words) hints.add(UNIONPAY)
            if ("discover" in words || value.contains("发现") || value.contains("發現")) hints.add(DISCOVER)
            if ("visa" in words) hints.add(VISA)
            if ("mastercard" in words || value.contains("万事达") || value.contains("萬事達")) hints.add(MASTERCARD)
            if ("jcb" in words) hints.add(JCB)
            if ("amex" in words || "ae" in words || value.contains("american express") || value.contains("运通") || value.contains("運通")) hints.add(AMEX)
            if ("diners" in words || value.contains("大莱") || value.contains("大萊")) hints.add(DINERS)
            return hints.singleOrNull() ?: fromNumber(number)
        }

''' + needle)
value = value.replace('Unknown issuers keep a neutral monogram.', 'Unknown issuers use a generic card icon.')
write(network, value)
main = 'apps/android/app/src/main/java/com/example/creditcard/ui/main/MainScreen.kt'
value = read(main)
start = value.index('fun getCardBrand(cardNumber: String): String {')
end = value.index('\n}\n', start) + 3
value = value[:start] + '''fun getCardBrand(cardNumber: String, level: String = ""): String {
    val network = com.example.creditcard.ui.wallet.WalletNetwork.fromCard(cardNumber, level)
    return when (network) {
        com.example.creditcard.ui.wallet.WalletNetwork.AMEX -> "Amex"
        com.example.creditcard.ui.wallet.WalletNetwork.UNKNOWN -> "Unknown"
        else -> network.label
    }
}
''' + value[end:]
write(main, value)
for path in (ROOT / 'apps/android/app/src/main/java').rglob('*.kt'):
    value = path.read_text()
    value = re.sub(r'getCardBrand\((\w+)\.cardNumber\)', r'getCardBrand(\1.cardNumber, \1.level)', value)
    value = value.replace('remember(card.cardNumber) { WalletNetwork.fromNumber(card.cardNumber) }',
                          'remember(card.cardNumber, card.level) { WalletNetwork.fromCard(card.cardNumber, card.level) }')
    value = value.replace('remember(card.cardNumber) { getCardBrand(card.cardNumber, card.level) }',
                          'remember(card.cardNumber, card.level) { getCardBrand(card.cardNumber, card.level) }')
    if value != path.read_text(): path.write_text(value)

write('apps/web/src/utils/cardBrand.js', r'''// Display hints only. Unambiguous level hints and number boundaries match the native clients.
export function cardOrganization(card = {}) {
  const value = String(card.level || '').toLowerCase()
  const words = new Set(value.split(/[^\p{L}\p{N}]+/u).filter(Boolean))
  const hints = new Set()
  if (/银联|銀聯/.test(value) || words.has('unionpay')) hints.add('unionpay')
  if (words.has('discover') || /发现|發現/.test(value)) hints.add('discover')
  if (words.has('visa')) hints.add('visa')
  if (words.has('mastercard') || /万事达|萬事達/.test(value)) hints.add('mastercard')
  if (words.has('jcb')) hints.add('jcb')
  if (words.has('amex') || words.has('ae') || /american express|运通|運通/.test(value)) hints.add('amex')
  if (words.has('diners') || /大莱|大萊/.test(value)) hints.add('diners')
  if (hints.size === 1) return [...hints][0]
  const digits = String(card.cardNumber || '').replace(/[^0-9]/g, '')
  const length = digits.length
  if (length < 4) return 'other'
  const two = Number(digits.slice(0, 2)), three = Number(digits.slice(0, 3)), four = Number(digits.slice(0, 4))
  if (length === 15 && [34, 37].includes(two)) return 'amex'
  if (length === 16 && ((two >= 51 && two <= 55) || (four >= 2221 && four <= 2720))) return 'mastercard'
  if (length >= 16 && length <= 19 && four >= 3528 && four <= 3589) return 'jcb'
  if (length >= 16 && length <= 19 && (four === 6011 || two === 65 || (three >= 644 && three <= 649))) return 'discover'
  if ([13, 16, 19].includes(length) && digits.startsWith('4')) return 'visa'
  if (length >= 16 && length <= 19 && [62, 81].includes(two)) return 'unionpay'
  if (length === 14 && ((three >= 300 && three <= 305) || [36, 38, 39].includes(two))) return 'diners'
  return 'other'
}
export const cardOrganizationName = value => ({ visa: 'VISA', mastercard: 'MasterCard', amex: '美国运通', unionpay: '银联', discover: 'Discover', jcb: 'JCB', diners: 'Diners Club', other: '其他卡组织' })[value] || '其他卡组织'
''')
# Keep boundary cases, but use full-length synthetic numbers under the now-explicit contract.
path = 'apps/web/src/utils/cardMetrics.test.js'
value = read(path)
for short, full in [('222100','2221000000000000'), ('272000','2720000000000000'), ('272100','2721000000000000'), ('358900','3589000000000000'), ('644123','6441230000000000'), ('361234','36123400000000'), ('621234','6212340000000000')]:
    assert ("['" + short + "',") in value
    value = value.replace("['" + short + "',", "['" + full + "',")
write(path, value)

mark = 'apps/web/src/components/common/WalletBrandMark.vue'
edit(mark, 'computed, ref, watch', 'computed, ref, watch, inject, unref')
edit(mark, 'const failed = ref(false)', "const failed = ref(false)\nconst theme = inject('theme', null)\nconst dark = computed(() => Boolean(unref(theme?.isDarkMode)))")
edit(mark, "${props.onCard ? '_card' : ''}", "${props.onCard || dark.value ? '_card' : ''}")
edit(mark, "props.onCard && ['visa', 'amex']", "(props.onCard || dark.value) && ['visa', 'amex']")
physics = 'apps/web/src/components/card/CreditCardPhysicsCard.vue'
value = read(physics)
value, count = re.subn(r'            <!-- 像素级卡组织.*?(?=          </div>\n        </div>)',
                     '            <WalletBrandMark :network="cardOrganization" on-card />\n', value, flags=re.S)
assert count == 1
value = value.replace("<span class=\"bank-name\">{{ card.bank || '' }}</span>",
                      "<div class=\"bank-heading\"><WalletBrandMark :bank=\"card.bank\" :country=\"card.country\" on-card /><span class=\"bank-name\">{{ card.bank || '' }}</span></div>")
value = value.replace('<script setup>', '<script setup>\nimport WalletBrandMark from \'../common/WalletBrandMark.vue\'')
value += '\n<style scoped>\n.bank-heading { display:flex; align-items:center; gap:8px; min-width:0; }\n.bank-heading .bank-name { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }\n.card-header .bank-info { min-width:0; flex:1; }\n.card-header .card-logo { flex-shrink:0; margin-left:8px; max-width:50%; }\n.card-level-badge { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; min-width:0; }\n</style>\n'
write(physics, value)

table = 'apps/web/src/components/table/CreditCardTable.vue'
edit(table, "import SecureField from '../common/SecureField.vue'", "import SecureField from '../common/SecureField.vue'\nimport WalletBrandMark from '../common/WalletBrandMark.vue'")
edit(table, '    SecureField,', '    SecureField,\n    WalletBrandMark,')
edit(table, '          <template v-else-if="column.value === \'cvv\'" #default="scope">',
     '          <template v-else-if="column.value === \'bank\'" #default="{ row }">\n            <span class="wallet-bank-cell"><WalletBrandMark :bank="row.bank" :country="row.country" /><span>{{ row.bank }}</span></span>\n          </template>\n          <template v-else-if="column.value === \'cvv\'" #default="scope">')
value = read(table) + '\n<style scoped>\n.wallet-bank-cell { display:inline-flex; align-items:center; gap:6px; max-width:100%; }\n.wallet-bank-cell .wallet-brand-mark { width:24px; height:24px; }\n.wallet-bank-cell > span:last-child { min-width:0; overflow-wrap:anywhere; }\n</style>\n'
write(table, value)
details = 'apps/web/src/components/dialog/CardDetailsDialog.vue'
edit(details, "import { inject, watch } from 'vue'", "import { inject, watch } from 'vue'\nimport WalletBrandMark from '../common/WalletBrandMark.vue'")
edit(details, "  name: 'CardDetailsDialog',", "  name: 'CardDetailsDialog',\n  components: { WalletBrandMark },")
edit(details, '<el-descriptions-item label="银行">{{ cardInfo.bank }}</el-descriptions-item>',
     '<el-descriptions-item label="银行"><WalletBrandMark :bank="cardInfo.bank" :country="cardInfo.country" /> {{ cardInfo.bank }}</el-descriptions-item>', 2)

# Localize the new Apple controls without changing existing translations.
translations = {
    '收藏': ('收藏', 'Favorite'), '取消收藏': ('取消收藏', 'Remove favorite'),
    '只看收藏': ('只看收藏', 'Favorites only'), '仅看收藏': ('僅看收藏', 'Favorites only'),
    '全部卡片': ('全部卡片', 'All cards'), '搜索银行、卡号、备注或权益': ('搜尋銀行、卡號、備註或權益', 'Search bank, card number, notes or benefits'),
    '银行卡': ('銀行卡', 'Bank card'), '跟随系统': ('跟隨系統', 'System'),
    '无法读取本地加密数据，原始文件已保留。请检查本机钥匙串或从备份恢复。': ('無法讀取本機加密資料，原始檔案已保留。請檢查本機鑰匙圈或從備份還原。', 'Unable to read local encrypted data. The original files are unchanged. Check this device’s keychain or restore a backup.')
}
for platform in ['ios', 'macos']:
    name = f'apps/{platform}/Resources/Localizable.xcstrings'
    path = ROOT / name
    catalog = json.loads(path.read_text()) if path.exists() else {'sourceLanguage':'zh-Hans', 'strings':{}, 'version':'1.0'}
    for key, (traditional, english) in translations.items():
        item = catalog['strings'].setdefault(key, {})
        localizations = item.setdefault('localizations', {})
        for language, text in [('zh-Hant', traditional), ('en', english)]:
            localizations.setdefault(language, {'stringUnit': {'state':'translated', 'value':text}})
    write(name, json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
key = '无法读取本地加密数据，原始文件已保留。请检查本机钥匙串或从备份恢复。'
edit('apps/ios/Domain/CryptoManager.swift', 'case .decryptionFailed: return "' + key + '"',
     'case .decryptionFailed: return NSLocalizedString("' + key + '", comment: "")')
