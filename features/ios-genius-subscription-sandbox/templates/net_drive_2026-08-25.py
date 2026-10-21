#!/usr/bin/env python3
"""
Driver Appium cho Round 3 — nhóm case MẤT KẾT NỐI / MẠNG YẾU (G2), máy thật iOS.
Bổ sung so với appium_drive.py: timeout dài, caps theo RUNBOOK update ① (Appium tự build WDA),
alert helpers (alert hệ thống KHÔNG có trong XML source — bài học Round 2), activate_app,
background, và toggle switch trong iOS Settings (tap đúng control bên phải x≈331pt).

Dùng: /usr/bin/python3 net_drive_2026-08-25.py <cmd> [args]
"""
import json, sys, urllib.request, urllib.error, base64, time, re, os

BASE = "http://127.0.0.1:4723"
SESS_FILE = "/tmp/genius_appium_session.txt"
DEV = "00008120-001A20320282201E"          # iPhone Tester 2 (14 Pro, iOS 26.4.2)
BUNDLE = "aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty"
PREFS = "com.apple.Preferences"
TIMEOUT = 600

def _req(method, path, body=None, timeout=TIMEOUT):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"error_http": e.code, "body": e.read().decode()[:1200]}
    except Exception as e:
        return {"error_exc": repr(e)[:400]}

def sid():
    return open(SESS_FILE).read().strip()

def create(bundle=BUNDLE):
    """Tạo session. Nếu máy đang KHOÁ thì session kèm bundleId sẽ fail
    ("device was not, or could not be, unlocked") mà muốn mở khoá lại cần session
    -> tự động fallback: tạo session KHÔNG bundleId -> unlock -> activate.
    Đã vấp 3 lần nên gói sẵn ở đây, đừng tự ghép tay nữa."""
    if _create(bundle): return
    print("  session kèm bundleId fail — thử không kèm bundleId (máy có thể đang khoá)")
    if _create(None):
        unlock(); time.sleep(2)
        activate(bundle or BUNDLE)

def _create(bundle=BUNDLE):
    caps = {"capabilities": {"alwaysMatch": {
        "platformName": "iOS",
        "appium:automationName": "XCUITest",
        "appium:udid": DEV,
        "appium:bundleId": bundle,
        "appium:usePrebuiltWDA": False,
        "appium:xcodeOrgId": "KS4Z2R52B4",
        "appium:xcodeSigningId": "Apple Development",
        "appium:updatedWDABundleId": "com.apero.wda",
        "appium:noReset": True,
        "appium:newCommandTimeout": 1800,
        "appium:wdaLaunchTimeout": 420000,
        "appium:wdaConnectionTimeout": 420000,
        "appium:waitForQuiescence": False,
        "appium:shouldTerminateApp": False,
    }, "firstMatch": [{}]}}
    if not bundle:
        caps["capabilities"]["alwaysMatch"].pop("appium:bundleId", None)
    r = _req("POST", "/session", caps)
    v = r.get("value") if isinstance(r, dict) else None
    if isinstance(v, dict) and v.get("sessionId"):
        open(SESS_FILE, "w").write(v["sessionId"])
        print("SESSION_OK", v["sessionId"], "" if bundle else "(không kèm bundleId)")
        return True
    print("  SESSION_FAIL", json.dumps(r)[:300])
    return False

def shot(path):
    r = _req("GET", f"/session/{sid()}/screenshot")
    b64 = r.get("value")
    if isinstance(b64, str):
        open(path, "wb").write(base64.b64decode(b64)); print("SHOT_OK", path)
    else:
        print("SHOT_FAIL", json.dumps(r)[:400])

def source(maxlen=6000):
    r = _req("GET", f"/session/{sid()}/source")
    v = r.get("value")
    print(v[:int(maxlen)] if isinstance(v, str) else json.dumps(r)[:600])

def texts():
    """Liệt kê mọi label/value nhìn thấy — nhanh hơn đọc XML thô."""
    r = _req("POST", f"/session/{sid()}/elements",
             {"using": "-ios predicate string",
              "value": "type IN {'XCUIElementTypeStaticText','XCUIElementTypeButton','XCUIElementTypeSwitch','XCUIElementTypeOther'} AND (label != '' OR value != '')"})
    els = r.get("value") or []
    if not isinstance(els, list):
        print("TEXTS_FAIL", json.dumps(r)[:400]); return
    out = []
    for e in els:
        eid = e.get("ELEMENT") or e.get("element-6066-11e4-a52e-4f735466cecf")
        if not eid: continue
        nm = _req("GET", f"/session/{sid()}/element/{eid}/attribute/label", timeout=60).get("value")
        vl = _req("GET", f"/session/{sid()}/element/{eid}/attribute/value", timeout=60).get("value")
        ty = _req("GET", f"/session/{sid()}/element/{eid}/name", timeout=60).get("value")
        if nm or vl:
            out.append(f"{ty}|label={nm}|value={vl}")
    print("\n".join(dict.fromkeys(out)))

def _find(txt):
    for using, val in [("accessibility id", txt),
                       ("-ios predicate string", f"name == '{txt}' OR label == '{txt}'"),
                       ("-ios predicate string", f"label CONTAINS '{txt}' OR name CONTAINS '{txt}'")]:
        r = _req("POST", f"/session/{sid()}/element", {"using": using, "value": val})
        el = r.get("value")
        if isinstance(el, dict):
            eid = el.get("ELEMENT") or el.get("element-6066-11e4-a52e-4f735466cecf")
            if eid: return eid
    return None

def tap(txt):
    eid = _find(txt)
    if not eid: print("TAP_NOTFOUND", txt); return
    c = _req("POST", f"/session/{sid()}/element/{eid}/click", {})
    print("TAP", txt, "->", "OK" if "value" in c else json.dumps(c)[:200])

def exists(txt):
    print("EXISTS" if _find(txt) else "ABSENT", txt)

def tapxy(x, y):
    body = {"actions":[{"type":"pointer","id":"finger1","parameters":{"pointerType":"touch"},
        "actions":[{"type":"pointerMove","duration":0,"x":int(x),"y":int(y)},
                   {"type":"pointerDown","button":0},{"type":"pause","duration":80},
                   {"type":"pointerUp","button":0}]}]}
    r = _req("POST", f"/session/{sid()}/actions", body)
    print("TAP_XY", x, y, "OK" if "value" in r else json.dumps(r)[:200])

def alert_text():
    r = _req("GET", f"/session/{sid()}/alert/text", timeout=60)
    print("ALERT_TEXT", json.dumps(r.get("value"))[:600] if "value" in r else json.dumps(r)[:300])

def alert(action):
    r = _req("POST", f"/session/{sid()}/alert/{action}", {}, timeout=60)
    print("ALERT_" + action.upper(), "OK" if "value" in r else json.dumps(r)[:300])

def activate(bundle=BUNDLE):
    r = _req("POST", f"/session/{sid()}/appium/device/activate_app", {"bundleId": bundle})
    print("ACTIVATE", bundle, "OK" if "value" in r else json.dumps(r)[:300])

def terminate(bundle=BUNDLE):
    """Kill app hẳn (nhóm case Vòng đời). Verify bằng state: 1 = not running."""
    r = _req("POST", f"/session/{sid()}/appium/device/terminate_app", {"bundleId": bundle})
    print("TERMINATE", bundle, "OK" if "value" in r else json.dumps(r)[:300])

def state(bundle=BUNDLE):
    r = _req("POST", f"/session/{sid()}/appium/device/app_state", {"bundleId": bundle})
    print("APP_STATE", json.dumps(r.get("value")))

def background(secs):
    r = _req("POST", f"/session/{sid()}/appium/app/background", {"seconds": int(secs)})
    print("BACKGROUND", secs, "OK" if "value" in r else json.dumps(r)[:300])

def toggle_row(label, want):
    """Bật/tắt 1 switch trong iOS Settings. Bài học Round 2: phải tap control bên PHẢI
    (x≈331pt), tap tâm hàng đè lên nhãn nên không ăn. Luôn đọc lại value để verify."""
    eid = _find(label)
    if not eid: print("ROW_NOTFOUND", label); return
    rect = _req("GET", f"/session/{sid()}/element/{eid}/rect").get("value") or {}
    y = rect.get("y", 0) + rect.get("height", 0)/2
    cur = _req("GET", f"/session/{sid()}/element/{eid}/attribute/value").get("value")
    print("ROW", label, "rect=", rect, "value_before=", cur)
    if str(cur) == str(want):
        print("ALREADY", want); return
    tapxy(331, y); time.sleep(1.5)
    eid2 = _find(label)
    now = _req("GET", f"/session/{sid()}/element/{eid2}/attribute/value").get("value") if eid2 else None
    print("VALUE_AFTER", now, "-> ", "OK" if str(now) == str(want) else "FAIL")


# ─────────── Network Link Conditioner (Settings ▸ Developer ▸ NLC) ───────────
# Dùng cho nhóm case MẤT KẾT NỐI / TIMEOUT (G2). Ưu điểm so với Airplane mode:
# Wi-Fi vẫn associated nên app không biết mình bị chặn ở tầng nào, sát thực tế hơn.
# Enable switch: control thật ở x≈331 (bài học Round 2 — tap tâm hàng KHÔNG ăn).
NLC_SWITCH_XY = (331, 157)

def _clear_settings_search():
    """Thoat khoi man ket qua Search cua Settings.
    Bug that: neu o Search con text tu lan truoc thi Settings dung o man ket qua,
    vong BackButton KHONG thoat ra duoc -> _open_nlc bao 'no NLC row' va nlc()
    IM LANG THAT BAI (mang khong doi, case chay sai ma khong biet). Da can 3 lan."""
    r = _req("POST", f"/session/{sid()}/elements",
             {"using": "-ios predicate string", "value": "type == 'XCUIElementTypeSearchField'"})
    for e in (r.get("value") or []):
        i = e.get("ELEMENT") or e.get("element-6066-11e4-a52e-4f735466cecf")
        if i:
            _req("POST", f"/session/{sid()}/element/{i}/clear", {}); time.sleep(1)
    for lbl in ("Cancel", "Huỷ"):
        eid = _find(lbl)
        if eid:
            _req("POST", f"/session/{sid()}/element/{eid}/click", {}); time.sleep(1.2); break

def _settings_root(maxback=10):
    """Back ra tan root cua Settings. Phai du sau: khi dang o Apps > Genius > Photos
    la 3-4 tang, maxback=6 cu tung khong ve toi root -> _open_nlc bao 'no Developer row'
    va mang KHONG duoc doi (im lang chay sai ca case). Verify bang NavigationBar name."""
    activate(PREFS); time.sleep(2)
    _clear_settings_search()
    for _ in range(maxback):
        eid = _find("BackButton")
        if not eid: break
        _req("POST", f"/session/{sid()}/element/{eid}/click", {}); time.sleep(1.2)
    src = _req("GET", f"/session/{sid()}/source").get("value") or ""
    at_root = 'XCUIElementTypeNavigationBar type="XCUIElementTypeNavigationBar" name="Settings"' in src
    if not at_root:
        print("WARN not at Settings root after", maxback, "back taps")
    # cuon len dinh de vong tim Developer luon bat dau tu cung 1 diem
    for _ in range(6):
        _swipe_down()
    return at_root

def _swipe_down():
    body = {"actions":[{"type":"pointer","id":"f1","parameters":{"pointerType":"touch"},
        "actions":[{"type":"pointerMove","duration":0,"x":200,"y":250},
                   {"type":"pointerDown","button":0},
                   {"type":"pointerMove","duration":300,"x":200,"y":750},
                   {"type":"pointerUp","button":0}]}]}
    _req("POST", f"/session/{sid()}/actions", body); time.sleep(0.6)

def _open_nlc():
    _settings_root()
    # Developer nằm cuối list → scroll xuống cho tới khi thấy
    for _ in range(14):
        if _find("Developer"): break
        _swipe_up()
    eid = _find("Developer")
    if not eid: print("NLC_FAIL no Developer row"); return False
    _req("POST", f"/session/{sid()}/element/{eid}/click", {}); time.sleep(2.5)
    eid = _find("Network Link Conditioner")
    if not eid: print("NLC_FAIL no NLC row"); return False
    _req("POST", f"/session/{sid()}/element/{eid}/click", {}); time.sleep(2.5)
    return True

def _swipe_up():
    body = {"actions":[{"type":"pointer","id":"f1","parameters":{"pointerType":"touch"},
        "actions":[{"type":"pointerMove","duration":0,"x":200,"y":700},
                   {"type":"pointerDown","button":0},
                   {"type":"pointerMove","duration":400,"x":200,"y":200},
                   {"type":"pointerUp","button":0}]}]}
    _req("POST", f"/session/{sid()}/actions", body); time.sleep(1)

def _enable_value():
    """Phải trỏ đúng XCUIElementTypeSwitch — trên màn NLC còn 1 Button cùng label 'Enable'
    không có attribute value, _find() bắt trúng nó thì đọc ra None."""
    r = _req("POST", f"/session/{sid()}/element",
             {"using": "-ios predicate string",
              "value": "type == 'XCUIElementTypeSwitch' AND name == 'Enable'"})
    el = r.get("value")
    if not isinstance(el, dict): return None
    eid = el.get("ELEMENT") or el.get("element-6066-11e4-a52e-4f735466cecf")
    if not eid: return None
    return _req("GET", f"/session/{sid()}/element/{eid}/attribute/value").get("value")

def nlc(arg):
    """nlc off            -> tắt NLC
       nlc '100% Loss'    -> chọn preset rồi bật NLC"""
    if not _open_nlc(): return
    want_off = str(arg).lower() == "off"
    if not want_off:
        eid = _find(arg)
        if not eid: print("NLC_FAIL preset not found:", arg); return
        _req("POST", f"/session/{sid()}/element/{eid}/click", {}); time.sleep(1.5)
    cur = _enable_value()
    target = "0" if want_off else "1"
    if str(cur) != target:
        tapxy(*NLC_SWITCH_XY); time.sleep(2)
    now = _enable_value()
    print(f"NLC preset={arg} enable_before={cur} enable_after={now}",
          "OK" if str(now) == target else "FAIL")

def nlc_state():
    _kill_prefs()
    if not _open_nlc(): return
    r = _req("GET", f"/session/{sid()}/source")
    src = r.get("value") or ""
    sel = re.findall(r'name="([^"]+)"[^>]*traits="Selected', src)
    print("NLC enable=", _enable_value(), "selected=", sel)


# ─────────── Khoá màn / Mở màn (nhóm case Edge-Interrupt) ───────────
# Máy thật iOS 26: KHÔNG khoá được theo lệnh.
#   • WDA /appium/device/lock  -> "Timed out while waiting until the screen gets locked"
#   • mobile: pressButton 'lock' -> máy chỉ hỗ trợ home/volumeup/volumedown
#   • devicectl -> không có lệnh lock/sleep (chỉ reboot)
# ⟹ Chỉ khoá được bằng CHỜ Auto-Lock. Lệnh Appium KHÔNG reset bộ đếm idle nên
#   vẫn poll trạng thái bình thường trong lúc chờ.
# Mở màn thì WDA /unlock cũng lỗi 500 -> phải tự làm 3 bước (hàm unlock dưới đây).
def _hid_power():
    return _req("POST", f"/session/{sid()}/execute/sync",
                {"script": "mobile: performIoHidEvent",
                 "args": [{"page": 0x0C, "usage": 0x30, "durationSeconds": 0.1}]})

def _swipe_up_unlock():
    body = {"actions":[{"type":"pointer","id":"f1","parameters":{"pointerType":"touch"},
        "actions":[{"type":"pointerMove","duration":0,"x":196,"y":820},
                   {"type":"pointerDown","button":0},
                   {"type":"pointerMove","duration":500,"x":196,"y":200},
                   {"type":"pointerUp","button":0}]}]}
    return _req("POST", f"/session/{sid()}/actions", body)

def is_locked():
    return _req("POST", f"/session/{sid()}/appium/device/is_locked", {}).get("value")

def unlock():
    """Đánh thức + vuốt + nhập passcode. Passcode đọc từ ~/.genius_device.env
    (GENIUS_DEVICE_PASSCODE) — KHÔNG hardcode, KHÔNG để trong repo.

    3 bài học phải giữ nguyên, đổi là hỏng:
      1. Đánh thức bằng `mobile: pressButton home`. HID power (page 0x0C/usage 0x30)
         KHÔNG đánh thức được màn (đo bằng cỡ ảnh screenshot: tắt ~40KB, sáng ~1.7MB).
      2. Phải làm LIỀN MẠCH. Màn ngủ lại sau vài giây, mà mỗi lệnh /source mất vài
         giây → chen 1 lệnh chậm vào giữa là cú vuốt rơi vào màn đã tắt, vuốt không ăn.
      3. BẤM TỪNG PHÍM SỐ KHÔNG ĂN (giống switch trong iOS Settings). Phải gửi thẳng
         text vào SecureTextField 'Passcode field'.
    """
    pin = os.environ.get("GENIUS_DEVICE_PASSCODE")
    if not pin:
        env = os.path.expanduser("~/.genius_device.env")
        if os.path.exists(env):
            for line in open(env):
                if line.startswith("GENIUS_DEVICE_PASSCODE="):
                    pin = line.split("=", 1)[1].strip()
    if not pin:
        print("UNLOCK_FAIL thiếu GENIUS_DEVICE_PASSCODE (~/.genius_device.env)"); return
    if not is_locked():
        print("UNLOCK already unlocked"); return
    for attempt in (1, 2, 3):
        _req("POST", f"/session/{sid()}/execute/sync",
             {"script": "mobile: pressButton", "args": [{"name": "home"}]}, timeout=30)
        time.sleep(1.0)
        _swipe_up_unlock()
        time.sleep(1.2)
        eid = _find("Passcode field")
        if eid:
            _req("POST", f"/session/{sid()}/element/{eid}/click", {}, timeout=30)
            _req("POST", f"/session/{sid()}/element/{eid}/value", {"text": pin}, timeout=30)
            time.sleep(3)
            if not is_locked():
                print(f"UNLOCK OK (lần {attempt})"); return
        print(f"  ... lần {attempt} chưa được, thử lại")
    print("UNLOCK_FAIL sau 3 lần")

def autolock(value):
    """Đổi Settings ▸ Display & Brightness ▸ Auto-Lock. value: '30 seconds' | 'Never' | '1 minute'…
    Row 'Display & Brightness' KHÔNG tìm được bằng cuộn danh sách Settings trên iOS 26
    → phải đi qua ô Search."""
    if is_locked(): unlock()
    # Nếu ĐANG ở sẵn màn Auto-Lock thì tap thẳng — đi vòng qua root hay hỏng
    # (Settings giữ nguyên trang cũ, vòng BackButton không về được root).
    src = _req("GET", f"/session/{sid()}/source").get("value") or ""
    if 'XCUIElementTypeNavigationBar type="XCUIElementTypeNavigationBar" name="Auto-Lock"' in src:
        eid = _find(value)
        if eid:
            _req("POST", f"/session/{sid()}/element/{eid}/click", {}); time.sleep(2)
            src = _req("GET", f"/session/{sid()}/source").get("value") or ""
            sel = re.findall(r'label="([^"]{2,25})"[^>]*traits="[^"]*Selected', src)
            print("AUTOLOCK ->", sel, "OK" if value in sel else "FAIL"); return
    _settings_root()
    r = _req("POST", f"/session/{sid()}/elements",
             {"using": "-ios predicate string", "value": "type == 'XCUIElementTypeSearchField'"})
    sf = r.get("value") or []
    if not sf: print("AUTOLOCK_FAIL không thấy ô Search"); return
    i = sf[0].get("ELEMENT") or sf[0].get("element-6066-11e4-a52e-4f735466cecf")
    _req("POST", f"/session/{sid()}/element/{i}/click", {}); time.sleep(1)
    # PHẢI clear trước: ô Search của Settings GIỮ text lần trước, gõ tiếp là nối chuỗi
    # thành "Auto-LockAutoAuto-Lock-Lock" -> "No Results" -> autolock im lặng thất bại.
    _req("POST", f"/session/{sid()}/element/{i}/clear", {}); time.sleep(1.5)
    _req("POST", f"/session/{sid()}/element/{i}/value", {"text": "Auto-Lock"}); time.sleep(3.5)
    # label trong source là "Auto-Lock, Display &amp; Brightness" — dùng chuỗi ĐÃ unescape
    eid = _find("Auto-Lock, Display & Brightness")
    if not eid: print("AUTOLOCK_FAIL không thấy kết quả search"); return
    _req("POST", f"/session/{sid()}/element/{eid}/click", {}); time.sleep(3)
    eid = _find(value)
    if not eid: print("AUTOLOCK_FAIL không thấy mục", value); return
    _req("POST", f"/session/{sid()}/element/{eid}/click", {}); time.sleep(2)
    src = _req("GET", f"/session/{sid()}/source").get("value") or ""
    sel = re.findall(r'label="([^"]{2,25})"[^>]*traits="[^"]*Selected', src)
    print("AUTOLOCK ->", sel, "OK" if value in sel else "FAIL")

def quit():
    print("QUIT", json.dumps(_req("DELETE", f"/session/{sid()}"))[:200])

if __name__ == "__main__":
    c = sys.argv[1]; a = sys.argv[2:]
    {"create": lambda: create(*a), "shot": lambda: shot(a[0]), "source": lambda: source(*a),
     "texts": texts, "tap": lambda: tap(a[0]), "exists": lambda: exists(a[0]),
     "tapxy": lambda: tapxy(a[0], a[1]), "alerttext": alert_text,
     "alert": lambda: alert(a[0]), "activate": lambda: activate(*a), "state": lambda: state(*a),
     "background": lambda: background(a[0]), "terminate": lambda: terminate(*a), "toggle": lambda: toggle_row(a[0], a[1]),
     "nlc": lambda: (nlc(a[0]), activate()), "nlcstate": lambda: (nlc_state(), activate()),
     "unlock": unlock, "islocked": lambda: print("LOCKED", is_locked()),
     "autolock": lambda: (autolock(a[0]), activate()),
     "quit": quit}[c]()
