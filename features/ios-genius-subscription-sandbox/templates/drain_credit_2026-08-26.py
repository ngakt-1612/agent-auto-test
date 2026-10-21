#!/usr/bin/env python3
"""
Gen can credit BANG THAO TAC THAT tren may that — khong fake, khong doi response.
Chi Thao chot 26/08/2026: moi case credit chi test bang thao tac that.

Dung: /usr/bin/python3 drain_credit_2026-08-26.py <credit_dich>
  vd: ... 1     -> gen cho toi khi credit = 1 (de chay S2V-E12 truoc khi ve 0)
      ... 0     -> gen tiep ve 0

Ghi log tung vong vao /tmp/genius_drain.log de theo doi.
Tu tao lai session Appium khi chet (state tren may van giu nen khong mat tien do).
"""
import json, urllib.request, urllib.error, time, sys, os, re, base64

BASE = "http://127.0.0.1:4723"
SESS = "/tmp/genius_appium_session.txt"
LOG  = "/tmp/genius_drain.log"
DEV  = "00008120-001A20320282201E"
B    = "aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty"
PREFS= "com.apple.Preferences"
TARGET = int(sys.argv[1]) if len(sys.argv) > 1 else 1
MAX_LOOPS = 200

def log(m):
    line = f"[{time.strftime('%H:%M:%S')}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def sid(): return open(SESS).read().strip()

def req(m, p, b=None, t=120):
    d = json.dumps(b).encode() if b is not None else None
    r = urllib.request.Request(BASE+p, data=d, method=m, headers={"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(r, timeout=t) as x: return json.loads(x.read().decode())
    except urllib.error.HTTPError as e: return {"HTTP": e.code, "body": e.read().decode()[:200]}
    except Exception as e: return {"EXC": repr(e)[:120]}

def new_session(with_bundle=True):
    caps = {"platformName":"iOS","appium:automationName":"XCUITest","appium:udid":DEV,
            "appium:usePrebuiltWDA":False,"appium:xcodeOrgId":"KS4Z2R52B4",
            "appium:xcodeSigningId":"Apple Development","appium:updatedWDABundleId":"com.apero.wda",
            "appium:noReset":True,"appium:newCommandTimeout":1800,
            "appium:wdaLaunchTimeout":420000,"appium:wdaConnectionTimeout":420000,
            "appium:waitForQuiescence":False}
    if with_bundle: caps["appium:bundleId"] = B
    r = req("POST","/session",{"capabilities":{"alwaysMatch":caps,"firstMatch":[{}]}}, t=600)
    v = r.get("value")
    if isinstance(v, dict) and v.get("sessionId"):
        open(SESS,"w").write(v["sessionId"]); log(f"  session moi OK"); return True
    log(f"  session FAIL {json.dumps(r)[:160]}"); return False

def alive():
    return isinstance(req("POST",f"/session/{sid()}/appium/device/app_state",{"bundleId":B},t=40).get("value"), int)

def ensure_session():
    """Session chet -> tao lai. May khoa -> tao session KHONG bundleId roi unlock (chicken-egg)."""
    try:
        if alive(): return True
    except Exception: pass
    log("  session chet, dang tao lai...")
    if new_session(True): return True
    log("  thu tao session khong kem bundleId (co the may dang khoa)")
    if new_session(False):
        unlock(); time.sleep(2)
        req("POST",f"/session/{sid()}/appium/device/activate_app",{"bundleId":B}); time.sleep(6)
        return True
    return False

def find(lbl, contains=False):
    v = f"label CONTAINS '{lbl}'" if contains else f"name == '{lbl}' OR label == '{lbl}'"
    for using, val in [("accessibility id", lbl), ("-ios predicate string", v)]:
        r = req("POST",f"/session/{sid()}/element",{"using":using,"value":val}, t=60)
        el = r.get("value")
        if isinstance(el, dict):
            e = el.get("ELEMENT") or el.get("element-6066-11e4-a52e-4f735466cecf")
            if e: return e
    return None

def tap(lbl):
    e = find(lbl)
    if not e: return False
    req("POST",f"/session/{sid()}/element/{e}/click",{}, t=60); return True

def tapxy(x, y):
    req("POST",f"/session/{sid()}/actions",{"actions":[{"type":"pointer","id":"f","parameters":{"pointerType":"touch"},
      "actions":[{"type":"pointerMove","duration":0,"x":int(x),"y":int(y)},{"type":"pointerDown","button":0},
                 {"type":"pause","duration":80},{"type":"pointerUp","button":0}]}]}, t=60)

def src(): return req("GET",f"/session/{sid()}/source", t=120).get("value") or ""

def is_locked(): return req("POST",f"/session/{sid()}/appium/device/is_locked",{}, t=40).get("value")

def unlock():
    pin=None
    env=os.path.expanduser("~/.genius_device.env")
    if os.path.exists(env):
        for l in open(env):
            if l.startswith("GENIUS_DEVICE_PASSCODE="): pin=l.split("=",1)[1].strip()
    if not pin or not is_locked(): return
    for _ in range(3):
        req("POST",f"/session/{sid()}/execute/sync",{"script":"mobile: pressButton","args":[{"name":"home"}]}, t=40)
        time.sleep(1)
        req("POST",f"/session/{sid()}/actions",{"actions":[{"type":"pointer","id":"f","parameters":{"pointerType":"touch"},
          "actions":[{"type":"pointerMove","duration":0,"x":196,"y":820},{"type":"pointerDown","button":0},
                     {"type":"pointerMove","duration":500,"x":196,"y":200},{"type":"pointerUp","button":0}]}]}, t=40)
        time.sleep(1.2)
        e=find("Passcode field")
        if e:
            req("POST",f"/session/{sid()}/element/{e}/click",{}, t=40)
            req("POST",f"/session/{sid()}/element/{e}/value",{"text":pin}, t=40); time.sleep(3)
            if not is_locked(): log("  da mo khoa"); return

def credit():
    """Doc credit badge o Home. Badge la StaticText so o goc phai header (x~225..232, y~78)."""
    s = src()
    for m in re.finditer(r'<XCUIElementTypeStaticText[^>]*label="(\d{1,3})"[^>]*x="(\d+)" y="(\d+)"', s):
        n, x, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
        if 200 <= x <= 260 and 60 <= y <= 100: return n
    return None

def goto_home():
    for _ in range(4):
        if find("Edit Now"): return True
        if not (tap("Back") or tap("Close") or tap("Home")): break
        time.sleep(3)
    return bool(find("Edit Now"))

def one_gen(i):
    """1 vong gen that. Tra ve True neu toi duoc [605]."""
    if not goto_home():
        req("POST",f"/session/{sid()}/appium/device/activate_app",{"bundleId":B}, t=60); time.sleep(6)
        tap("Home"); time.sleep(3)
    if not tap("Motion"): log(f"  #{i} khong tap duoc Motion"); return False
    time.sleep(9)
    if not tap("Tap to use"):
        tap("Try Again"); time.sleep(8); tap("Tap to use")
    time.sleep(8)
    if not tap("Gallery"): log(f"  #{i} khong tap duoc Gallery"); return False
    time.sleep(6)
    tapxy(196, 474); time.sleep(7)
    if not find("Close"): log(f"  #{i} anh chua vao 601"); return False
    if not tap("Generate"): log(f"  #{i} khong tap duoc Generate"); return False
    time.sleep(10)
    tapxy(360, 120); time.sleep(6)     # X paywall chung
    tapxy(360, 118); time.sleep(8)     # X paywall Last Chance
    for w in range(40):                # cho toi 10 phut
        time.sleep(15)
        s = src()
        if 'label="Save"' in s and 'label="Regenerate"' in s: return True
        if "Generation Failed" in s: log(f"  #{i} [604] Generation Failed"); return False
    log(f"  #{i} qua 10 phut chua xong"); return False

# ─────────── main ───────────
log(f"=== BAT DAU gen can credit -> muc tieu {TARGET} (thao tac that, khong fake) ===")
if not ensure_session(): log("KHONG tao duoc session, dung."); sys.exit(1)
unlock()
goto_home()
c = credit()
log(f"credit ban dau: {c}")
if c is None: log("khong doc duoc credit, dung."); sys.exit(1)

i = 0
while c is not None and c > TARGET and i < MAX_LOOPS:
    i += 1
    t0 = time.time()
    if not ensure_session(): log("mat session han, dung."); break
    unlock()
    ok = one_gen(i)
    goto_home()
    new = credit()
    dt = int(time.time() - t0)
    log(f"#{i:3d}  gen={'OK ' if ok else 'FAIL'}  credit {c} -> {new}  ({dt}s)  con {(new or 0)-TARGET} lan nua")
    if new is not None and new == c and ok:
        log("  !! CANH BAO: gen thanh cong ma credit KHONG giam — dung lai de bao chi")
        break
    c = new if new is not None else c
log(f"=== KET THUC: credit = {c}, da chay {i} vong ===")
