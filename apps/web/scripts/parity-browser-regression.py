"""Production-page parity checks. Synthetic records only; external requests are blocked."""
import functools
import http.server
import json
from datetime import datetime, timezone
import traceback
from pathlib import Path
import subprocess
import threading
from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'browser-results'
OUT.mkdir(exist_ok=True)
PASSWORD = 'ParityBrowser!123'
legacy_hash = subprocess.check_output(['node', '-e', "const c=require('crypto-js');process.stdout.write(JSON.stringify(c.AES.encrypt(c.SHA256(process.argv[1]+'app_salt_2024').toString(),'password_encryption_key').toString()))", PASSWORD], cwd=ROOT, text=True)
cards = [dict(id=f'parity-{i:03}', cardCategory='credit', country='US', bank='HSBC', alias=f'Parity-{i:03}',
              cardNumber=f'411100000000{i:04}', type='USD', limit=100+i, isSharedLimit=False,
              accountBillDate='20', dueDate='10', billingDaySpendingToNextBill=True,
              annualFee=0, isQualified='3', lastModifyTime=1789700000000+i, cardImages=[], equity='airport lounge', remark='sample-only') for i in range(60)]
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT / 'dist')))
threading.Thread(target=server.serve_forever, daemon=True).start()
url = f'http://127.0.0.1:{server.server_port}'
results = {}
with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True)
    context = browser.new_context(viewport={'width': 1280, 'height': 1000}, color_scheme='light', timezone_id='UTC')
    context.route('**/*', lambda route: route.continue_() if route.request.url.startswith(url + '/') else route.abort())
    page = context.new_page()
    # A fixed civil date keeps the real automatic reminder deterministic, without
    # pausing timers or skipping the reminder flow that runs after wallet loading.
    page.clock.set_fixed_time(datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc))
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    seed = json.dumps({'cards': cards, 'password': legacy_hash})
    page.add_init_script("""(() => {
      if (localStorage.getItem('parity-seeded')) return;
      const data = """ + seed + """;
      localStorage.setItem('cardData', JSON.stringify(data.cards));
      localStorage.setItem('app_security_password', data.password);
      localStorage.setItem('parity-seeded', 'true');
    })()""")
    def unlock():
        page.get_by_placeholder('请输入密码', exact=True).fill(PASSWORD)
        page.get_by_role('button', name='解锁', exact=True).click()
        expect(page.locator('.wallet-favorites-filter')).to_be_visible(timeout=30000)
        reminder = page.locator('.annual-fee-dialog')
        expect(reminder).to_be_visible(timeout=30000)
        expect(reminder).to_contain_text('账单日提醒')
        reminder.get_by_role('button', name='知道了', exact=True).click()
        expect(reminder).not_to_be_visible()
        results['initial_reminder_dismissals'] = results.get('initial_reminder_dismissals', 0) + 1
    try:
        page.goto(url, wait_until='networkidle')
        unlock()
        expect(page.locator('.credit-card-table .el-table__body tr')).to_have_count(50)
        favorite = page.get_by_role('button', name='收藏卡片', exact=True).first
        favorite.click()
        expect(page.get_by_role('button', name='取消收藏', exact=True)).to_have_count(1)
        checkbox = page.get_by_role('checkbox', name='只看收藏', exact=True)
        expect(checkbox).not_to_be_checked()
        # Element Plus intentionally hides the native input; click its visible label.
        page.locator('.wallet-favorites-filter .el-checkbox').click()
        expect(checkbox).to_be_checked()
        expect(page.locator('.credit-card-table .el-table__body tr')).to_have_count(1)
        row_text = page.locator('.credit-card-table .el-table__body tr').inner_text()
        page.reload(wait_until='networkidle')
        unlock()
        expect(page.get_by_role('checkbox', name='只看收藏', exact=True)).to_be_checked()
        expect(page.locator('.credit-card-table .el-table__body tr')).to_have_count(1)
        expect(page.get_by_role('button', name='取消收藏', exact=True)).to_have_count(1)
        assert row_text == page.locator('.credit-card-table .el-table__body tr').inner_text()
        results['favorite_survives_reload_and_unlock'] = True
        page.get_by_role('button', name='取消收藏', exact=True).click()
        expect(page.locator('.credit-card-table .el-table__body tr')).to_have_count(0)
        page.locator('.wallet-favorites-filter .el-checkbox').click()
        expect(checkbox).not_to_be_checked()
        expect(page.locator('.credit-card-table .el-table__body tr')).to_have_count(50)
        results['removing_favorite_updates_filtered_results'] = True
        page.locator('.el-radio-button').filter(has=page.get_by_role('radio', name='卡片', exact=True)).click()
        expect(page.locator('.physics-card-wrapper')).to_have_count(24)
        bank = page.locator('[data-resource="wallet_issuer_hsbc_card"] img').first
        network = page.locator('[data-resource="wallet_network_visa"] img').first
        expect(bank).to_be_visible()
        expect(network).to_be_visible()
        page.wait_for_function("() => { const images = [...document.querySelectorAll('.physics-card-wrapper:first-child .wallet-brand-mark img')]; return images.length >= 2 && images.every(img => img.complete && img.naturalWidth > 0); }")
        assert bank.evaluate("image => new URL(image.src).origin === location.origin")
        results['same_origin_bank_and_network_artwork_loaded'] = True
        for theme in ['light', 'dark']:
            page.emulate_media(color_scheme=theme)
            expect(page.locator('html')).to_have_class('dark' if theme == 'dark' else '')
            for width in [1280, 390]:
                page.set_viewport_size({'width': width, 'height': 1000})
                page.screenshot(path=str(OUT / f'parity-branding-{theme}-{width}.png'), full_page=True)
        # A broken asset is not replaced with guessed letters or another issuer.
        bank.dispatch_event('error')
        expect(page.locator('[data-resource="wallet_issuer_hsbc_card"]').first.locator('svg')).to_be_visible()
        results['broken_artwork_uses_generic_card'] = True
        assert not errors, errors
        results['page_errors'] = errors
    except Exception:
        (OUT / 'parity-failure.txt').write_text(traceback.format_exc() + '\n\n' + page.locator('body').inner_text() + '\n\n' + repr(errors), encoding='utf-8')
        page.screenshot(path=str(OUT / 'parity-failure.png'), full_page=True)
        raise
    finally:
        (OUT / 'parity-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
        print(json.dumps(results, ensure_ascii=False))
        browser.close()
        server.shutdown()
