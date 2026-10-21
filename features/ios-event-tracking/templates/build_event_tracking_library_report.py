"""Dựng report HTML event tracking Library 2.9.0 từ report-summary.json + ảnh trong evidence/.

    python3 build_event_tracking_library_report.py report-summary.json evidence out.html
"""
import base64, html, json, os, sys

SUMMARY, EVID, OUT = sys.argv[1:4]
data = json.load(open(SUMMARY))
rows = data["rows"]
cnt = {k: sum(1 for r in rows if r["status"] == k) for k in ("PASS", "FAIL", "CHECK", "NA")}
done = cnt["PASS"] + cnt["FAIL"] + cnt["CHECK"]
LABEL = {"PASS": "Pass", "FAIL": "Fail", "CHECK": "Cần xác nhận", "NA": "Chưa test"}
e = html.escape

# Kết luận cho dev / PO — viết tay từ số đo, mỗi dòng dẫn chứng code.
FINDINGS = [
    ("FAIL", "gen_tray_view · gen_tray_retry_click — feature_name", "Luồng video gửi <code>i2v</code> (chữ thường); spec liệt kê <code>I2V</code>. Luồng ảnh gửi đúng <code>I2I</code>.",
     "<code>EventValue.swift:24</code> <code>EVENT_VALUE_FEATURE_NAME_I2V = \"i2v\"</code>, dùng chung cho mọi event của luồng video."),
    ("FAIL", "gen_tray_click — destination", "Chạm khay lúc đang tạo: app gửi <code>destination=library</code> và mở Library. Spec: running → mở lại màn Generating.",
     "<code>GenerationStatusView.swift:349-354</code> chỉ lượt Chat mới trả <code>generating</code>; mọi luồng khác luôn <code>library</code> (comment code ghi là cố ý, cùng luật với <code>HomeTabView.openBackgroundJob</code>). Cần PO chốt: sửa app hay sửa spec."),
    ("FAIL", "gen_tray_retry_click — error_code", "Bấm Retry trên khay lỗi (2 lần, lúc mất mạng và lúc có mạng): <code>error_code</code> luôn rỗng.",
     "<code>TrackGenTray.swift</code>: “hiện Job chưa giữ mã lỗi nên luôn \"\"”; lượt hỏng do mất mạng không ghi mã lỗi vào <code>job.errorCode</code>."),
    ("CHECK", "library_load_success — item_count", "Luôn ra 18–20 dù Library có nhiều hơn 20 kết quả (lưới cuộn tiếp).",
     "<code>CreationLibrary.swift:96/189</code>: <code>items.count</code> của trang đầu (<code>listJobs limit 20</code>). Spec ghi “Số kết quả đã tạo”: cần PO chốt là tổng hay số ô trang đầu."),
    ("NA", "library_start_creating_click", "Chỉ hiện ở trạng thái trống “Nothing here yet.” — tài khoản test đang có lịch sử.",
     "Muốn chạy phải xoá toàn bộ kết quả của tài khoản Sandbox, hoặc dùng một Apple ID Sandbox mới chưa tạo gì."),
]

def img(name):
    p = os.path.join(EVID, name + ".jpg")
    return "data:image/jpeg;base64," + base64.b64encode(open(p, "rb").read()).decode() if os.path.exists(p) else ""

SHOTS = [("chon", "Chế độ chọn — library_select_click"), ("xoa2", "Xoá 2 ô → Cancel — multi_select, cancel 2/0"),
         ("menu-xoa", "Menu ··· → Delete — item_menu, delete 1/1"), ("khay-roi-gen", "Rời Generating video — gen_tray_view i2v, 1"),
         ("khay-dang-tao", "Chạm khay đang tạo → mở Library (spec: Generating)"), ("khay-loi", "Mất mạng: Library lỗi + khay lỗi → Retry")]

def table_rows():
    out, last = [], None
    for r in rows:
        ev = r["event"] if r["event"] != last else ""
        last = r["event"]
        out.append(f"<tr class='{'first' if ev else ''}'><td class='ev'>{e(ev)}</td><td><code>{e(str(r['param']))}</code></td>"
                   f"<td class='al'>{e(str(r['allowed'] or ''))}</td><td><span class='pill {r['status'].lower()}'>{LABEL[r['status']]}</span></td>"
                   f"<td class='act'>{e(r['actual'])}</td><td class='bs'>{e(r['basis'])}</td></tr>")
    return "\n".join(out)

page = f"""<title>Genius 2.9.0 Library Events</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
/* Layout: one reading column; summary → findings → full spec table → evidence strip */
:root{{--bg:#F5F6F8;--surface:#FFFFFF;--ink:#1B1F2A;--muted:#5D6473;--line:#DEE1E8;--accent:#5B3FD1;
--pass:#1F7A4D;--pass-bg:#E3F3EA;--fail:#B4232C;--fail-bg:#FBE6E7;--check:#8A5A00;--check-bg:#FBF0D9;--na:#5D6473;--na-bg:#ECEEF2;
--sans:"Be Vietnam Pro",system-ui,-apple-system,sans-serif;--mono:"JetBrains Mono",ui-monospace,Menlo,monospace}}
@media (prefers-color-scheme:dark){{:root:not([data-theme="light"]){{--bg:#12141A;--surface:#1B1E27;--ink:#E7E9EF;--muted:#9AA1B0;--line:#2C303C;--accent:#A895FF;
--pass:#5FD39A;--pass-bg:#173326;--fail:#FF8A8F;--fail-bg:#3A1C1F;--check:#F1C26B;--check-bg:#352A14;--na:#9AA1B0;--na-bg:#252935;color-scheme:dark}}}}
:root[data-theme="dark"]{{--bg:#12141A;--surface:#1B1E27;--ink:#E7E9EF;--muted:#9AA1B0;--line:#2C303C;--accent:#A895FF;
--pass:#5FD39A;--pass-bg:#173326;--fail:#FF8A8F;--fail-bg:#3A1C1F;--check:#F1C26B;--check-bg:#352A14;--na:#9AA1B0;--na-bg:#252935;color-scheme:dark}}
*{{box-sizing:border-box}}
body{{background:var(--bg);color:var(--ink);font:15px/1.6 var(--sans);padding-block:32px 64px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}}
.wrap{{max-width:1120px;margin:0 auto;display:flex;flex-direction:column;gap:28px}}
h1{{font-size:clamp(24px,4vw,32px);line-height:1.15;margin:0;text-wrap:balance}}
h2{{font-size:19px;margin:0 0 12px;text-wrap:balance}}
.lede{{color:var(--muted);margin:8px 0 0;max-width:70ch}}
.meta{{display:flex;flex-wrap:wrap;gap:6px 20px;font:12.5px var(--mono);color:var(--muted);margin-top:12px}}
.meta b{{color:var(--ink);font-weight:500}}
.tiles{{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px}}
.tile{{background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:14px 16px}}
.tile .k{{font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);font-weight:600}}
.tile .v{{font-size:30px;font-weight:700;font-variant-numeric:tabular-nums;line-height:1.2}}
.tile .s{{font-size:12.5px;color:var(--muted)}}
.tile.pass .v{{color:var(--pass)}} .tile.fail .v{{color:var(--fail)}} .tile.check .v{{color:var(--check)}} .tile.cover .v{{color:var(--accent)}}
.find{{display:flex;flex-direction:column;gap:10px}}
.f{{background:var(--surface);border:1px solid var(--line);border-left:4px solid var(--na);border-radius:8px;padding:12px 16px;min-width:0}}
.f.fail{{border-left-color:var(--fail)}} .f.check{{border-left-color:var(--check)}}
.f h3{{font-size:15px;margin:0 0 4px;display:flex;gap:10px;align-items:center;flex-wrap:wrap}}
.f p{{margin:2px 0;font-size:14px}} .f .src{{color:var(--muted);font-size:13px}}
code{{font-family:var(--mono);font-size:.86em;background:var(--na-bg);padding:.05em .35em;border-radius:4px}}
.pill{{display:inline-block;font-size:11.5px;font-weight:600;padding:2px 9px;border-radius:99px;white-space:nowrap}}
.pill.pass{{color:var(--pass);background:var(--pass-bg)}} .pill.fail{{color:var(--fail);background:var(--fail-bg)}}
.pill.check{{color:var(--check);background:var(--check-bg)}} .pill.na{{color:var(--na);background:var(--na-bg)}}
.tw{{overflow-x:auto;background:var(--surface);border:1px solid var(--line);border-radius:10px}}
table{{border-collapse:collapse;width:100%;min-width:900px;font-size:13px}}
th{{text-align:left;font-size:11px;letter-spacing:.07em;text-transform:uppercase;color:var(--muted);padding:10px 12px;border-bottom:1px solid var(--line);white-space:nowrap}}
td{{padding:8px 12px;vertical-align:top;border-bottom:1px solid var(--line)}}
tr.first td{{border-top:1px solid var(--line)}}
td.ev{{font:500 12.5px var(--mono);white-space:nowrap}} td.al{{color:var(--muted);font-size:12px;max-width:180px}}
td.act{{font:12px var(--mono);max-width:300px;overflow-wrap:anywhere}} td.bs{{font-size:12.5px;color:var(--muted);max-width:320px}}
.shots{{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:12px}}
figure{{margin:0;background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:8px;display:flex;flex-direction:column;gap:6px}}
figure img{{width:100%;border-radius:6px;display:block}} figcaption{{font-size:12px;color:var(--muted);line-height:1.4}}
ol.how{{margin:0;padding-left:20px;max-width:75ch}} ol.how li{{margin-bottom:6px}}
.panel{{background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:16px 18px}}
</style>
<div class="wrap">
<header>
  <h1>Event tracking Genius 2.9.0 — Library &amp; khay tạo nền</h1>
  <p class="lede">Chạy automation trên máy thật theo spec <code>genius-eventtracking-library.xlsx</code>: 14 event, 34 dòng param. Mỗi dòng được chấm từ event app thực sự ghi ra trong lúc XCUITest thao tác.</p>
  <div class="meta"><span>Thiết bị <b>iPhone 12 · iOS 26.5.2</b></span><span>Build <b>Debug · env prod</b></span><span>Ngày chạy <b>21/10/2026</b></span><span>Gói <b>Weekly Sandbox (mua 10:18)</b></span></div>
</header>
<section class="tiles">
  <div class="tile cover"><div class="k">Đã chạy</div><div class="v">{done}/{len(rows)}</div><div class="s">{round(done*100/len(rows),1)}% dòng param</div></div>
  <div class="tile pass"><div class="k">Pass</div><div class="v">{cnt['PASS']}</div></div>
  <div class="tile fail"><div class="k">Fail</div><div class="v">{cnt['FAIL']}</div><div class="s">3 lỗi khác nhau</div></div>
  <div class="tile check"><div class="k">Cần xác nhận</div><div class="v">{cnt['CHECK']}</div></div>
  <div class="tile"><div class="k">Chưa test</div><div class="v">{cnt['NA']}</div><div class="s">cần Library trống</div></div>
</section>
<section>
  <h2>Kết luận cần xử lý</h2>
  <div class="find">
  {''.join(f"<div class='f {s.lower()}'><h3><span class='pill {s.lower()}'>{LABEL[s]}</span>{t}</h3><p>{w}</p><p class='src'>{src}</p></div>" for s, t, w, src in FINDINGS)}
  </div>
</section>
<section>
  <h2>Kết quả từng dòng spec</h2>
  <div class="tw"><table>
  <thead><tr><th>Event</th><th>Param</th><th>Allowed values</th><th>Status</th><th>Giá trị đo được (theo bước)</th><th>Căn cứ</th></tr></thead>
  <tbody>{table_rows()}</tbody></table></div>
</section>
<section>
  <h2>Ảnh minh chứng</h2>
  <div class="shots">{''.join(f"<figure><img src='{img(n)}' alt='{e(c)}'><figcaption>{e(c)}</figcaption></figure>" for n, c in SHOTS)}</div>
</section>
<section class="panel">
  <h2>Cách đo</h2>
  <ol class="how">
    <li>App ghi mọi event (cùng chỗ gọi Firebase, <code>AnalyticsTracker.track</code>) vào <code>~/Documents/*.jsonl</code> khi chạy với <code>EVENT_SINK_PATH</code>. Kéo file về bằng <code>devicectl copy from</code>.</li>
    <li>Kịch bản in mốc thời gian ngay trước mỗi thao tác. Event thuộc bước nào thì có <code>ts</code> nằm giữa mốc của bước đó và mốc của bước kế tiếp. Mỗi thao tác phải bắn đúng 1 lần, thừa thì Fail.</li>
    <li>Đã kiểm thêm: chạm lại bộ lọc đang chọn không bắn event. <code>time_to_action</code> của <code>library_complete</code> khớp thời gian ở màn đo được (lệch &lt;5 ms).</li>
    <li>4 lượt chạy: duyệt/lọc/chọn/huỷ xoá · khay tạo nền (1 video + 1 ảnh) · mất mạng (Airplane Mode) + Retry · xoá thật 1 ảnh vừa tạo. Không mock, không sửa response.</li>
  </ol>
</section>
</div>
"""
open(OUT, "w").write(page)
print("wrote", OUT, len(page))
