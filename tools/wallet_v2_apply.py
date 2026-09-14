#!/usr/bin/env python3
"""Final review cleanup of this feature's Android files only."""
from pathlib import Path
from collections import Counter
import subprocess, json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'apps/android';J=A/'app/src/main/java/com/example/creditcard'
if subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()!='feat/android-wallet-redesign-v2':
    raise RuntimeError('Feature branch required')
manifest=json.loads((A/'branding/catalog.json').read_text())
if manifest.get('asset_revision',0)<2: raise RuntimeError('Reviewed logo revision required')
p=A/'app/src/test/java/com/example/creditcard/ui/wallet/WalletV2VisualTest.kt';s=p.read_text()
if 'import androidx.compose.ui.semantics.getOrNull' not in s:
    s=s.replace('import androidx.compose.ui.semantics.SemanticsProperties','import androidx.compose.ui.semantics.SemanticsProperties\nimport androidx.compose.ui.semantics.getOrNull')
s=s.replace('header.height.value < 230f','(header.bottom - header.top).value < 230f')
s=s.replace('assertTrue(compose.onNodeWithTag("wallet_theme_picker").getUnclippedBoundsInRoot().height.value < 100f)',
    'compose.onNodeWithTag("wallet_theme_picker").assertHeightIsAtMost(100.dp)')
p.write_text(s)
# Complex multicolour marks cannot be flattened into a featureless white square/circle.
algorithm='''def card_variant(image):
    pixels=list(image.getdata())
    opaque=[(r,g,b) for r,g,b,a in pixels if a>200 and min(r,g,b)<240]
    from collections import Counter
    bins=Counter((r//40,g//40,b//40) for r,g,b in opaque)
    multicolour=sum(count>len(opaque)*0.05 for count in bins.values())>=2
    coverage=sum(a>200 for r,g,b,a in pixels)/len(pixels)
    if multicolour and coverage>0.70:
        return image.copy()
    result=Image.new('RGBA',image.size)
    result.putdata([(255,255,255,0 if min(r,g,b)>245 else a) for r,g,b,a in pixels])
    if result.getchannel('A').getbbox() is None: result.putalpha(image.getchannel('A'))
    return result

'''
p=A/'branding/build_catalog.py';s=p.read_text()
if 'def card_variant(image):' not in s:
    s=s.replace('assets=[]; excluded=[]',algorithm+'assets=[]; excluded=[]')
    start=s.index("        white=Image.new('RGBA',image.size)")
    end=s.index("    normalized=",start)
    s=s[:start]+"        card_variant(image).save(RES/f'{resource}_card.webp',lossless=True)\n"+s[end:]
    s=s.replace("'asset_revision':2", "'asset_revision':3")
    p.write_text(s)
exec(algorithm)
res=A/'app/src/main/res/drawable-nodpi'
if manifest.get('asset_revision')!=3:
    for issuer in manifest['issuers']:
        image=Image.open(res/(issuer['resource']+'.webp')).convert('RGBA')
        card_variant(image).save(res/(issuer['resource']+'_card.webp'),lossless=True)
    manifest['asset_revision']=3
# Remove only unused resources introduced by the replaced UI implementation.
used={a['resource'] for a in manifest['assets']}
for f in res.glob('wallet_*.webp'):
    if f.stem.removesuffix('_card') not in used: f.unlink()
for f in (A/'branding/catalog_sources').glob('wallet_*.svg'):
    if f.stem not in used: f.unlink()
manifest['resource_bytes']=sum(p.stat().st_size for p in res.glob('wallet_issuer_*.webp'))
(A/'branding/catalog.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(A/'branding/README.md').write_text('''# Android 离线品牌资源

实际机构和别名清单见 COVERAGE.md，机器可读目录和原始图形校验值见 catalog.json。目录包含历史名称，不是全球银行名录，也不承诺任何地区所有在营银行均已覆盖。未知或有歧义的名称使用中性缩写，不冒用品牌。

## 维护

在仓库根目录运行 `python3 apps/android/branding/build_catalog.py`，需要 CairoSVG 2.8.2 和 Pillow 11.3.0。只有显式运行维护脚本才会下载公开素材；正常 Gradle 构建和应用显示 Logo 不访问第三方服务器，不上传卡号或银行名称。上游固定提交及补充来源分别见构建器和 supplemental_assets.json。原始 SVG 位于 catalog_sources，转换后的资源位于 drawable-nodpi。

图形按原始宽高比缩放，去除已知的外层图标底板，不拉伸。简单卡面标识使用透明单色版本以保持对比度；复杂多色图形保留品牌色，避免内部细节变成白色实心块。列表保留品牌色。完整许可证随应用打包在 assets/licenses，商标归各自权利人所有。不同 Logo 形状会有不同占用比例，不强行填满同一个矩形。

名称匹配支持大小写、常见中英文别名、部分繁简体和公司后缀归一化；精确匹配优先、歧义回退，结果使用有界缓存。卡组织识别只根据本地号码前缀提供显示提示，不是完整 BIN 查询或卡片有效性验证。
''')
print('Complex brand marks, visual regression references and unused feature assets reviewed.')
