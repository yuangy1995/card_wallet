from pathlib import Path
import subprocess, re, json

root = Path.cwd()
old = 'e8b8333b778927d9206b2f7a5d2a93ec52cf6bec'
subprocess.run(['git', 'diff', '--quiet', '7a0aadcf8e8cb90ee859585372c75d30b0fbebf2', 'HEAD', '--', 'apps', 'contracts', 'docs'], check=True)

def legacy(path):
    return subprocess.check_output(['git', 'show', f'{old}:{path}'], text=True)

def put(path, text):
    p = root / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)

transient = ['showCardNumber', 'showCVV', 'countryRowSpan', 'showCountry', 'bankRowSpan', 'showBank', 'limitRowSpan', 'showLimit', 'lastTimeRowSpan', 'showLastTime', 'cardId', 'uuid', 'legacyId', 'annualFeeDate', 'extraFields', 'constructor', 'prototype']
base = 'apps/android/app/src/main/java/com/example/creditcard/data/'
for name in ['SharedCard.kt', 'CardImageAsset.kt']:
    s = legacy(base + name).replace('emptyList()\n,', 'emptyList(),').replace('val name: String = ""\n,', 'val name: String = "",')
    put(base + name, s)
put(base + 'CardFutureFields.kt', '''package com.example.creditcard.data

/** Keep opaque fields from newer clients; never sync local UI state or legacy identities. */
internal object CardFutureFields {
    private val transient = setOf(''' + ', '.join(json.dumps(x) for x in transient) + ''')
    fun allowed(name: String) = !name.startsWith("_") && name !in transient
}
''')
p = root / 'apps/android/app/src/main/java/com/example/creditcard/ui/CardFormScreen.kt'
s = p.read_text()
assert '        cardImages = cardImages\n    )' in s
p.write_text(s.replace('        cardImages = cardImages\n    )', '        cardImages = cardImages,\n        extraFields = originalCard?.extraFields.orEmpty()\n    )'))

for platform in ['macos', 'ios']:
    path = f'apps/{platform}/Domain/CardJSONValue.swift'
    s = legacy(path)
    s = re.sub(r'static let transient: Set<String> = \[.*?\]', 'static let transient: Set<String> = [' + ', '.join(json.dumps(x) for x in transient) + ']', s)
    s = s.replace('    static func encode(_ fields:', '''    static func fromJSONObject(_ object: [String: Any], known: Set<String>) -> [String: CardJSONValue] {
        let fields = object.filter { !known.contains($0.key) && allowed($0.key) }
        guard JSONSerialization.isValidJSONObject(fields),
              let data = try? JSONSerialization.data(withJSONObject: fields),
              let decoded = try? JSONDecoder().decode([String: CardJSONValue].self, from: data) else { return [:] }
        return decoded
    }
    static func encode(_ fields:''')
    put(path, s)
    path = f'apps/{platform}/Domain/CardModels.swift'
    s = (root / path).read_text()
    ls = legacy(path)
    start = s.index('public struct CardImageAsset:')
    end = s.index('\npublic struct SharedCard:', start) if platform == 'macos' else s.index('\n/// 跨端同步主数据模型', start)
    lstart = ls.index('public struct CardImageAsset:')
    lend = ls.index('\npublic struct SharedCard:', lstart) if platform == 'macos' else ls.index('\n/// 跨端同步主数据模型', lstart)
    image = ls[lstart:lend]
    image = image.replace('name: String = ""\n', 'name: String = "",\n        extraFields: [String: CardJSONValue] = [:]\n')
    image = image.replace('        self.name = name\n', '        self.name = name\n        self.extraFields = extraFields\n')
    image = image.replace('private enum CodingKeys: String, CodingKey {', 'private enum CodingKeys: String, CodingKey, CaseIterable {')
    image = image.replace('    public init(from decoder: Decoder)', '    static let knownFieldNames = Set(CodingKeys.allCases.map(\\.rawValue))\n    public init(from decoder: Decoder)')
    image = image.replace('known: ["id", "mimeType", "data", "createdAt", "source", "name"]', 'known: Self.knownFieldNames')
    s = s[:start] + image + s[end:]
    s = s.replace('    public var cardImages: [CardImageAsset]\n', '    public var cardImages: [CardImageAsset]\n    public var extraFields: [String: CardJSONValue] = [:]\n')
    a, b = s.split('public struct SharedCard:', 1)
    b = b.replace('private enum CodingKeys: String, CodingKey {', 'private enum CodingKeys: String, CodingKey, CaseIterable {')
    b = b.replace('    public init(\n', '    static let knownFieldNames = Set(CodingKeys.allCases.map(\\.rawValue))\n\n    public init(\n', 1)
    b = b.replace('cardImages: [CardImageAsset] = []\n', 'cardImages: [CardImageAsset] = [],\n        extraFields: [String: CardJSONValue] = [:]\n')
    b = b.replace('        self.cardImages = cardImages\n', '        self.cardImages = cardImages\n        self.extraFields = extraFields\n')
    b = b.replace('        self.cardImages = (try? container.decode([CardImageAsset].self, forKey: .cardImages)) ?? []\n', '        self.cardImages = (try? container.decode([CardImageAsset].self, forKey: .cardImages)) ?? []\n        self.extraFields = try CardFutureFields.decode(from: decoder, known: Self.knownFieldNames)\n')
    if platform == 'ios':
        enc = ls[ls.index('    public func encode(to encoder: Encoder)', ls.index('public struct SharedCard:')):]
        enc = enc[:enc.index('    private static func normalizeCardCategory')]
        enc = re.sub(r'known: \[.*?\]', 'known: Self.knownFieldNames', enc)
        b = b.replace('    private static func normalizeCardCategory', enc + '    private static func normalizeCardCategory', 1)
    else:
        b = b.replace('    public func encode(to encoder: Encoder) throws {\n', '    public func encode(to encoder: Encoder) throws {\n        try CardFutureFields.encode(extraFields, to: encoder, known: Self.knownFieldNames)\n', 1)
    put(path, a + 'public struct SharedCard:' + b)
    p = root / f'apps/{platform}/Features/CardEditView.swift'
    s = p.read_text()
    assert '            cardImages: cardImages\n        )' in s
    p.write_text(s.replace('            cardImages: cardImages\n        )', '            cardImages: cardImages,\n            extraFields: cardToEdit?.extraFields ?? [:]\n        )'))

p = root / 'apps/macos/Domain/DataMigrationManager.swift'
s = p.read_text()
s = s.replace('            cardImages: cardImages\n        )', '            cardImages: cardImages,\n            extraFields: CardFutureFields.fromJSONObject(dict, known: SharedCard.knownFieldNames)\n        )')
s = s.replace('                name: (dict["name"] as? String) ?? ""\n', '                name: (dict["name"] as? String) ?? "",\n                extraFields: CardFutureFields.fromJSONObject(dict, known: CardImageAsset.knownFieldNames)\n')
p.write_text(s)
put('apps/web/src/utils/cardFutureFields.js', '''// Forward fields are opaque JSON, not editable UI or a new sync protocol.
const transient = new Set(''' + json.dumps(transient) + ''')
export const allowedCardField = name => !name.startsWith('_') && !transient.has(name)
export const futureCardFields = (value, known) => Object.fromEntries(
  Object.entries(value).filter(([name]) => !known.has(name) && allowedCardField(name))
)
''')
p = root / 'apps/web/src/utils/cardDataMigration.js'
s = "import { futureCardFields } from './cardFutureFields'\n" + p.read_text()
s = s.replace('  const migratedCard = { ...DEFAULT_CARD_DATA }', '  const migratedCard = { ...futureCardFields(oldCard, new Set(Object.keys(DEFAULT_CARD_DATA))), ...DEFAULT_CARD_DATA }')
s = s.replace('      return {\n        id: item.id || crypto.randomUUID(),', "      return {\n        ...futureCardFields(item, new Set(['id', 'mimeType', 'data', 'createdAt', 'source', 'name'])),\n        id: item.id || crypto.randomUUID(),")
p.write_text(s)
fixture = {
    'id': 'forward-fields-fixture', 'cardCategory': 'credit', 'country': 'US', 'bank': 'SyntheticBank', 'cardNumber': '', 'alias': 'before', 'lastModifyTime': 1789725600000,
    'futureProgram': {'label': 'opaque', 'enabled': True, 'amount': 1234.5, 'items': [1, 'two', None, False, {'nested': '保留'}]},
    'futureNull': None, 'showCVV': True, '_localOnly': 'must-not-sync', 'legacyId': 'must-not-sync', 'extraFields': {'invalid': 'wrapper'},
    'cardImages': [{'id': 'image-fixture', 'mimeType': 'image/jpeg', 'data': 'data:image/jpeg;base64,/9j/2Q==', 'createdAt': 1789725600000, 'source': 'fixture', 'name': 'synthetic.jpg', 'futureImage': {'rotation': 90, 'labels': ['one', 'two']}, 'showCVV': True, '_localOnly': 'must-not-sync'}]
}
put('contracts/card-wallet/fixtures/unknown-fields.json', json.dumps(fixture, indent=2, ensure_ascii=False) + '\n')
put('apps/web/src/utils/cardFutureFields.test.js', '''import { describe, it, expect } from 'vitest'
import fixture from '../../../../contracts/card-wallet/fixtures/unknown-fields.json'
import { migrateCardData } from './cardDataMigration'
import { activeRecord, mergeRecords } from './syncProtocol'
import { futureCardFields } from './cardFutureFields'

describe('opaque future fields from older integration branches', () => {
  it('preserves all JSON values through migration, editing and sync', () => {
    const migrated = migrateCardData(structuredClone(fixture))
    const edited = { ...migrated, alias: 'edited' }
    const synced = mergeRecords([activeRecord(edited)]).find(x => x.cardId === fixture.id).card
    expect(synced.futureProgram).toEqual(fixture.futureProgram)
    expect(synced.futureNull).toBeNull()
    expect(synced.cardImages[0].futureImage).toEqual(fixture.cardImages[0].futureImage)
    expect(synced.alias).toBe('edited')
    for (const key of ['showCVV', '_localOnly', 'legacyId', 'extraFields']) expect(synced).not.toHaveProperty(key)
    for (const key of ['showCVV', '_localOnly']) expect(synced.cardImages[0]).not.toHaveProperty(key)
  })
  it('does not let opaque fields shadow identity or introduce prototype keys', () => {
    const input = JSON.parse('{"id":"shadow","constructor":{},"prototype":{},"__proto__":{"polluted":true},"future":null}')
    const extra = futureCardFields(input, new Set(['id']))
    expect(extra).toEqual({ future: null })
    expect({}.polluted).toBeUndefined()
  })
  it('preserves fields across repeated migrations', () => {
    const once = migrateCardData(structuredClone(fixture))
    expect(migrateCardData(JSON.parse(JSON.stringify(once)))).toEqual(once)
  })
})
''')
put('apps/android/app/src/test/java/com/example/creditcard/data/CardFutureFieldsTest.kt', '''package com.example.creditcard.data

import com.example.creditcard.utils.AppJson
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class CardFutureFieldsTest {
    private fun fixture(): JsonObject = checkNotNull(javaClass.classLoader?.getResourceAsStream("unknown-fields.json"))
        .bufferedReader().use { AppJson.json.parseToJsonElement(it.readText()).jsonObject }

    @Test fun preservesCardAndImageFieldsThroughEditingAndRoundTrip() {
        val input = fixture()
        val card = AppJson.json.decodeFromJsonElement<SharedCard>(input)
        val edited = card.copy(alias = "edited")
        val encoded = AppJson.json.encodeToJsonElement(edited).jsonObject
        assertEquals(input["futureProgram"], encoded["futureProgram"])
        assertEquals(JsonNull, encoded["futureNull"])
        assertEquals(input["cardImages"]!!.jsonArray[0].jsonObject["futureImage"], encoded["cardImages"]!!.jsonArray[0].jsonObject["futureImage"])
        assertEquals("edited", encoded["alias"]!!.jsonPrimitive.content)
        for (key in listOf("showCVV", "_localOnly", "legacyId", "extraFields")) assertFalse(encoded.containsKey(key))
        for (key in listOf("showCVV", "_localOnly")) assertFalse(encoded["cardImages"]!!.jsonArray[0].jsonObject.containsKey(key))
        assertEquals(edited, AppJson.json.decodeFromString<SharedCard>(AppJson.json.encodeToString(edited)))
    }

    @Test fun knownFieldsCannotBeShadowedEvenWhenDefaultsAreNotEncoded() {
        val card = SharedCard(id = "real", extraFields = mapOf("id" to JsonPrimitive("shadow"), "limit" to JsonPrimitive(999), "constructor" to JsonPrimitive("bad"), "future" to JsonNull))
        val encoded = Json.encodeToJsonElement(card).jsonObject
        assertEquals("real", encoded["id"]!!.jsonPrimitive.content)
        assertFalse(encoded.containsKey("limit"))
        assertFalse(encoded.containsKey("constructor"))
        assertEquals(JsonNull, encoded["future"])
    }

    @Test fun syncRecordRoundTripKeepsFutureFields() {
        val card = AppJson.json.decodeFromJsonElement<SharedCard>(fixture())
        val json = AppJson.json.encodeToString(card)
        assertEquals(card.extraFields, AppJson.json.decodeFromString<SharedCard>(json).extraFields)
        assertEquals(card.cardImages.single().extraFields, AppJson.json.decodeFromString<SharedCard>(json).cardImages.single().extraFields)
    }
}
''')
p = root / 'apps/android/app/src/androidTest/java/com/example/creditcard/LocalVaultInstrumentedTest.kt'
s = p.read_text().replace('import java.security.KeyStore', 'import kotlinx.serialization.json.JsonPrimitive\nimport java.security.KeyStore')
s = s.replace('CardImageAsset(id="image", data="A".repeat(2_200_000))', 'CardImageAsset(id="image", data="A".repeat(2_200_000), extraFields=mapOf("futureImage" to JsonPrimitive("kept")))')
s = s.replace('extraFields=mapOf("futureImage" to JsonPrimitive("kept")))))', 'extraFields=mapOf("futureImage" to JsonPrimitive("kept")))), extraFields=mapOf("future" to JsonPrimitive("kept")))')
p.write_text(s)
for platform, module in [('macos', 'CreditCardMac'), ('ios', 'CreditCardIOS')]:
    test = '''import XCTest
@testable import MODULE

final class CardFutureFieldsTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "unknown-fields", withExtension: "json", subdirectory: "fixtures"))
        return try Data(contentsOf: url)
    }
    func testCardAndImageFieldsSurviveEditingAndCodableRoundTrip() throws {
        let data = try fixtureData()
        let input = try JSONDecoder().decode([String: CardJSONValue].self, from: data)
        var card = try JSONDecoder().decode(SharedCard.self, from: data)
        card.alias = "edited"
        let encoded = try JSONEncoder().encode(card)
        let output = try JSONDecoder().decode([String: CardJSONValue].self, from: encoded)
        XCTAssertEqual(output["futureProgram"], input["futureProgram"])
        XCTAssertEqual(output["futureNull"], .null)
        XCTAssertEqual(card.cardImages.first?.extraFields["futureImage"], .object(["rotation": .number(90), "labels": .array([.string("one"), .string("two")])]))
        for key in ["showCVV", "_localOnly", "legacyId", "extraFields"] { XCTAssertNil(output[key]) }
        XCTAssertNil(card.cardImages.first?.extraFields["showCVV"])
        XCTAssertEqual(try JSONDecoder().decode(SharedCard.self, from: encoded), card)
    }
    func testOpaqueFieldsNeverOverrideKnownFieldsOrIntroducePrototypeKeys() throws {
        var card = SharedCard(id: "real", country: "", bank: "", cardNumber: "")
        card.extraFields = ["id": .string("shadow"), "limit": .number(999), "constructor": .string("bad"), "future": .null]
        let output = try JSONDecoder().decode([String: CardJSONValue].self, from: JSONEncoder().encode(card))
        XCTAssertEqual(output["id"], .string("real"))
        XCTAssertEqual(output["limit"], .number(0))
        XCTAssertNil(output["constructor"])
        XCTAssertEqual(output["future"], .null)
    }
    func testSyncRecordRoundTripPreservesOpaqueFields() throws {
        let card = try JSONDecoder().decode(SharedCard.self, from: fixtureData())
        let record = CardSyncRecord.activeUsingCardTimestamp(card)
        let decoded = try JSONDecoder().decode(CardSyncRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded.card?.extraFields, card.extraFields)
        XCTAssertEqual(decoded.card?.cardImages, card.cardImages)
    }
'''.replace('MODULE', module)
    if platform == 'macos':
        test += '''    func testLegacyDictionaryBackupImportPreservesOpaqueFields() throws {
        let cards = try XCTUnwrap(DataMigrationManager.cardsFromBackupJSON("[" + String(decoding: fixtureData(), as: UTF8.self) + "]"))
        let original = try JSONDecoder().decode(SharedCard.self, from: fixtureData())
        XCTAssertEqual(cards.first?.extraFields, original.extraFields)
        XCTAssertEqual(cards.first?.cardImages.first?.extraFields, original.cardImages.first?.extraFields)
    }
'''
    put(f'apps/{platform}/Tests/CardFutureFieldsTests.swift', test + '}\n')

# Keep the existing Xcode file references valid.
for platform in ['macos', 'ios']:
    model = root / f'apps/{platform}/Domain/CardModels.swift'
    codec = root / f'apps/{platform}/Domain/CardJSONValue.swift'
    model.write_text(model.read_text() + '\n' + codec.read_text().replace('import Foundation\n', '', 1))
    codec.unlink()
    tests = root / f'apps/{platform}/Tests/LocalParityTests.swift'
    added = root / f'apps/{platform}/Tests/CardFutureFieldsTests.swift'
    text = added.read_text()
    text = text[text.index('final class CardFutureFieldsTests'):]
    tests.write_text(tests.read_text() + '\n' + text)
    added.unlink()

put('docs/retired-branches-integration-2026-09-18.md', '''# 两个旧对齐分支的实际整合与冲突处理

整合对象：`e8b8333b778927d9206b2f7a5d2a93ec52cf6bec` 和 `6948ec4e68eb54a6bda743c697e1e47c3affbbb1`。整合前业务代码基准为 main `7a0aadcf8e8cb90ee859585372c75d30b0fbebf2`。这不是直接覆盖或保留当前树的空合并。

## 逐类决议

| 旧分支内容 | 整合结果 |
| --- | --- |
| CardFutureFields、CardJSONValue、卡片与图片 extraFields | 迁移到三端原生模型，并补齐 Web 的导入保留逻辑。编辑、备份导入、同步和本地加密存储均保留未知 JSON；过滤本机 UI 状态、旧身份别名和危险属性名。 |
| CalendarRules、Metrics、Search、Operations 与旧测试数据 | 采用 main 的 WalletCardRules、cardCatalog、提醒、批量操作和共用 fixtures；不恢复同一业务的第二套实现。原有测试不删除，额外加入共用 unknown-fields fixture 和四端回归。 |
| Android v5 encrypted_payload、替代密钥别名及本地偏好加密方案 | 冲突选择 main 的 v4 分块密文、AAD 与 card_wallet_local_data_v1；保留大图片读写、丢失密钥失败保护和真实 AndroidKeyStore 回归，不更换数据库结构。 |
| Apple LocalWalletCipher、WebDAVSessionRegistry、锁定与引导流程 | 冲突选择 main 已落实的 LocalDataCipher、钥匙串错误处理、串行/原子写入、锁定保护和网络生命周期，避免恢复旧存储和并行状态实现。 |
| 旧品牌、界面和无障碍实现 | 保留 main 的四端离线素材、主题、图片策略、搜索排序、本机收藏和当前界面；不回退旧品牌判断或未完成界面。 |
| .parity-final 载荷、parity-apply/source/resume/workspace 临时流程、旧签名 | 不进入最终代码树；它们是传输/执行中间产物或已泄漏材料，不作为产品能力保留。完整原始 Git 备份已在仓库外加密保存。 |

两个旧分支互相比对，领域数据层的未知字段实现相同；completion 中额外的引导、主题修补及 sync-cases/schema 与 main 对照后采用当前主线的已完成实现。整合提交保留两个父分支的祖先关系。删除分支必须在整合后的四端 CI 全部成功后执行，并验证祖先关系与精确 SHA 租约；运行失败不删除。

## 验证范围

新增共同 JSON 夹具包含嵌套对象、数组、数值、布尔、null 与图片扩展信息。测试覆盖编辑、序列化往返、同步记录、Mac 字典备份导入以及 Android 真实加密数据库大图片往返。Swift JSON 编解码在本地完成编译与执行；完整原生、浏览器、Lint 和设备测试以本次 GitHub Actions 的最终结论为准。

签名 Secrets 上传和正式发布是独立门禁。代码整合成功不代表新密钥已经存入 Secrets，也不代表历史泄漏已从 GitHub 缓存清除。
''')
print('Reviewed source integration prepared; no credentials were read or written.')
