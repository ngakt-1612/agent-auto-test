#!/usr/bin/env python3
"""Driver Appium tối giản qua HTTP (stdlib) cho máy thật iOS. Lưu sessionId ra /tmp."""
import json, sys, urllib.request, urllib.error, os, base64

BASE = "http://127.0.0.1:4723"
SESS_FILE = "/tmp/genius_appium_session.txt"
DEV = "00008120-001A20320282201E"  # iPhone Tester 2 (14 Pro, iOS 26.4.2) — máy đang test Log out
BUNDLE = "aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty"

def _req(method, path, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"error_http": e.code, "body": e.read().decode()[:800]}

def sid():
    return open(SESS_FILE).read().strip()

def create():
    caps = {"capabilities": {"alwaysMatch": {
        "platformName": "iOS",
        "appium:automationName": "XCUITest",
        "appium:udid": DEV,
        "appium:bundleId": BUNDLE,
        "appium:usePreinstalledWDA": True,
        "appium:updatedWDABundleId": "com.apero.wda",
        "appium:noReset": True,
        "appium:newCommandTimeout": 600,
        "appium:wdaLaunchTimeout": 180000,
        "appium:wdaConnectionTimeout": 180000,
        "appium:waitForQuiescence": False,
    }, "firstMatch": [{}]}}
    r = _req("POST", "/session", caps)
    if "value" in r and isinstance(r["value"], dict) and r["value"].get("sessionId"):
        open(SESS_FILE, "w").write(r["value"]["sessionId"])
        print("SESSION_OK", r["value"]["sessionId"])
    else:
        print("SESSION_FAIL", json.dumps(r)[:1000])

def shot(path):
    r = _req("GET", f"/session/{sid()}/screenshot")
    b64 = r.get("value")
    if b64:
        open(path, "wb").write(base64.b64decode(b64))
        print("SHOT_OK", path)
    else:
        print("SHOT_FAIL", json.dumps(r)[:400])

def source():
    r = _req("GET", f"/session/{sid()}/source")
    print(r.get("value", json.dumps(r))[:4000])

def tap_text(txt):
    # find element by accessibility id or name, then click
    for using, val in [("accessibility id", txt), ("-ios predicate string", f"name == '{txt}' OR label == '{txt}'")]:
        r = _req("POST", f"/session/{sid()}/element", {"using": using, "value": val})
        el = r.get("value", {})
        if isinstance(el, dict) and el.get("ELEMENT" ) or (isinstance(el, dict) and "element-6066-11e4-a52e-4f735466cecf" in el):
            eid = el.get("ELEMENT") or el.get("element-6066-11e4-a52e-4f735466cecf")
            c = _req("POST", f"/session/{sid()}/element/{eid}/click", {})
            print("TAP", txt, "->", "OK" if "value" in c else json.dumps(c)[:200]); return
    print("TAP_NOTFOUND", txt)

def tap_xy(x, y):
    body = {"actions":[{"type":"pointer","id":"finger1","parameters":{"pointerType":"touch"},
        "actions":[{"type":"pointerMove","duration":0,"x":int(x),"y":int(y)},
                   {"type":"pointerDown","button":0},{"type":"pause","duration":80},
                   {"type":"pointerUp","button":0}]}]}
    r = _req("POST", f"/session/{sid()}/actions", body)
    print("TAP_XY", x, y, "OK" if "value" in r else json.dumps(r)[:200])

def swipe(x1,y1,x2,y2,dur=300):
    body = {"actions":[{"type":"pointer","id":"finger1","parameters":{"pointerType":"touch"},
        "actions":[{"type":"pointerMove","duration":0,"x":int(x1),"y":int(y1)},
                   {"type":"pointerDown","button":0},
                   {"type":"pointerMove","duration":int(dur),"x":int(x2),"y":int(y2)},
                   {"type":"pointerUp","button":0}]}]}
    r = _req("POST", f"/session/{sid()}/actions", body)
    print("SWIPE","OK" if "value" in r else json.dumps(r)[:200])

def quit():
    r = _req("DELETE", f"/session/{sid()}")
    print("QUIT", "OK" if "value" in r else json.dumps(r)[:200])

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "create": create()
    elif cmd == "shot": shot(sys.argv[2])
    elif cmd == "source": source()
    elif cmd == "tap": tap_text(sys.argv[2])
    elif cmd == "tapxy": tap_xy(sys.argv[2], sys.argv[3])
    elif cmd == "swipe": swipe(*sys.argv[2:6], dur=int(sys.argv[6]) if len(sys.argv)>6 else 300)
    elif cmd == "quit": quit()
