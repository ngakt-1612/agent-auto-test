# Chạy & báo cáo — Android Sub/Paywall autotest

Mọi lệnh chạy từ `~/magic-ai-sub-e2e`. Đặt `A`/`B` = serial (xem `setup-environment.md`).

## 1. Preflight (mỗi lần mở terminal)
```bash
cd ~/magic-ai-sub-e2e; export PATH=$PATH:~/Library/Android/sdk/platform-tools
export A=R58TB198BNN B=<serial máy B>
for S in $A $B; do adb -s $S shell svc power stayon usb; done
./venv/bin/python -m pytest tests/ -q                     # xanh mới chạy máy
```
Đọc trạng thái account (phải đúng trạng thái bước Run_Plan sắp chạy, thường FREE trước A1) — snippet ở `setup-environment.md` §4.

## 2. Lệnh chạy

**Run_Plan cả app (khuyến nghị)** — tự chờ FREE, tự huỷ, tự mua lại Weekly, ghi xlsx sau mỗi bước:
```bash
./venv/bin/python -u scripts/run_plan_ada903.py $A --serial-b $B --tu-buoc A1 --den-buoc R3     # ADA903
scripts/run-plan-linguza.sh [TÊN_LÔ]          # Linguza: chạy từ lô đó tới hết (C-04, A1 … F2, NA)
```
**Một lô / một case:**
```bash
# ADA903 (config mặc định apps/magic-ai.json, cases/)
./venv/bin/python -u run_yaml.py --serial $A --xlsx tc/TC_Subscription_Android_ADA903_v2.xlsx \
  --diem-cham all --cho-free-phut 60 --cases SUB_AND_44@home_badge_pro,SUB_AND_22
# App khác
./venv/bin/python -u run_yaml.py --app apps/<app>/config.json --xlsx tc/TC_Subscription_Android_<APP>.xlsx \
  --cases-dir apps/<app>/cases --artifacts apps/<app>/artifacts --serial $A [--serial-b $B] \
  [--diem-cham all|p1,p2] [--cho-free-phut 20] --cases SUB_AND_40,SUB_AND_44@pop_up_chat_screen
scripts/run-linguza-cases.sh SUB_AND_33 --cho-free-phut 20        # wrapper Linguza
scripts/run-artspire-cases.sh SUB_AND_18,SUB_AND_57 [--serial-b $B]   # wrapper Artspire (XLSX=~/Downloads/TC_Subscription_Android_aip882.xlsx)
# Chờ Play hết "Server error" rồi chạy tiếp
./venv/bin/python -u scripts/wait_play_then_resume_run_plan.py $A --tu-buoc E5 --den-buoc F2
./venv/bin/python -u scripts/wait_play_then_resume_run_plan.py $A --serial-b $B --cases SUB_AND_35
```
Cờ `run_yaml.py`: `--cases` giữ đúng thứ tự gõ (thứ tự = ràng buộc trạng thái); `SUB_AND_44` = mọi điểm chạm, `SUB_AND_44@x` = 1 bản ·
`--diem-cham all` = mọi placement trong `diem_cham` của config · `--cho-free-phut N` = chờ FREE tối đa N phút thay vì SKIP (bật luôn `--mua-khi-thieu-pro`) ·
`--lap-paywall` = lặp cả case paywall 01–21 theo điểm chạm (khi điểm chạm có biến thể khác) · `--include-blocked` = chạy cả case thiếu điều kiện (ra NOT_EVALUATED) · `--serial-b` = máy thứ hai.

Chạy dài: dùng `run_in_background`, theo dõi log lọc `PASS|FAIL|ERROR|SKIP|BLOCKED|PARTIAL|Traceback`. Không chờ user nhắc — tự chạy tiếp lô sau.
Case 2 máy (35/46 huỷ trên B): chạy ngay sau một lần mua; báo user cắm máy B khi tới. Oppo không bấm được trang Play (bounds 0) → huỷ tay trên B, ghi `--ghi-tay` kèm ảnh.

## 3. Kết quả nằm đâu
| Thứ | Đường dẫn |
|---|---|
| Lượt chạy | `artifacts/<yymmdd-hhmm>-yaml/` (app khác `apps/<app>/artifacts/...`): `results.json` (`{started, cases:[{tc_id,title,verdict,note,luc,evidence[{intent,layer,text,desc,box}],ads_closed,ad_log}]}`), `report.md`, ảnh/dump từng bước |
| Ảnh lỗi | `fail_<case>_*.png` (+ crop node vừa resolve); ảnh bước assert tên bắt đầu `kiem` |
| Kiểm tay | `artifacts/<lượt>/kiem-tay/<case>_*.png` (+ video) |
| File kết quả | `tc/TC_Subscription_Android_<APP>_ket_qua.xlsx` → **copy sang `~/Downloads/`** |
| Quyết định QA | `tc/quyet_dinh_qa.json` |
| Ảnh bằng chứng gốc | `plans/reports/bang-chung-<yymmdd>/` — **giữ cục bộ, không commit** (~15MB/lượt) |
| Bug report | `plans/reports/bug-<yymmdd>-<hhmm>-<app>-<slug>-report.md` (mẫu: `bug-261009-1535-ada903-billing-not-reconnected-after-play-store-restart-report.md`) |
| Handoff | `docs/handoff-<yymmdd>[-app]/00-trang-thai-va-cach-chay-tiep.md` |

## 4. Ghi kết quả vào xlsx
- **Chỉ ghi vào sheet `TC_Subscription_Android`**: cột I PASS/FAIL, M bằng chứng (giờ · quan sát · ảnh), N–Q ảnh từng điểm chạm. **Không ghi Matrix_Touchpoint** (user 09/10). Ngoại lệ 16/10 Linguza: khi user xin bảng điểm chạm, file kết quả có thêm sheet `Diem_cham_Paywall` và Matrix được điền — chỉ trong file `_ket_qua`, không sửa file gốc.
- File kết quả **luôn sinh lại** từ file gốc + toàn bộ lượt chạy. Không sửa tay ô. Muốn đổi: chạy lại case, hoặc `quyet_dinh_qa.json`, hoặc `--ghi-tay`.
- Lượt ERROR không đè kết quả hợp lệ trước đó; chỉ có ERROR/PARTIAL ⇒ ô trống, lý do ở cột ghi chú.
- Case "Mỗi điểm chạm": I gộp (có FAIL → FAIL; đủ placement PASS/N/A → PASS), M một dòng/placement.
```bash
# Sau mỗi bước Run_Plan script tự gọi. Ghi lại thủ công ADA903:
./venv/bin/python -c "import sys; sys.path.insert(0,'scripts'); import run_plan_ada903 as r; r.ghi_ket_qua('<yymmdd>-0000', sys.executable)"
# Linguza (gồm 8+ verdict sửa tay có lý do, thêm sheet điểm chạm, copy ~/Downloads):
scripts/fill-results-linguza.sh [--ghi-tay "SUB_AND_xx=PASS:lý do"]
# Lõi:
./venv/bin/python .claude/skills/subscription-android-autotest/scripts/fill_touchpoint_matrix_results.py \
  --root apps/<app> --xlsx tc/<gốc>.xlsx --out tc/<gốc>_ket_qua.xlsx --touchpoints-from-config config.json \
  --tu-luot <yymmdd-hhmm-yaml> [--cung-ket-qua A=B] [--ghi-tay ID[@placement]=VERDICT:lý do] [--buoc-json ...]
```
`quyet_dinh_qa.json`: `"SUB_AND_xx": {"ket_qua": "PASS|FAIL|N/A", "ghi_de": true, "ly_do": "..."}` — không `ghi_de` chỉ áp khi máy ra PARTIAL; `ghi_de` áp bất kể. Automation chạy lại được thì **xoá** override kiểm tay (tiền lệ 35, 10/10).
FAIL luôn có `ly_do` 2 phần: `LÝ DO FAIL: …` + `BƯỚC TÁI HIỆN: 1) … 2) …` (tay + lệnh adb + log + đối chứng) — user 10/10.

## 5. Bug phát hiện thêm → testcase
Điều kiện: tái hiện ≥2 lần, có ảnh + log, phân biệt với ERROR; chưa rõ đúng/sai spec → hỏi QA/PO trước.
1) Bug report md. 2) Case YAML mới `SUB_AND_<số tiếp>` tái hiện, bug còn ⇒ FAIL (mẫu `templates/case-bug-billing-reconnect-SUB_AND_55.yaml`; verb mới → `tc_runner/dsl/` + unit test).
3) File TC gốc: nhóm `▌ 12. Bug phát hiện khi chạy automation` (merge A:I, copy style dòng trên), J `1 lần`, K bước Run_Plan, L `Auto`; Summary thêm `=COUNT(...)`, dời TOTAL, sửa ô trỏ TOTAL (Run_Plan!B31); thêm vào `BUOC`. 4) Sửa test phạm vi → pytest xanh. 5) Chạy, ghi kết quả. Tính vào **FAIL**.

## 6. Report HTML (artifact)
```bash
./venv/bin/python .claude/skills/subscription-android-autotest/scripts/build_report_html_from_result_xlsx.py \
  --xlsx tc/TC_Subscription_Android_<APP>_ket_qua.xlsx --artifacts <artifacts dir> \
  --notes <html ghi chú lượt này> --app "<Tên> Android (<mã>)" --subtitle "<build · máy A + máy B>" --out <scratchpad>/report.html
```
Mẫu notes: `.claude/skills/subscription-android-autotest/assets/report-notes-example-ada903-261010.html`. Bộ cũ không Run_Plan: `build_qa_sheet_report.py --xlsx ... --notes ... --case-notes <json> --bugs N`.
Định dạng user đã chốt (mẫu "Subscription QA Sheet"):
- Đầu trang: app · Run_Plan · build · máy A/B · file kết quả. KPI: Đã chạy %, **Tỉ lệ pass tính trên tổng**, ô PASS · FAIL · **N/A** (bỏ cột "bug phát hiện thêm" — bug thêm nằm trong FAIL) — user 06/10, 10/10.
- Khung ghi chú: 🐞 từng bug (bảng log thời điểm, gợi ý sửa, link bug report) · ⚠️ tracking · 📝 quyết định QA & môi trường (kỳ gói, Play lỗi).
- **Bảng "Điểm chạm paywall — x/y đã automation test"**: Placement (+ `source`) · Vị trí hiển thị (checklist PO) · Automation (Đã/Chưa/N/A) · Kết quả (số lượt PASS/N/A) · Ghi chú (file:dòng code mở paywall, lý do chưa test). — user 16/10.
- Bảng toàn bộ case **theo thứ tự ID**, spec nguyên văn từ xlsx, kết quả chạy thật bằng lời dễ hiểu, **ảnh cho mọi case kể cả PASS**, cột trạng thái. — user 06/10, 13/10.
- Case N/A/không PASS: ghi rõ **lý do, lỗi ở đâu, cách gỡ**. — user 13–14/10.
- **Bỏ** mục "ngoài phạm vi automation", bỏ mục "Cập nhật ngày …"; thuật ngữ (verdict, PARTIAL…) phải có giải thích nghĩa. — user 06/10.
- Ảnh trong trang dùng bản thu nhỏ nhúng; ảnh gốc giữ local. Muốn số liệu đúng thì chạy lại case, không sửa tay HTML.
- **Publish đè lên link cũ** (giữ URL cho team); lần đầu mới tạo link. Plan/kiến thức chốt thì user muốn bản "đóng gói, không chỉnh sửa".
Link hiện có: ADA903 `https://claude.ai/artifact/17nATzXK6Kh3s7m4vV6vJp` · Linguza `https://claude.ai/artifact/2C2n14ZqehV4KCzX7VwUAj` · Artspire `https://claude.ai/artifact/FDsJXsJfFRpvqAY94zfhyq` · Plan `https://claude.ai/artifact/JDqUyTfxeT9P7cRf92iDF6`.
Script dựng report Linguza bản 6 (143 ảnh) nằm ở scratchpad phiên cũ — có thể đã mất (chưa xác minh); dựng lại bằng `build_report_html_from_result_xlsx.py`.

## 7. Handoff (khi user "lưu tiến trình"/"mai chạy tiếp")
`docs/handoff-<yymmdd>[-app]/00-trang-thai-va-cach-chay-tiep.md` gồm: Đang ở đâu (build, máy A/B serial, file TC/kết quả) · Bảng tổng kết verdict + case · FAIL kèm lý do · Phát hiện mới · Sửa runner (đã/chưa commit) · Việc còn lại (đánh số) · Lệnh chạy lại lô/case chính xác · Câu hỏi chờ PO · Trạng thái account (FREE/ACTIVE, mua lúc mấy giờ) + máy (stayon, crawler, màn hình reset). Cập nhật memory dự án.
Kết lượt: account về trạng thái thống nhất (thường FREE: huỷ + chờ hết kỳ); tắt `stayon` nếu xong; không commit ảnh/APK/secret; commit chỉ khi user bảo.

## 8. Câu hỏi PO đang mở
- ADA903: placement `home` còn dùng? `edit_video` có test? `generate_song` cần dò mức giới hạn lượt nhạc; 41 N/A ở home_badge_pro/select_photo đúng ý QA?
- Linguza: gói chọn sẵn Weekly (app) hay Monthly (ảnh)? Free 2 hay 3 lượt chat/ngày? Sub ~100 vs spec 20 vs "Unlimited"? Sub hết lượt cần thông báo? RC đổi giữa ngày áp dụng hôm sau — đúng thiết kế? Tách source `icon_top_bar`? Khi nào build 2.1.0 (RevenueCat, case 67–77)?
- Artspire: biến thể paywall nào đúng spec? giá Weekly sale $4.99 / Yearly $99.99 vs app?
