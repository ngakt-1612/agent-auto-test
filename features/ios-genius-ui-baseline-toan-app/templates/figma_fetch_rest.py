#!/usr/bin/env python3
"""Tải nốt ảnh màn Figma qua REST API — KHÔNG dùng quota MCP.

Token: đặt 1 trong 2 chỗ (đừng dán token vào chat):
  echo 'figd_xxx' > ~/.figma-token     # hoặc
  export FIGMA_TOKEN=figd_xxx
Tạo token: Figma → Settings → Security → Personal access tokens
           (scope tối thiểu: File content = Read)

Chạy:  python3 fetch_rest.py            # tải hết phần còn thiếu
       python3 fetch_rest.py --scale 2  # ảnh nét gấp đôi
"""
import json,os,sys,time,urllib.request,urllib.error,glob

B=os.path.dirname(os.path.abspath(__file__))
FILE_KEY="DVnwame4JHVgijSAdZKEjM"
BATCH=40                     # số id mỗi request /v1/images
SCALE=2 if "--scale" in sys.argv and sys.argv[sys.argv.index("--scale")+1]=="2" else 1

def token():
    t=os.environ.get("FIGMA_TOKEN","").strip()
    if t: return t
    p=os.path.expanduser("~/.figma-token")
    if os.path.exists(p):
        t=open(p).read().strip()
        if t: return t
    sys.exit("THIẾU TOKEN. Làm: echo 'figd_xxx' > ~/.figma-token   (xem docstring)")

TOK=token()

def api(url):
    req=urllib.request.Request(url,headers={"X-Figma-Token":TOK})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req,timeout=120) as r:
                return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            body=e.read().decode()[:300]
            if e.code==429:                      # rate limit → chờ rồi thử lại
                w=(attempt+1)*20; print(f"  429, chờ {w}s…"); time.sleep(w); continue
            sys.exit(f"HTTP {e.code}: {body}")
    sys.exit("thử 4 lần vẫn 429 — dừng")

work=json.load(open(B+"/_worklist.json",encoding='utf-8'))
have={os.path.basename(p) for p in glob.glob(B+"/screen/**/*.png",recursive=True)}
todo=[w for w in work if w["file"] not in have]
print(f"tổng {len(work)} màn · đã có {len(work)-len(todo)} · cần tải {len(todo)}")
if not todo: sys.exit(0)

ok=fail=0
for i in range(0,len(todo),BATCH):
    chunk=todo[i:i+BATCH]
    ids=",".join(w["node_id"] for w in chunk)
    print(f"\n[lô {i//BATCH+1}] xin URL cho {len(chunk)} màn…")
    r=api(f"https://api.figma.com/v1/images/{FILE_KEY}?ids={ids}&format=png&scale={SCALE}")
    if r.get("err"): sys.exit("Figma trả err: "+str(r["err"]))
    imgs=r.get("images",{})
    for w in chunk:
        u=imgs.get(w["node_id"]) or imgs.get(w["node_id"].replace(":","-"))
        if not u: print("  KHÔNG có URL:",w["node_id"],w["name"][:30]); fail+=1; continue
        d=os.path.join(B,"screen",w["dir"]); os.makedirs(d,exist_ok=True)
        p=os.path.join(d,w["file"])
        try:
            with urllib.request.urlopen(u,timeout=180) as resp, open(p,"wb") as f:
                f.write(resp.read())
            if os.path.getsize(p)>500: ok+=1
            else: print("  file rỗng:",w["file"]); fail+=1
        except Exception as e:
            print("  tải lỗi:",w["file"],e); fail+=1
    print(f"  xong lô — OK {ok} · lỗi {fail}")

print(f"\nKẾT QUẢ: tải được {ok} · lỗi {fail}")
mp=B+"/manifest.json"
if os.path.exists(mp):
    m=json.load(open(mp,encoding='utf-8'))
    have2={os.path.basename(p) for p in glob.glob(B+"/screen/**/*.png",recursive=True)}
    left=[w["node_id"] for w in work if w["file"] not in have2]
    m["tang_2_anh"]={"da_tai":len(work)-len(left),"con_thieu":len(left),"tong":len(work)}
    m["con_thieu_node_id"]=left
    m["ngay_tai_rest"]=time.strftime("%Y-%m-%d")
    json.dump(m,open(mp,'w',encoding='utf-8'),ensure_ascii=False,indent=1)
    print("đã cập nhật manifest.json")
