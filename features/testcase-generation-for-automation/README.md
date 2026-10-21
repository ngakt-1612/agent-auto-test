# Sinh testcase cho automation (mọi project)

Tóm tắt cách sinh TC để agent chạy automation được. Luật chung xem thêm `common/working-rules.md` §2.

## Skills dùng
| Skill | Khi nào | Output |
|---|---|---|
| `anthropic-skills:qa-testcase-generator` | Có spec (Confluence/PRD) → sinh TC. Mode **G** = sinh mới từ spec khi chưa có file TC | Excel `.xlsx` feature-first + coverage + Gap/Ambiguity |
| `anthropic-skills:testcase-writer` | Có User Story/AC dạng text + link Google Sheet đích + service account | Ghi thẳng 1 tab Google Sheet (không xuất local) |
| `anthropic-skills:excel-template` | Xuất `tc_list` ra xlsx chuẩn Apero | 10 cột A–J, header locked, dropdown PASS/FAIL/BLOCKED/N/A |
| `anthropic-skills:spec-qa-reviewer` | Review spec trước khi sinh TC / chạy: ambiguity, contradiction, missing behavior, policy ad/sub | Danh sách câu hỏi cần PO/BA confirm |

Spec Confluence: lấy bằng Confluence MCP (`confluence_get_page`), lưu bản markdown vào scratchpad để trích dòng.

## Luật của user cho TC automation
1. **TC phải automatable** — không sinh TC manual; mỗi TC đánh dấu `Auto` hoặc `Auto + setup`. Nhu cầu harness (RC REST API, mitmproxy, StoreKit, snapshot, `page.route`) ghi vào cột ghi chú, không biến thành bước manual.
2. **Không sinh case giả lỗi server / làm chậm server / đổi Remote Config tay** (user bỏ 18/10) — web thì mock bằng `page.route` vẫn được (Genius web).
3. **Chỉ sinh/chạy TC của spec lần này**; plan/TC cũ = công cụ, không phải phạm vi.
4. **Không tự sinh thêm case khi chạy** — sheet có cột `ID`/`N°` mới là case; chỉ được tách case gộp 2 nửa (qa-e2e RUNBOOK #7, #15).
5. **File xlsx của user chỉ để ĐỌC** — kết quả ghi ra file mới (`*_Result_<ts>.xlsx` / `*_ket_qua.xlsx`) (qa-e2e #13).
6. Điểm mơ hồ: đánh `[⚠️ AMBIGUOUS]` ngay trong Expected Result + gom vào sheet Ambiguity/Audit để PO/BA trả lời; không tự đoán.
7. Thứ tự TC trong mỗi feature: **UI → Validate → Logic → Edge Case**; cuối là Regression/E2E.

## Format xlsx đã dùng
| Bộ | Cột / sheet |
|---|---|
| Genius Web (`TC_Genius_Web_Automation*.xlsx`) | 9 cột: N°, Feature (merge), Test Description, Sub-scenario, Precondition, Test Data, Action, Expected Result, PASS/FAIL (+ `Automation` ở v1.3); dòng nhóm `▌ ...`; sheet Summary, Spec Deviations |
| qa-testcase-generator (I2I IIP055.1.5.4, 09/10) | 9 cột A–I, merge chỉ cột B–C, dòng ngăn cách màu theo feature, ô mơ hồ tô vàng; sheet `TC_<feature>`, `Summary` (`=SUM()`), `Ambiguity & Audit` |
| Remote Config (IIP055 v2.9.0, 13/10) | Sheet `TC_RemoteConfig_2.9.0`, `Spec vs Code` (file:line), `Summary` |
| excel-template chuẩn Apero | 10 cột A–J, header locked, dropdown status |

Ví dụ quy mô: I2I 162 TC (10 feature, 21 điểm mơ hồ, 28 TC "chờ confirm"); RC 2.9.0 73 TC / 10 nhóm / 11 điểm lệch spec-code.

## TC Remote Config từ source code (IIP055 Genius iOS 2.9.0)
Quy trình (13/10):
1. Lấy spec (Confluence page RC: bảng Pre-Rollout + mục "Khi nào app dùng giá trị mặc định").
2. Đọc source **đúng version build** (vd `/Users/kieunga/Downloads/IIP055-Genius-IOS-2.9.0`, kiểm `MARKETING_VERSION`). User đổi source giữa chừng → chạy lại toàn bộ đối chiếu trên source mới.
3. Liệt kê key RC từ code (repository RC, giá trị default, kiểu) → so với spec; key chỉ có trong code gắn `[Inferred]`/`[Source-only]`.
4. Nhóm TC theo key: cơ chế chung (default khi chưa fetch, fetch lỗi/timeout, rỗng/sai kiểu, khi nào có hiệu lực) → từng key → tổ hợp/regression.
5. Sheet `Spec vs Code`: mỗi điểm lệch có `file:line` (vd `RemoteConfigRepositoryImpl.swift:147` key bool chưa tạo trên console → code giữ default app, spec coi false; splash chờ RC spec 60s / code 10s `SplashViewModel.swift:228`).
6. Kết luận từ comment phải xác minh bằng code thật; điểm lệch chỉ là "đọc từ code, chưa kiểm trên build thật" cho tới khi chạy.
- Script sinh: `tc_data.py` (TCS + DISCREPANCIES) + `export_tc_xlsx.py <out.xlsx>` trong scratchpad (bị xoá khi hết session — chưa xác minh còn).
- Bẫy: giải nén zip source lớn vào scratchpad → disk full; đọc trực tiếp file liên quan thay vì giải nén cả repo.

## Tổng quan các project đã chạy
Nguồn: buổi tổng hợp nghiên cứu "ứng dụng AI vào automation test" (20/10/2026). Công cụ: Claude Code + skill; iOS: Xcode, XCUITest, xcodebuild, devicectl; Android: adb + Python runner, jadx/dexdump; TC trong Excel, kết quả ghi ngược file; máy thật iPhone 12, Samsung/Pixel/Oppo. Quy trình 5 bước: đọc spec → viết test → chạy máy thật → chấm từ log + ảnh → report; QA giữ 2 cổng (duyệt TC trước chạy, chốt bug sau chạy).

| Bộ | Nền tảng | Số case | Thực hiện | Thời gian máy chạy | Cơ sở số |
|---|---|---|---|---|---|
| I2I – Genius Image Generate | iOS | 51 | 9 đợt, 07→14/09 | **1h24′** / 1 lượt full (~2h15 kể cả cài app + chờ mật khẩu sandbox), ~16 credit | Đo thật, log xcodebuild 10/09 |
| I2V – Genius Video Generate | iOS | 62 | 8 buổi, 17→25/09 (~58 lượt gen) | **~2h** / lượt full, ~15 credit | Ước tính trong plan (không còn log) |
| Magic AI – Sub Android | Android | 55 | 09→10/10 | **7h44′** tổng, 32 lượt; Run_Plan 09/10 = 7h25′ | Log runner `~/magic-ai-sub-e2e/artifacts` |
| AIP918 Linguza – Sub (áp plan Magic AI) | Android | 80 | 10→14/10 (5 ngày) | **9h47′** tổng, 41 lượt; Run_Plan 12/10 = 7h30′ | Log runner `apps/linguza/artifacts` |
| Genius 2.9.0 – Update UI + Library | iOS | 84 | 18→19/10 | **7h08′** tổng, 131 lượt (20 lượt treo/huỷ không tính) | Log xcodebuild `runs/` của plan 2.9.0 |
| Genius Web (bộ này, ngoài slide) | Web Playwright | 35 TC (v1.3) | 21→22/09 | ~3′ cho `-m "not credit"` | results.json 22/09 |

- Tổng (slide): 5 bộ mobile / **332 case**, **22 case FAIL** có ảnh + bước tái hiện; Genius 2.9.0: 74 PASS · 7 FAIL · 3 lệch spec chờ PO (91%).
- Lưu ý cột thời gian lẫn 2 loại: I2I/I2V = 1 lượt full; 3 bộ sau = tổng cả đợt kể cả chạy lại.
- Sub chạy lâu vì phải chờ gia hạn/hết hạn thật (Android test: Weekly/Monthly ~5′, Yearly ~30′; iOS sandbox Weekly ~10′, Monthly ~20′, Yearly ~40′).
- Điểm nhấn: lỗi Billing tìm ở Magic AI thành case tự động và bắt lại đúng lỗi đó trên Linguza.
- Tỉ lệ Pass tính = PASS / (PASS + FAIL).
- Chưa có số giờ test tay tương đương để so tiết kiệm (chưa xác minh).
