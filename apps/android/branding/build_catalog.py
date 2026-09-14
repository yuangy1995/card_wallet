#!/usr/bin/env python3
"""Explicit asset maintenance, not a Gradle/runtime download. Public SVGs are data only.
Requires CairoSVG 2.8.2 and Pillow 11.3.0. Writes only Android branding and logo resources.
"""
from pathlib import Path
from html.parser import HTMLParser
import hashlib, io, json, re, urllib.request, zipfile
import xml.etree.ElementTree as ET
import cairosvg
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / 'branding'
RES = ROOT / 'app/src/main/res/drawable-nodpi'
JAVA = ROOT / 'app/src/main/java/com/example/creditcard/ui/wallet'
SOURCES = BRAND / 'catalog_sources'
LICENSES = ROOT / 'app/src/main/assets/licenses'
UPSTREAMS = {
 'banks': ('icongo/bank-logos', 'ffca539a043900fbf2a4fd6a5d32f1706ae5dfd1'),
 'global': ('auraveni/global-bank-logos', 'ad33060ca976397a9fcb46dd40c2d77bce5ce7e1'),
 'simple': ('simple-icons/simple-icons', '0af835e2949a9222965522780e5e0810d3c53382'),
 'networks': ('aaronfagan/svg-credit-card-payment-icons', '6dd023ae32415ed7b01bf809f15a25613a52098c')
}
for folder in [RES,JAVA,SOURCES,LICENSES]: folder.mkdir(parents=True,exist_ok=True)

def archive(repo, rev):
    url=f'https://codeload.github.com/{repo}/zip/{rev}'
    with urllib.request.urlopen(url,timeout=90) as response: data=response.read(40_000_001)
    if len(data)>40_000_000: raise ValueError('Upstream archive too large')
    z=zipfile.ZipFile(io.BytesIO(data)); prefix=z.namelist()[0].split('/')[0]+'/'
    return {n[len(prefix):]:z.read(n) for n in z.namelist() if not n.endswith('/') and n.endswith(('.svg','.html','.md','.json','LICENSE','.txt'))}

archives={key:archive(*source) for key,source in UPSTREAMS.items()}
for key,a in archives.items():
    license_path=next((p for p in ['LICENSE','LICENSE.md','LICENSE.txt'] if p in a),None)
    if license_path is None: raise ValueError('Missing upstream license: '+key)
    (LICENSES/f'wallet-catalog-{key}.txt').write_bytes(a[license_path])

class Images(HTMLParser):
    def __init__(self): super().__init__(); self.items=[]
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag=='img': self.items.append((a.get('src','').removeprefix('./'),a.get('alt','')))

def norm(s): return re.sub(r'[^a-z0-9\u4e00-\u9fff]','',s.lower())
def safe_id(s): return re.sub('[^a-z0-9_]','_',s.lower())
def quote(s): return json.dumps(s,ensure_ascii=False).replace('$','\\$')

# Reuse the reviewed issuer aliases and accents already in the application.
old=(JAVA/'WalletBrand.kt').read_text()
aliases={}; colors={}
code_to_slug={'cmb':'cmbchina','abc':'abchina','bocom':'bankcomm','citic':'citicbank','cgb':'cgbchina','ceb':'cebbank','citi':'citibank','boa':'bankofamerica'}
for m in re.finditer(r'^\s+[A-Z]+\("([^"]+)", 0xFF([A-Fa-f0-9]+), (.+)\),?$',old,re.M):
    key=code_to_slug.get(m[1],m[1]); aliases[key]=re.findall(r'"([^"]+)"',m[3]); colors[key]=m[2]
extra=json.loads((BRAND/'issuer_aliases.json').read_text())
for key,names in extra.items(): aliases.setdefault({"americanexpress":"amex", "deutschebank":"deutsche"}.get(key,key),[]).extend(names)
redirect={norm(name):key for key,names in aliases.items() for name in names}
records={}

def add(key,name,origin,path):
    if not name or '银行业监督' in name or key in {'pbc','csrc','china-cba','norincogroup'}: return
    key=redirect.get(norm(name),key)
    names=set(aliases.get(key,[])+[name])
    for n in list(names):
        if '农村商业银行' in n: names.update([n.replace('农村商业银行','农商银行'),n.replace('农村商业银行','农商')])
        elif n.endswith('农商'): names.update([n+'银行',n[:-2]+'农村商业银行'])
    if key in records: records[key]['aliases'].update(names); return
    previous=next((r for r in records.values() if norm(name)==norm(r['name'])),None)
    if previous: previous['aliases'].update(names); return
    records[key]={'id':key,'name':name,'origin':origin,'path':path,'aliases':names}

p=Images();p.feed(archives['banks']['README.md'].decode())
labels={path:name for path,name in p.items}
corrections={'sc':'渣打银行','xmbankonline':'厦门银行','bankoftianjin':'天津银行','ccabchina':'长安银行'}
for path in sorted(archives['banks']):
    if path.startswith('logos/') and path.endswith('-rect.svg'):
        key=Path(path).stem.removesuffix('-rect');name=corrections.get(key,labels.get(path,''))
        add(key,name,'banks',path)
    elif path.startswith('other/') and re.search(r'logo\.svg$',path,re.I):
        name=re.sub('logo$','',Path(path).stem,flags=re.I).lstrip('!').strip()
        if re.search('银行|銀行|农商|农信|信用',name): add('cn_'+hashlib.sha256(name.encode()).hexdigest()[:12],name,'banks',path)
for path,data in archives['global'].items():
    if path.endswith('.html'):
        p=Images();p.feed(data.decode())
        for source,label in p.items:
            if source.startswith('assets/bank/') and source in archives['global']:
                add('global_'+Path(source).stem,re.sub(r'\s+Logo$','',label,flags=re.I),'global',source)
for key in extra:
    path=f'icons/{key}.svg'
    if path in archives['simple']: add(key,extra[key][0],'simple',path)
if 'amex' not in records: add('amex','美国运通','networks','logo/amex.svg')

# Supplemental assets are explicitly reviewed public logos, not runtime downloads.
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
(LICENSES/'wallet-catalog-supplement.txt').write_text(json.dumps(manual,ensure_ascii=False,indent=2)+'\n')
# Use the transparent wordmark instead of turning a blue Amex tile into a white tile.
records['amex']['origin']='networks'
records['amex']['path']='logo/amex.svg'
assets=[]; excluded=[]
def export(resource,origin,path,mono=False):
    raw=archives[origin][path];root=ET.fromstring(raw)
    # Known icon-library tile geometry, not a color-key removal of genuine white logo details.
    for child in list(root):
        fill=child.get('fill','').lower();d=re.sub(r'\s+',' ',child.get('d','')).strip().lower()
        if root.get('viewBox')=='0 0 1024 1024' and d.startswith(('m0 0m224', 'm224 0h576')) and fill in ['#fff','#ffffff','white']: root.remove(child)
    # A requested transparent variant of the Schwab wordmark; preserve the letter paths.
    if origin == 'supplement' and path == 'charlesschwab.svg':
        for parent in root.iter():
            for child in list(parent):
                if child.tag.split('}')[-1] == 'rect': parent.remove(child)
    for child in root.iter():
        if any('http' in v and k.split('}')[-1]=='href' for k,v in child.attrib.items()): raise ValueError('External SVG reference')
    png=cairosvg.svg2png(bytestring=ET.tostring(root),output_width=512)
    image=Image.open(io.BytesIO(png)).convert('RGBA');box=image.getchannel('A').getbbox()
    if box is None: raise ValueError('Empty artwork')
    image=image.crop(box)
    if origin == 'supplement' and path == 'charlesschwab.svg':
        alpha=image.getchannel('A'); image=Image.new('RGBA',image.size,(0,105,157,0)); image.putalpha(alpha)
    image.thumbnail((192,192),Image.Resampling.LANCZOS)
    pad=Image.new('RGBA',(image.width+4,image.height+4));pad.alpha_composite(image,(2,2));image=pad
    image.save(RES/f'{resource}.webp',lossless=True)
    if mono:
        white=Image.new('RGBA',image.size)
        white.putdata([(255,255,255,0 if min(r,g,b)>245 else a) for r,g,b,a in image.getdata()])
        if white.getchannel('A').getbbox() is None: white.putalpha(image.getchannel('A'))
        white.save(RES/f'{resource}_card.webp',lossless=True)
    normalized='\n'.join(s.rstrip() for s in raw.decode().splitlines())+'\n'
    (SOURCES/f'{resource}.svg').write_text(normalized)
    source_url=manual[Path(path).stem]['url'] if origin=='supplement' else 'https://github.com/{}/blob/{}/{}'.format(*UPSTREAMS[origin],path)
    assets.append({'resource':resource,'url':source_url,
        'source_sha256':hashlib.sha256(raw).hexdigest(),'stored_sha256':hashlib.sha256(normalized.encode()).hexdigest(),
        'width':image.width,'height':image.height})

palette=['244B6B','315D52','6F3859','79412E','394B80','246977']
for key in list(records):
    r=records[key];r['resource']='wallet_issuer_'+safe_id(key)
    try: export(r['resource'],r['origin'],r['path'],True)
    except Exception as e: excluded.append({'id':key,'reason':str(e)});del records[key];continue
    r['accent']=colors.get(key,palette[int(hashlib.sha256(key.encode()).hexdigest()[:4],16)%len(palette)])
networks=['visa','mastercard','amex','unionpay','jcb','discover','diners']
for n in networks: export('wallet_network_'+n,'networks',f'logo/{n}.svg')
code='package com.example.creditcard.ui.wallet\n\nimport com.example.creditcard.R\n\ninternal object WalletBrandAssets {\n    fun network(network: WalletNetwork): Int? = when (network) {\n'
for n in networks: code+=f'        WalletNetwork.{n.upper()} -> R.drawable.wallet_network_{n}\n'
(JAVA/'WalletBrandAssets.kt').write_text(code+'        else -> null\n    }\n}\n')
rows=sorted(records.values(),key=lambda r:r['id']);chunks=[rows[i:i+60] for i in range(0,len(rows),60)]
code='package com.example.creditcard.ui.wallet\n\nimport com.example.creditcard.R\n\ninternal object WalletLogoCatalogData {\n    val entries by lazy { buildList {\n'
for i in range(len(chunks)): code+=f'        addAll(part{i}())\n'
code+='    } }\n'
for i,chunk in enumerate(chunks):
    code+=f'    private fun part{i}() = listOf(\n'
    for r in chunk:
        code+=f'        WalletIssuerLogo({quote(r["id"])}, {quote(r["name"])}, R.drawable.{r["resource"]}, R.drawable.{r["resource"]}_card, 0xFF{r["accent"]}, listOf('+', '.join(quote(a) for a in sorted(r['aliases']))+')),\n'
    code+='    )\n'
(JAVA/'WalletLogoCatalogData.kt').write_text(code+'}\n')
manifest={'asset_revision':2,'upstreams':UPSTREAMS,'issuers':[dict(r,aliases=sorted(r['aliases'])) for r in rows],'assets':assets,'excluded':excluded,
 'issuer_count':len(rows),'network_count':7,'resource_bytes':sum(p.stat().st_size for p in RES.glob('wallet_issuer_*.webp'))}
(BRAND/'catalog.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(BRAND/'COVERAGE.md').write_text('# 实际离线标识覆盖\n\n'+str(len(rows))+' 个去重机构条目、7 类卡组织。包含历史名称，不代表所有地区全部在营银行。未覆盖或匹配有歧义时显示中性缩写。\n\n| 机构 | 别名 | 来源 |\n|---|---|---|\n'+''.join('| '+r['name']+' | '+' / '.join(sorted(r['aliases']))+' | '+r['origin']+' |\n' for r in rows))
print(json.dumps({k:manifest[k] for k in ['issuer_count','network_count','resource_bytes','excluded']},ensure_ascii=False))
