#!/usr/bin/env python3
"""Ping Discord kênh bot_sub khi auto-test cần chị thao tác tay (mua IAP/Sandbox/Face ID),
và đính report khi xong round.  Theo quy tắc CLAUDE.md: KHÔNG hỏi trong chat rồi ngồi chờ.

Dùng:
  python3 discord_notify_2026-08-24.py ping  "Gói Weekly" "iPhone Tester 2" "đang chờ ở bảng Subscribe của Apple"
  python3 discord_notify_2026-08-24.py file  /duong/dan/report.html "Report Round 2 Seedance2"

Credential đọc từ TesterL3/discord-spec-watcher/.env (DISCORD_BOT_TOKEN, DISCORD_CHANNEL_ID).
Lưu ý: memory `discord-notify-purchase-thao` (webhook + user id) KHÔNG có trên máy t-thao,
nên script gửi qua Bot API thay vì webhook. Muốn @ chị thì set env MENTION_USER_ID.
"""
import json, os, sys, urllib.request, mimetypes, uuid, pathlib

ENV = pathlib.Path("/Users/t-thao/Documents/Documents - Trinh’s MDT/TesterL3/discord-spec-watcher/.env")
CHANNEL_BOT_SUB = "1534806777466458224"   # kênh bot_sub (RUNBOOK mục ③)

def env():
    d = {}
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            d[k.strip()] = v.strip().strip('"').strip("'")
    return d

def api(path, token, data=None, headers=None, method="POST"):
    url = f"https://discord.com/api/v10{path}"
    h = {"Authorization": f"Bot {token}", "User-Agent": "GeniusQA/1.0"}
    h.update(headers or {})
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.status, r.read().decode("utf-8", "replace")[:400]

def send_text(token, channel, content):
    body = json.dumps({"content": content}).encode()
    return api(f"/channels/{channel}/messages", token,
               body, {"Content-Type": "application/json"})

def send_file(token, channel, path, content=""):
    p = pathlib.Path(path)
    # Discord lỗi 400 với tên file có dấu/space (RUNBOOK mục ③) → chuẩn hoá tên
    safe = "".join(c if (c.isalnum() or c in "._-") else "_" for c in p.name)
    ctype = mimetypes.guess_type(p.name)[0] or "application/octet-stream"
    bnd = uuid.uuid4().hex
    parts = [
        f'--{bnd}\r\nContent-Disposition: form-data; name="payload_json"\r\n'
        f'Content-Type: application/json\r\n\r\n{json.dumps({"content": content})}\r\n'.encode(),
        f'--{bnd}\r\nContent-Disposition: form-data; name="files[0]"; filename="{safe}"\r\n'
        f'Content-Type: {ctype}\r\n\r\n'.encode(),
        p.read_bytes(), f'\r\n--{bnd}--\r\n'.encode(),
    ]
    return api(f"/channels/{channel}/messages", token, b"".join(parts),
               {"Content-Type": f"multipart/form-data; boundary={bnd}"})

def main():
    e = env()
    token = e.get("DISCORD_BOT_TOKEN")
    if not token:
        sys.exit("Thiếu DISCORD_BOT_TOKEN trong .env")
    channel = os.environ.get("DISCORD_CHANNEL_ID") or CHANNEL_BOT_SUB
    mention = os.environ.get("MENTION_USER_ID")
    pre = f"<@{mention}> " if mention else ""
    cmd = sys.argv[1] if len(sys.argv) > 1 else "ping"

    if cmd == "ping":
        pkg, device, step = (sys.argv[2:5] + ["?", "?", "?"])[:3]
        msg = (f"{pre}🛒 **Auto-test cần thao tác tay**\n"
               f"• Gói: **{pkg}**\n• Máy: **{device}**\n• Đang chờ ở bước: **{step}**\n"
               f"Máy đã mở SẴN màn paywall và CHỌN SẴN gói — chị chỉ cần bấm «Continue» rồi Subscribe.\n"
               f"Em DỪNG HẲN, không đụng gì vào máy nữa cho tới khi chị nhắn 'xong' "
               f"(luật RUNBOOK 27/08 lần 3 mục ③).")
        print(send_text(token, channel, msg))
    elif cmd == "file":
        path = sys.argv[2]; note = sys.argv[3] if len(sys.argv) > 3 else ""
        print(send_file(token, channel, path, f"{pre}📄 {note}"))
    else:
        sys.exit("cmd phải là 'ping' hoặc 'file'")

if __name__ == "__main__":
    main()
