"""Chấm event tracking Library 2.9.0 từ log XCUITest (mốc ETSTEP) + file sink JSONL của app.

    python evaluate_event_tracking_library.py <runs-dir> <spec.xlsx> <out.xlsx> <out-summary.json>

Mỗi bước của kịch bản in `ETSTEP|<bước>|<ms>` ngay TRƯỚC thao tác; event thuộc bước nào là event có
`ts` nằm trong [mốc bước, mốc bước kế). Lấy lượt chạy MỚI NHẤT của mỗi test (et-test01*, 02*, 03*).
"""
import glob, json, os, re, sys
import openpyxl
from openpyxl.styles import PatternFill, Alignment, Font

RUNS, SPEC, OUT_XLSX, OUT_JSON = sys.argv[1:5]

# ---------- nạp lượt chạy ----------
def load_run(prefix):
    logs = sorted(glob.glob(os.path.join(RUNS, f"{prefix}-*.log")), key=os.path.getmtime)
    logs = [l for l in logs if os.path.exists(l[:-4] + ".jsonl")]
    if not logs:
        return None
    log = logs[-1]
    steps, notes, seen = [], {}, set()
    for line in open(log, errors="ignore"):
        m = re.search(r"ETSTEP\|([^|]+)\|(\d+)", line)
        if m and m.group(0) not in seen:
            seen.add(m.group(0)); steps.append((m.group(1), int(m.group(2))))
        m = re.search(r"ETNOTE\|([^|]+)\|(.*)$", line)
        if m: notes[m.group(1)] = m.group(2).strip()
    events = [json.loads(l) for l in open(log[:-4] + ".jsonl") if l.strip()]
    return {"name": os.path.basename(log)[:-4], "steps": steps, "notes": notes, "events": events}

RUN = {k: load_run(f"et-{k}") for k in ("test01", "test02", "test03", "test04")}

def window(step):
    """Event nằm trong cửa sổ của bước `step` — trùng tên bước thì lấy lượt chạy sau (test04 > test02)."""
    for run in reversed(list(RUN.values())):
        if not run: continue
        st = run["steps"]
        for i, (name, ts) in enumerate(st):
            if name == step:
                end = st[i + 1][1] if i + 1 < len(st) else 10**15
                return run, [e for e in run["events"] if ts <= e["ts"] < end]
    return None, None

def lib(e): return e["name"].startswith("library_") or e["name"].startswith("gen_tray_")

# ---------- kỳ vọng theo từng bước ----------
# (event, bước, tham số kỳ vọng — None = chỉ cần có mặt, callable = hàm kiểm)
EXPECT = [
    ("library_view", "open_library", {}), ("library_view", "back_from_media", {}), ("library_view", "reenter_library", {}),
    ("library_load_success", "open_library", {}), ("library_load_success", "reenter_library", {}),
    ("library_load_fail", "open_library_offline", {}),
    ("library_start_creating_click", "start_creating", {}),
    ("library_filter_click", "filter_image", {"filter": "image"}), ("library_filter_click", "filter_video", {"filter": "video"}),
    ("library_filter_click", "filter_conversation", {"filter": "conversation"}), ("library_filter_click", "filter_all", {"filter": "all"}),
    ("library_item_click", "item_open_media", {"status": "success"}),
    ("library_item_click", "item_open_conversation", {"source_feature": "AI Chat", "status": "success"}),
    ("library_item_click", "pending_cell_click", {"status": "loading"}),
    ("library_select_click", "select", {}), ("library_select_click", "select_multi", {}),
    ("library_select_cancel_click", "select_cancel", {}), ("library_select_cancel_click", "select_cancel_multi", {}),
    ("library_delete_click", "item_menu_delete", {"source": "item_menu", "selected_count": "1"}),
    ("library_delete_click", "multi_delete", {"source": "multi_select", "selected_count": "2"}),
    ("library_delete_click", "real_delete_menu", {"source": "item_menu", "selected_count": "1"}),
    ("library_delete_dialog_click", "dialog_cancel_one", {"action": "cancel", "selected_count": "1", "deleted_count": "0"}),
    ("library_delete_dialog_click", "dialog_cancel_multi", {"action": "cancel", "selected_count": "2", "deleted_count": "0"}),
    ("library_delete_dialog_click", "real_delete_confirm", {"action": "delete", "selected_count": "1", "deleted_count": "1"}),
    ("library_complete", "item_open_media", {}), ("library_complete", "item_open_conversation", {}), ("library_complete", "leave_to_home", {}),
    ("gen_tray_view", "leave_video_generating", {"running_count": "1"}),
    ("gen_tray_view", "leave_image_generating", {"running_count": "2"}),
    ("gen_tray_click", "tray_click_running", {"state": "running", "destination": "generating"}),
    ("gen_tray_click", "tray_click_done", {"state": "done", "destination": "library"}),
    ("gen_tray_retry_click", "tray_retry_offline", {}), ("gen_tray_retry_click", "tray_retry_online", {}),
]
# Bước mà KHÔNG được có event (chạm lại bộ lọc đang chọn).
EXPECT_NONE = [("library_filter_click", "filter_all_again")]

# ---------- spec ----------
wb = openpyxl.load_workbook(SPEC)
ws = wb.active
rows, cur = [], None
for r in range(2, ws.max_row + 1):
    ev = ws.cell(r, 3).value or cur
    cur = ev
    rows.append({"row": r, "event": ev, "param": ws.cell(r, 6).value, "allowed": ws.cell(r, 8).value,
                 "type": ws.cell(r, 9).value, "source": ws.cell(r, 7).value})

def allowed_set(a): return [x.strip() for x in str(a).split("|")] if a else []

def type_ok(v, t):
    if t in ("int", "long"): return re.fullmatch(r"-?\d+", v or "") is not None
    if t == "bool": return v in ("true", "false")
    return v is not None

# ---------- chấm ----------
occ = {}   # event -> list of (step, matched events, expected)
for ev, step, exp in EXPECT:
    run, evs = window(step)
    if evs is None:
        occ.setdefault(ev, []).append({"step": step, "ran": False, "hits": [], "exp": exp}); continue
    hits = [e for e in evs if e["name"] == ev]
    occ.setdefault(ev, []).append({"step": step, "ran": True, "hits": hits, "exp": exp, "run": run["name"]})

def last_view_before(run_name, ts):
    run = next(r for r in RUN.values() if r and r["name"] == run_name)
    views = [e["ts"] for e in run["events"] if e["name"] == "library_view" and e["ts"] < ts]
    return views[-1] if views else None

def fmt(e): return "{" + ", ".join(f"{k}: {v}" for k, v in sorted(e["params"].items())) + "}"

results = []
for row in rows:
    ev, p = row["event"], row["param"]
    obs = occ.get(ev, [])
    ran = [o for o in obs if o["ran"]]
    status, actual, basis = "NA", "—", ""
    if not ran:
        status = "NA"
        basis = "Chưa chạy được bước kích hoạt: " + ", ".join(o["step"] for o in obs)
    else:
        problems, values = [], []
        for o in ran:
            n = len(o["hits"])
            if n == 0: problems.append(f"bước {o['step']}: KHÔNG bắn"); continue
            if n > 1: problems.append(f"bước {o['step']}: bắn {n} lần (1 thao tác)")
            e = o["hits"][0]
            v = e["params"].get(p)
            values.append(f"{o['step']}={v}")
            if v is None: problems.append(f"bước {o['step']}: thiếu param `{p}`"); continue
            if p in o["exp"] and o["exp"][p] != v: problems.append(f"bước {o['step']}: `{p}`={v}, kỳ vọng {o['exp'][p]}")
            al = allowed_set(row["allowed"])
            if al and v not in al: problems.append(f"bước {o['step']}: `{p}`={v} ngoài Allowed Values {al}")
            if p == "feature_name" and ev.startswith("library_") and v != "Library": problems.append(f"`feature_name`={v}")
            if p == "error_code" and v == "": problems.append(f"bước {o['step']}: `error_code` rỗng — app không giữ mã lỗi của lượt hỏng")
            if not type_ok(v, row["type"]): problems.append(f"`{p}`={v} không đúng kiểu {row['type']}")
            if ev == "library_complete" and p == "time_to_action":
                lv = last_view_before(o["run"], e["ts"])
                if lv is not None and abs((e["ts"] - lv) - int(v)) > 1500:
                    problems.append(f"time_to_action {v} ms ≠ thời gian ở màn đo được {e['ts'] - lv} ms")
                values[-1] += f" (đo {e['ts'] - lv if lv else '?'} ms)"
        for evn, step in EXPECT_NONE:
            if evn == ev:
                run, evs = window(step)
                if evs is not None and any(e["name"] == ev for e in evs):
                    problems.append(f"bước {step}: chạm lại bộ lọc đang chọn vẫn bắn")
        actual = " · ".join(dict.fromkeys(values)) or "—"
        missing = [o["step"] for o in obs if not o["ran"]]
        status = "FAIL" if problems else "PASS"
        basis = "; ".join(problems) if problems else f"đúng ở {len(ran)} lần thao tác"
        # Spec: "Số kết quả đã tạo" — app gửi số ô của TRANG ĐẦU (listJobs limit 20), kho có hơn 20 ô vẫn ra 20.
        if not problems and ev == "library_load_success" and p == "item_count" and values and all(v.endswith("=20") for v in values):
            status = "CHECK"
            basis = ("app gửi số ô trang đầu (pageSize 20, CreationLibrary.swift:96/189: items.count của listJobs limit 20); "
                     "kho có hơn 20 kết quả thì vẫn chỉ ra 20 — spec ghi 'Số kết quả đã tạo', cần PO chốt nghĩa")
        if missing: basis += f" · chưa chạy: {', '.join(missing)}"
    results.append({**row, "status": status, "actual": actual, "basis": basis})

# ---------- xuất ----------
FILL = {"PASS": "C6EFCE", "FAIL": "FFC7CE", "NA": "E7E6E6", "CHECK": "FFEB9C"}
c0 = ws.max_column
for i, h in enumerate(["Actual value (đo trên máy)", "Status", "Căn cứ kết luận"]):
    cell = ws.cell(1, c0 + 1 + i, h); cell.font = Font(bold=True)
for res in results:
    r = res["row"]
    ws.cell(r, c0 + 1, res["actual"]); s = ws.cell(r, c0 + 2, res["status"]); ws.cell(r, c0 + 3, res["basis"])
    s.fill = PatternFill("solid", fgColor=FILL[res["status"]])
    for k in range(1, 4): ws.cell(r, c0 + k).alignment = Alignment(wrap_text=True, vertical="top")
for col, w in zip("LMN", (55, 10, 70)): ws.column_dimensions[col].width = w

log = wb.create_sheet("Event log")
log.append(["Lượt chạy", "Bước", "Mốc (ms)", "Event", "Params", "ts"])
for run in RUN.values():
    if not run: continue
    st = run["steps"]
    for i, (name, ts) in enumerate(st):
        end = st[i + 1][1] if i + 1 < len(st) else 10**15
        for e in [e for e in run["events"] if ts <= e["ts"] < end and lib(e)]:
            log.append([run["name"], name, ts, e["name"], fmt(e), e["ts"]])
wb.save(OUT_XLSX)

summary = {"runs": {k: (v and {"name": v["name"], "notes": v["notes"], "steps": len(v["steps"]), "events": len(v["events"])}) for k, v in RUN.items()},
           "rows": results}
json.dump(summary, open(OUT_JSON, "w"), ensure_ascii=False, indent=1, default=str)
cnt = {}
for r in results: cnt[r["status"]] = cnt.get(r["status"], 0) + 1
print("rows:", len(results), cnt)
for r in results:
    print(f"{r['row']:>3} {r['event']:<30} {str(r['param']):<16} {r['status']:<5} {r['actual'][:70]} | {r['basis'][:110]}")
