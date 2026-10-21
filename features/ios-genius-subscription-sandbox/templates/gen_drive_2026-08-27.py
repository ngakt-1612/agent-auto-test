#!/usr/bin/env python3
"""
Driver Appium cho round GEN ẢNH (I2I · Enhance · Restore · Remove Object · WC Looks · TryOn).

Vì sao có file này thay vì dùng net_drive_2026-08-25.py:
`texts` của driver cũ gọi 3 HTTP request cho MỖI element (label + value + name) nên ở màn
nhiều element (Home, Result, Settings) nó chạy rất lâu và **trả rỗng im lặng** — đã cắn 3 lần
ngày 27/08. Driver này GET /source đúng MỘT lần rồi parse XML tại máy: nhanh, không mất dữ liệu,
và có sẵn toạ độ tâm element để tap những control không click được qua /element/{id}/click.

Dùng: /usr/bin/python3 gen_drive_2026-08-27.py <cmd> [args]
  labels [loc]      — in mọi element có label/value (loc=1 thì kèm toạ độ)
  find "<label>"    — in toạ độ tâm + type của element khớp label
  tap "<label>"     — tap tâm element khớp label (khớp chính xác, rồi khớp chứa)
  tapxy x y         — tap toạ độ
  wait "<label>" [s]— poll 1s tới khi thấy label (mặc định 120s)
  watch [s] [step]  — poll và in label MỚI so với mốc t=0 (bắt toast bung muộn, sống ngắn)
  shot <path>       — chụp màn
  state             — app state (4=foreground, 1=not running)
  drag x1 y1 x2 y2 [ms] — kéo (slider Before/After)
Session dùng chung file /tmp/genius_appium_session.txt với net_drive_2026-08-25.py.
"""
import json, sys, time, base64, re, urllib.request, urllib.error

BASE = "http://127.0.0.1:4723"
SESS_FILE = "/tmp/genius_appium_session.txt"
BUNDLE = "aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty"
TIMEOUT = 600

def _req(method, path, body=None, timeout=TIMEOUT):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"error_http": e.code, "body": e.read().decode()[:800]}
    except Exception as e:
        return {"error_exc": repr(e)[:300]}

def sid(): return open(SESS_FILE).read().strip()

def _source():
    r = _req("GET", f"/session/{sid()}/source")
    v = r.get("value")
    if not isinstance(v, str):
        print("SOURCE_FAIL", json.dumps(r)[:400]); sys.exit(2)
    return v

_EL = re.compile(r'<(XCUIElementType\w+)([^>]*)/?>')
def _parse(src):
    """[(type, label, value, x, y, w, h)] — bỏ element không có label lẫn value."""
    out = []
    for m in _EL.finditer(src):
        ty, attrs = m.group(1), m.group(2)
        def a(k):
            mm = re.search(k + r'="([^"]*)"', attrs)
            return mm.group(1) if mm else ""
        lab, val, nm = a('label'), a('value'), a('name')
        lab = lab or nm
        if not lab and not val: continue
        try:
            x, y, w, h = int(a('x') or 0), int(a('y') or 0), int(a('width') or 0), int(a('height') or 0)
        except ValueError:
            x = y = w = h = 0
        import html as _h
        out.append((ty, _h.unescape(lab), _h.unescape(val), x, y, w, h))
    return out

def labels(loc=""):
    for ty, lab, val, x, y, w, h in _parse(_source()):
        s = f"{ty.replace('XCUIElementType','')}|{lab}|{val}"
        if loc: s += f"|@{x+w//2},{y+h//2} ({w}x{h})"
        print(s)

def _match(label, els=None):
    els = els or _parse(_source())
    for e in els:                                    # khớp chính xác trước
        if e[1] == label or e[2] == label: return e
    low = label.lower()
    for e in els:                                    # rồi khớp chứa
        if low in e[1].lower() or low in e[2].lower(): return e
    return None

def find(label):
    e = _match(label)
    print("NOTFOUND" if not e else
          f"FOUND {e[0].replace('XCUIElementType','')}|{e[1]}|@{e[3]+e[5]//2},{e[4]+e[6]//2}")

def tapxy(x, y):
    r = _req("POST", f"/session/{sid()}/actions", {"actions": [{
        "type": "pointer", "id": "finger1", "parameters": {"pointerType": "touch"},
        "actions": [{"type": "pointerMove", "duration": 0, "x": int(x), "y": int(y)},
                    {"type": "pointerDown", "button": 0},
                    {"type": "pause", "duration": 120},
                    {"type": "pointerUp", "button": 0}]}]})
    print("TAPXY", x, y, "OK" if "error" not in json.dumps(r) else json.dumps(r)[:200])

def tap(label):
    e = _match(label)
    if not e: print("TAP_NOTFOUND", label); return
    tapxy(e[3] + e[5] // 2, e[4] + e[6] // 2)
    print("  ->", e[0].replace('XCUIElementType', ''), "|", e[1])

def drag(x1, y1, x2, y2, ms=600):
    r = _req("POST", f"/session/{sid()}/actions", {"actions": [{
        "type": "pointer", "id": "finger1", "parameters": {"pointerType": "touch"},
        "actions": [{"type": "pointerMove", "duration": 0, "x": int(x1), "y": int(y1)},
                    {"type": "pointerDown", "button": 0},
                    {"type": "pointerMove", "duration": int(ms), "x": int(x2), "y": int(y2)},
                    {"type": "pointerUp", "button": 0}]}]})
    print("DRAG", f"({x1},{y1})->({x2},{y2})", "OK" if "error" not in json.dumps(r) else json.dumps(r)[:200])

def wait(label, secs=120):
    t0 = time.time()
    while time.time() - t0 < float(secs):
        if _match(label):
            print(f"WAIT_OK {label} sau {time.time()-t0:.0f}s"); return
        time.sleep(1)
    print(f"WAIT_TIMEOUT {label} sau {secs}s")

def watch(secs=180, step=1):
    """Poll và in label MỚI so với mốc t=0. Toast của Genius bung rất muộn và sống ngắn
    (Save ~14s, Share ~61s) — poll 3–5s là trượt cửa sổ, nên mặc định 1s."""
    base = {e[1] for e in _parse(_source())}
    print(f"WATCH t=0: {len(base)} label")
    t0 = time.time()
    while time.time() - t0 < float(secs):
        time.sleep(float(step))
        now = _parse(_source())
        for e in now:
            if e[1] not in base:
                print(f"  +{time.time()-t0:5.1f}s  MỚI: {e[0].replace('XCUIElementType','')}|{e[1]}|{e[2]}")
                base.add(e[1])
    print("WATCH_DONE")

def type_text(label, text):
    """Go text vao field: tap vao field theo toa do roi gui keys (bam tung phim khong an - bai hoc Round 2)."""
    e = _match(label)
    if not e: print("TYPE_NOTFOUND", label); return
    tapxy(e[3] + e[5] // 2, e[4] + e[6] // 2)
    time.sleep(1)
    r = _req("POST", f"/session/{sid()}/actions", {"actions": [{
        "type": "key", "id": "kb",
        "actions": [a for ch in text for a in
                    ({"type": "keyDown", "value": ch}, {"type": "keyUp", "value": ch})]}]})
    print("TYPE", label, "<-", text, "OK" if "error" not in json.dumps(r) else json.dumps(r)[:200])

def shot(path):
    r = _req("GET", f"/session/{sid()}/screenshot")
    b64 = r.get("value")
    if isinstance(b64, str):
        open(path, "wb").write(base64.b64decode(b64)); print("SHOT_OK", path)
    else: print("SHOT_FAIL", json.dumps(r)[:300])

def state():
    r = _req("POST", f"/session/{sid()}/appium/device/app_state", {"bundleId": BUNDLE})
    print("APP_STATE", r.get("value"))

if __name__ == "__main__":
    c, a = sys.argv[1], sys.argv[2:]
    {"labels": lambda: labels(*a), "find": lambda: find(a[0]), "tap": lambda: tap(a[0]),
     "tapxy": lambda: tapxy(a[0], a[1]), "drag": lambda: drag(*a),
     "wait": lambda: wait(*a), "watch": lambda: watch(*a),
     "shot": lambda: shot(a[0]), "state": state, "type": lambda: type_text(a[0], a[1])}[c]()
