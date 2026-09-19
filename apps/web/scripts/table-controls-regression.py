"""Production regression for favourites, page sizes and merged-bank hover. Synthetic data only."""
import functools
import http.server
import json
import re
import subprocess
import threading
from datetime import datetime, timezone
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'browser-results'
OUT.mkdir(exist_ok=True)
PASSWORD = 'TableControls!123'
password = subprocess.check_output(['node', '-e', "const c=require('crypto-js');process.stdout.write(JSON.stringify(c.AES.encrypt(c.SHA256(process.argv[1]+'app_salt_2024').toString(),'password_encryption_key').toString()))", PASSWORD], cwd=ROOT, text=True)
cards = [dict(id=f'controls-{i:03}', alias=f'Controls-{i:03}', cardCategory='credit',
              country='中国' if i < 10 else 'US', bank='上海银行' if i < 2 else '建设银行' if i < 10 else 'HSBC',
              cardNumber=f'411100000000{i:04}', type='CNY', limit=100, isSharedLimit=True,
              accountBillDate='20', dueDate='10', annualFee=0, isQualified='3',
              lastModifyTime=1789700000000-i, cardImages=[]) for i in range(115)]
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT / 'dist')))
threading.Thread(target=server.serve_forever, daemon=True).start()
url = f'http://127.0.0.1:{server.server_port}'
results = {}
with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True)
    context = browser.new_context(viewport={'width': 1500, 'height': 950}, color_scheme='light', timezone_id='UTC')
    context.route('**/*', lambda route: route.continue_() if route.request.url.startswith(url + '/') else route.abort())
    page = context.new_page()
    page.clock.set_fixed_time(datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc))
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    seed = json.dumps({'cards': cards, 'password': password})
    page.add_init_script("""(() => {
      if (localStorage.getItem('controls-seeded')) return;
      const data = """ + seed + """;
      localStorage.setItem('cardData', JSON.stringify(data.cards));
      localStorage.setItem('app_security_password', data.password);
      localStorage.setItem('creditCardSortMode', 'modifyTime');
      localStorage.setItem('controls-seeded', 'true');
    })()""")
    def unlock():
        page.get_by_placeholder('请输入密码', exact=True).fill(PASSWORD)
        page.get_by_role('button', name='解锁', exact=True).click()
        expect(page.locator('.wallet-list-controls')).to_be_visible(timeout=30000)
        reminder = page.locator('.annual-fee-dialog')
        expect(reminder).to_be_visible(timeout=30000)
        reminder.get_by_role('button', name='知道了', exact=True).click()
        expect(reminder).not_to_be_visible()
    def choose_size(size):
        page.locator('.wallet-pagination .el-select').click()
        page.get_by_role('option', name=re.compile(r'^' + str(size) + r'\s*条\/页$')).click()
    def row(alias):
        return page.locator('.credit-card-table .el-table__body tr').filter(has=page.get_by_text(alias, exact=True))
    try:
        page.goto(url, wait_until='networkidle')
        unlock()
        rows = page.locator('.credit-card-table .el-table__body tr')
        expect(rows).to_have_count(50)
        for theme in ('light', 'dark'):
            page.emulate_media(color_scheme=theme)
            expect(page.locator('html')).to_have_class('dark' if theme == 'dark' else '')
            for bank, alias in [('上海银行', 'Controls-001'), ('建设银行', 'Controls-004')]:
                row(alias).get_by_text(alias, exact=True).hover()
                overlay = page.locator('.table-row-hover-overlay:not(.table-row-hover-overlay--cell)')
                expect(overlay).to_be_visible()
                bank_cell = page.locator('.wallet-bank-cell').filter(has_text=bank).locator('xpath=ancestor::td')
                # Current UI highlights the hovered row plus shared rowspan cells, not sibling rows.
                # Verify the merged bank block is covered by the union of the disjoint overlays.
                band = overlay.bounding_box(); merged = bank_cell.bounding_box()
                viewport = page.locator('.credit-card-table .el-table__body-wrapper .el-scrollbar__wrap').bounding_box()
                hovered = row(alias).bounding_box()
                assert abs(band['y'] - max(hovered['y'], viewport['y'])) < 2, (band, hovered)
                assert abs(band['y'] + band['height'] - min(hovered['y'] + hovered['height'], viewport['y'] + viewport['height'])) < 2
                center_x = merged['x'] + merged['width'] / 2
                intervals = page.locator('.table-row-hover-overlay').evaluate_all(
                    "els => els.map(el => { const r=el.getBoundingClientRect(); return {left:r.left,right:r.right,top:r.top,bottom:r.bottom}; })")
                covered = max(merged['y'], viewport['y'])
                for part in sorted(intervals, key=lambda item: item['top']):
                    if part['left'] <= center_x <= part['right'] and part['bottom'] >= covered - 2:
                        assert part['top'] <= covered + 2, (bank, part, covered)
                        covered = max(covered, part['bottom'])
                assert covered >= min(merged['y'] + merged['height'], viewport['y'] + viewport['height']) - 2
                results[f'{theme}_{bank}_merged_block'] = True
                if bank == '上海银行':
                    # Full-page capture can resize the viewport and intentionally clear hover.
                    page.screenshot(path=str(OUT / f'table-controls-{theme}.png'))
                    expect(overlay).to_be_visible()
            page.locator('.wallet-list-controls').hover()
            expect(page.locator('.table-row-hover-overlay')).not_to_be_visible()
        choose_size(20); expect(rows).to_have_count(20)
        page.locator('.wallet-pagination .btn-next').click()
        expect(rows.first).to_contain_text('Controls-020')
        expect(page.locator('.wallet-page-range')).to_have_text('第 21–40 条，共 115 条')
        row('Controls-020').get_by_role('button', name='收藏卡片', exact=True).click()
        expect(page.locator('.wallet-favorite-count')).to_have_text('1')
        expect(page.locator('.wallet-page-range')).to_contain_text('第 21–40 条')
        page.locator('.wallet-favorites-filter .el-checkbox').click()
        expect(rows).to_have_count(1)
        expect(page.locator('.wallet-page-range')).to_have_text('第 1–1 条，共 1 条')
        page.locator('.wallet-favorites-filter .el-checkbox').click()
        expect(rows).to_have_count(20)
        choose_size(200); expect(rows).to_have_count(115)
        choose_size(50); expect(rows).to_have_count(50)
        choose_size(100); expect(rows).to_have_count(100)
        choose_size(20); expect(rows).to_have_count(20)
        for _ in range(5): page.locator('.wallet-pagination .btn-next').click()
        expect(rows).to_have_count(15)
        expect(page.locator('.wallet-page-range')).to_have_text('第 101–115 条，共 115 条')
        page.locator('.omni-search-input input').fill('Controls-114')
        expect(rows).to_have_count(1)
        expect(page.locator('.wallet-page-range')).to_have_text('第 1–1 条，共 1 条')
        page.locator('.omni-search-input input').fill(''); expect(rows).to_have_count(20)
        page.reload(wait_until='networkidle'); unlock(); expect(rows).to_have_count(20)
        results['page_sizes_filtering_favourites_and_reload'] = True
        page.set_viewport_size({'width': 390, 'height': 844})
        assert page.locator('.wallet-pagination').evaluate('el => [...el.children].every(child => { const r=child.getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth; })')
        controls = page.locator('.wallet-list-controls').bounding_box()
        assert controls['x'] >= 0 and controls['x'] + controls['width'] <= 390
        page.screenshot(path=str(OUT / 'table-controls-mobile.png'), full_page=True)
        results['mobile_controls_in_viewport'] = True
        page.locator('.el-radio-button').filter(has=page.get_by_role('radio', name='卡片', exact=True)).click()
        expect(page.locator('.physics-card-wrapper')).to_have_count(24)
        choose_size(50); expect(page.locator('.physics-card-wrapper')).to_have_count(50)
        results['card_view_page_size'] = True
        assert not errors, errors
        results['page_errors'] = errors
    except Exception:
        page.screenshot(path=str(OUT / 'table-controls-failure.png'), full_page=True)
        raise
    finally:
        (OUT / 'table-controls-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
        print(json.dumps(results, ensure_ascii=False))
        browser.close(); server.shutdown()
