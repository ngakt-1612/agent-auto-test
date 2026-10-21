# 17 điểm chạm Paywall — Genius iOS (tra cứu, KHÔNG phải testcase)

Bảng từ sheet «Điểm chạm Paywall» của `Subscription_TestCases_Genius.xlsx` (19/08). Cả 17 điểm = **1 case** (ID 16, cũ C-0 «Các điểm chạm sub»). Không nở thành 17 case (đã sai 28/08: 51→69). % tính trên 17 điểm, không cộng vào % bộ case.

Cách chạy mỗi điểm: chỉ verify «paywall mở ra đúng rồi đóng» — KHÔNG lặp Free→mua→Pro→cancel ở từng điểm, không mua lại. Đóng từng lớp, đọc /source sau mỗi lớp, chụp ảnh.
Tên placement: `iosApp/Features/Paywall/PaywallSource.swift`; key RC: `iosApp/Data/Repositories/RemoteConfig/RemoteConfigKeys.swift`.

| # | Source | Nơi kích hoạt | RC | Đo thật (07–08/09) |
|---|---|---|---|---|
| 1 | home | Nút «Pro» ở Home | — | ✅ 1 lớp |
| 2 | onboarding | Paywall sau Onboarding | — | ✅ fresh install KHÔNG bung paywall — cần PO/BA xác nhận spec |
| 3 | credit | Mua Credit (MyCredit / hết credit) | — | ✅ Setting → My Balance → Get More → [Top-up creations] |
| 4 | lastChance | Paywall «Last Chance» | — | ✅ «🎉 Limited Offer: 50% OFF Today» 199.000đ/week |
| 5 | restore | Restore (phục hồi ảnh) | — | ✅ 3 lớp (Free) |
| 6 | i2i | Image → Image | — | ✅ 3 lớp |
| 7 | removeObject | Remove Object | — | ✅ 3 lớp |
| 8 | enhanceImage | Enhance | — | ✅ 1 lớp, không last-chance |
| 9 | scanResult | Kết quả Scan (Enhance) | — | ✅ 1 lớp, Limited Offer |
| 10 | i2v | Image → Video | showI2VPaywall | ✅ 3 lớp, vào qua category «Future Legend» |
| 11 | seedance | Seedance2 (video) | `enable_seedance_2_feature` (default true) | ⏳ Chờ dev — tab «AI Video» ẩn ⇒ RC thật trả false; check `show_208_seedance2_paywall` |
| 12 | motionControl | Motion Control | — | ✅ 2 lớp |
| 13 | worldCupVideo | World Cup — template Video | showVideoPaywall · `enable_worldcup_tab` (default false) | ⏳ Chờ dev/PO bật tab (ẩn là đúng default) |
| 14 | tryOn | World Cup — Jersey Try On | showTryOnPaywall | ⏳ cùng cờ `enable_worldcup_tab` |
| 15 | wclooks | World Cup — Looks/Makeup | showWcLooksPaywall | ⏳ cùng cờ `enable_worldcup_tab` |
| 16 | topup* | Hết quota tính năng → paywall topup | — | ✅ offer lẻ «Get 1 creation 0.99$» + [Top-up creations] 29.000đ |
| 17 | lastChance* | Offer cơ hội cuối theo tính năng | — | ✅ «Limited Offer 50% OFF» |

Kết quả 08/09: cover 13/17 (76,5%) · Pass/đã chấm 13/13 · 4 Chờ · Blocked 0 · chạy máy 38′35″ (thêm 2h13′ gỡ force-update). 4 điểm còn lại nếu RC bật ước ~10–12′.
Tab bar hiện tại chỉ Home · Tools · Motion · Profile. Không kết luận «key RC chưa tạo» khi chưa đọc được console đúng project `iip055-genius`.
