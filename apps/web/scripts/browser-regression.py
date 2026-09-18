"""Production-browser regression with synthetic fixtures only; no real WebDAV account.
Run from apps/web after pnpm build: python scripts/browser-regression.py
Requires playwright==1.57.0 and its Chromium browser (CI installs both).
"""
import functools
import http.server
import json
import traceback
from pathlib import Path
import subprocess
import threading
import time
from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'browser-results'
OUT.mkdir(exist_ok=True)
PASSWORD = 'BrowserRegression!123'
# This is generated test data, never a user credential.
legacy_hash = subprocess.check_output(['node', '-e', "const c=require('crypto-js');process.stdout.write(JSON.stringify(c.AES.encrypt(c.SHA256(process.argv[1]+'app_salt_2024').toString(),'password_encryption_key').toString()))", PASSWORD], cwd=ROOT, text=True)
cards = [dict(id=f'fixture-{i:04d}', cardCategory='credit', country='US', bank='Regression Bank',
              alias=f'Card-{i:04d}', cardNumber=f'411100000000{i:04d}', type='USD' if i % 2 == 0 else 'HKD',
              limit=100 + i, isSharedLimit=True, billingDaySpendingToNextBill=True, accountBillDate='', dueDate='',
              cvv='123', valid='2035-12', annualFee=0, isQualified='3', nextAnnualFeeCollectionTime=None,
              lastModifyTime=int(time.time() * 1000), cardImages=[], equity='', remark='') for i in range(2000)]
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT / 'dist'))
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
url = f'http://127.0.0.1:{server.server_port}'
results = {}
errors = []
with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True)
    context = browser.new_context(viewport={'width': 1440, 'height': 1100})
    # Explicitly isolate the test from external accounts/services.
    context.route('**/*', lambda route: route.continue_() if route.request.url.startswith(url + '/') else route.abort())
    page = context.new_page()
    page.on('pageerror', lambda error: errors.append(str(error)))
    loaded = []
    page.on('request', lambda request: loaded.append(request.url))
    seed = {'cards': cards, 'password': legacy_hash}
    page.add_init_script('''(() => {
      if (localStorage.getItem('regression-seeded')) return;
      const data = ''' + json.dumps(seed, ensure_ascii=False) + ''';
      localStorage.setItem('cardData', JSON.stringify(data.cards));
      localStorage.setItem('app_security_password', data.password);
      localStorage.setItem('regression-seeded', 'true');
    })()''')
    try:
        page.goto(url, wait_until='networkidle')
        expect(page.get_by_text('应用已锁定', exact=True)).to_be_visible()
        assert 'Regression Bank' not in page.locator('body').inner_text()
        assert not any('echarts-' in resource or '/App-' in resource for resource in loaded)
        results['locked_entry_no_wallet_or_charts'] = True
        page.get_by_placeholder('请输入密码', exact=True).fill('wrong-password')
        page.get_by_role('button', name='解锁', exact=True).click()
        expect(page.get_by_text('密码错误 1 次', exact=True)).to_be_visible()
        page.get_by_placeholder('请输入密码', exact=True).fill(PASSWORD)
        start = time.perf_counter()
        page.get_by_role('button', name='解锁', exact=True).click()
        expect(page.locator('.credit-card-table .el-table__body tr')).to_have_count(50, timeout=30000)
        results['unlock_and_render_2000_ms'] = round((time.perf_counter() - start) * 1000)
        # Close migration/informational dialogs, if any, without affecting wallet data.
        if page.locator('.el-message-box').is_visible():
            page.locator('.el-message-box button').last.click()
        assert not any('echarts-' in resource for resource in loaded)
        persisted = page.evaluate('''async () => {
          const db = await new Promise((resolve,reject) => { const r=indexedDB.open('card-wallet-web-local-db',2);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error); });
          const rows = await new Promise((resolve,reject) => { const r=db.transaction('kv').objectStore('kv').getAll();r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error); });
          db.close(); return {rows, local: {...localStorage}};
        }''')
        assert any(row['key'] == 'walletLocalVaultV1' for row in persisted['rows'])
        assert 'Regression Bank' not in json.dumps(persisted, ensure_ascii=False)
        assert 'app_security_password' not in persisted['local']
        results['legacy_migration_is_encrypted'] = True
        # Batch checkboxes keep a selection from a different page.
        page.locator('.credit-card-table .el-table__body tr .el-checkbox').first.click()
        page.locator('.credit-card-table .el-pagination .btn-next').click()
        expect(page.locator('.credit-card-table .el-table__body tr')).to_have_count(50)
        page.locator('.credit-card-table .el-table__body tr .el-checkbox').first.click()
        expect(page.locator('.batch-operation-toolbar')).to_contain_text('已选择 2 项')
        results['cross_page_selection'] = True
        # Search is over the full data set, not just the current page.
        page.locator('.omni-search-input input').fill('Card-1999')
        expect(page.locator('.credit-card-table .el-table__body tr')).to_have_count(1, timeout=10000)
        expect(page.locator('.credit-card-table')).to_contain_text('Card-1999')
        page.locator('.omni-search-input input').fill('')
        expect(page.locator('.credit-card-table .el-table__body tr')).to_have_count(50)
        results['full_dataset_search'] = True
        page.locator('.el-radio-button').filter(has=page.get_by_role('radio', name='卡片', exact=True)).click()
        expect(page.get_by_role('radio', name='卡片', exact=True)).to_be_checked()
        expect(page.locator('.physics-card-wrapper')).to_have_count(24, timeout=15000)
        page.screenshot(path=str(OUT / 'cards-light.png'), full_page=True)
        page.emulate_media(color_scheme='dark')
        expect(page.locator('html')).to_have_class('dark')
        page.screenshot(path=str(OUT / 'cards-dark.png'), full_page=True)
        results['card_view_2000_rendered_count'] = page.locator('.physics-card-wrapper').count()
        expect(page.locator('.group-limit-pill').first).to_contain_text('USD')
        expect(page.locator('.group-limit-pill').first).to_contain_text('HKD')
        assert '¥' not in page.locator('.group-limit-pill').first.inner_text()
        page.get_by_role('button', name='统计分析', exact=True).click()
        expect(page.locator('.statistics-container')).to_be_visible(timeout=15000)
        assert any('echarts-' in resource for resource in loaded)
        results['charts_loaded_only_when_opened'] = True
        # Cross-tab locking must destroy chart/dialog DOM and all wallet content.
        page.evaluate("localStorage.setItem('app_lock_state', JSON.stringify({isLocked:true})); window.dispatchEvent(new StorageEvent('storage',{key:'app_lock_state'}))")
        expect(page.get_by_text('应用已锁定', exact=True)).to_be_visible()
        expect(page.locator('.statistics-container')).to_have_count(0)
        assert 'Regression Bank' not in page.locator('body').inner_text()
        results['lock_destroys_wallet_and_dialogs'] = True
        page.get_by_placeholder('请输入密码', exact=True).fill(PASSWORD)
        page.get_by_role('button', name='解锁', exact=True).click()
        expect(page.locator('.physics-card-wrapper')).to_have_count(24, timeout=15000)
        # A second tab needs its own key even if localStorage says unlocked.
        other = context.new_page(); other.goto(url, wait_until='networkidle')
        expect(other.get_by_text('应用已锁定', exact=True)).to_be_visible()
        results['new_tab_requires_password'] = True
        other.close()
        page.set_viewport_size({'width': 390, 'height': 844})
        expect(page.locator('.el-message')).to_have_count(0, timeout=10000)
        assert page.locator('.wallet-pagination').evaluate('el => [...el.children].every(child => {const r=child.getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth})')
        results['mobile_pagination_in_viewport'] = True
        page.screenshot(path=str(OUT / 'cards-mobile.png'), full_page=True)
        page.reload(wait_until='networkidle')
        expect(page.get_by_text('应用已锁定', exact=True)).to_be_visible()
        assert not errors, errors
        results['page_errors'] = errors
    except Exception:
        page.screenshot(path=str(OUT / 'failure.png'), full_page=True)
        (OUT / 'failure.txt').write_text(traceback.format_exc() + '\n\n' + page.locator('body').inner_text() + '\n\n' + repr(errors), encoding='utf-8')
        raise
    finally:
        (OUT / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps(results, ensure_ascii=False))
        browser.close(); server.shutdown()
