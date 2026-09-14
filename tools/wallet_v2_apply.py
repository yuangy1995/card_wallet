#!/usr/bin/env python3
"""Finish reviewed Android UI and branding assets on the isolated feature branch."""
from pathlib import Path
import subprocess, sys, json
ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'apps/android'; J=A/'app/src/main/java/com/example/creditcard'
branch=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()
if branch!='feat/android-wallet-redesign-v2': raise RuntimeError('Feature branch required')
if 'WalletHomeHeader(' not in (J/'ui/main/MainScreen.kt').read_text(): raise RuntimeError('Initial integration missing')
p=J/'ui/wallet/WalletCardNumber.kt';s=p.read_text().replace('minFontSize = 12.sp','minFontSize = 10.sp');p.write_text(s)
p=J/'ui/main/MainScreen.kt';s=p.read_text().replace('.padding(innerPadding),\n            contentAlignment = Alignment.TopCenter', '.padding(innerPadding).consumeWindowInsets(innerPadding),\n            contentAlignment = Alignment.TopCenter');p.write_text(s)
p=A/'branding/build_catalog.py';s=p.read_text()
if "archives['supplement']" not in s:
    s=s.replace("d.startswith('m0 0m224')", "d.startswith(('m0 0m224', 'm224 0h576'))")
    s=s.replace("if not name or key in {'pbc','csrc','china-cba','norincogroup'}: return", "if not name or '银行业监督' in name or key in {'pbc','csrc','china-cba','norincogroup'}: return")
    s=s.replace('assets=[]; excluded=[]', '''# Supplemental assets are explicitly reviewed public logos, not runtime downloads.
manual=json.loads((BRAND/'supplemental_assets.json').read_text())
archives['supplement']={}
for key,item in manual.items():
    request=urllib.request.Request(item['url'], headers={'User-Agent':'CardWallet-logo-maintenance/1.0 (offline assets)'})
    with urllib.request.urlopen(request, timeout=40) as response: data=response.read(200001)
    if len(data)>200000: raise ValueError('Supplemental SVG too large')
    if item.get('sha1') and hashlib.sha1(data).hexdigest()!=item['sha1']: raise ValueError('Upstream artwork changed: '+key)
    archives['supplement'][key+'.svg']=data
    add(key,item['name'],'supplement',key+'.svg')
    colors[key]=item['accent']
(LICENSES/'wallet-catalog-supplement.txt').write_text(json.dumps(manual,ensure_ascii=False,indent=2)+'\\n')
# Use the transparent wordmark instead of turning a blue Amex tile into a white tile.
records['amex']['origin']='networks'
records['amex']['path']='logo/amex.svg'
assets=[]; excluded=[]''')
    s=s.replace("    for child in root.iter():\n", '''    # A requested transparent variant of the Schwab wordmark; preserve the letter paths.
    if origin == 'supplement' and path == 'charlesschwab.svg':
        for parent in root.iter():
            for child in list(parent):
                if child.tag.split('}')[-1] == 'rect': parent.remove(child)
    for child in root.iter():
''')
    s=s.replace("    image=image.crop(box);image.thumbnail", '''    image=image.crop(box)
    if origin == 'supplement' and path == 'charlesschwab.svg':
        alpha=image.getchannel('A'); image=Image.new('RGBA',image.size,(0,105,157,0)); image.putalpha(alpha)
    image.thumbnail''')
    s=s.replace("    repo,rev=UPSTREAMS[origin]\n    assets.append({'resource':resource,'url':f'https://github.com/{repo}/blob/{rev}/{path}',", '''    source_url=manual[Path(path).stem]['url'] if origin=='supplement' else 'https://github.com/{}/blob/{}/{}'.format(*UPSTREAMS[origin],path)
    assets.append({'resource':resource,'url':source_url,''')
    s=s.replace("manifest={'upstreams':UPSTREAMS", "manifest={'asset_revision':2,'upstreams':UPSTREAMS")
    p.write_text(s)
manifest=A/'branding/catalog.json'
if not manifest.exists() or json.loads(manifest.read_text()).get('asset_revision')!=2:
    subprocess.run([sys.executable,str(p)],cwd=ROOT,check=True)
print('Reviewed transparency, proportional logos, coverage and narrow layouts applied.')
