#!/bin/bash
# Ghi kết quả AIP918 Linguza vào file _ket_qua.xlsx, kèm các verdict sửa tay
# (case mà lượt tự động chấm sai do bộ đo / điều kiện runner - lý do ghi trong từng dòng).
cd "$(dirname "$0")/.." || exit 1
./venv/bin/python .claude/skills/subscription-android-autotest/scripts/fill_touchpoint_matrix_results.py \
 --root apps/linguza --xlsx tc/TC_Subscription_Android_AIP918.xlsx --out tc/TC_Subscription_Android_AIP918_ket_qua.xlsx \
 --touchpoints-from-config config.json --tu-luot 261010-1622-yaml \
 --ghi-tay "SUB_AND_63=PASS:Thoát giữa chừng ads reward không được tính - case 64 chạy ngay sau (12/10 12:13) bắt đầu ở Watch Ad (0/2). Lần chạy tự động đọc nhầm lúc nút Watch Ad đang quay spinner (đã sửa runner)." \
 --ghi-tay "SUB_AND_64=ERROR:Ads reward đã preload trước khi tắt mạng nên vẫn phát được (0/2 -> 1/2) - hành vi hợp lệ. Case cần tắt mạng trước khi app preload ads, hoặc test tay." \
 --ghi-tay "SUB_AND_33=ERROR:Canh giờ - đọc Google Play lúc 14:29 thì gói test đã Expired lúc 14:27 (License Testing hết hạn vài phút sau cancel). Phần app đúng: Settings vẫn hiện Cancel Subscription. Cần chạy lại, đọc Play ngay sau cancel." \
 --ghi-tay "SUB_AND_34=ERROR:Canh giờ - chờ cố định 8 phút, lúc đọc (14:52) Play vẫn Cancelled, hết hạn 14:53. App không crash. Cần chờ theo mốc hết hạn trên Play rồi chạy lại." \
 --ghi-tay "SUB_AND_39=PASS:Phần app đúng - đã cancel chưa hết hạn, Settings vẫn hiện Cancel Subscription. Play ghi status Cancelled nhưng dòng chi tiết chưa cập nhật (vẫn Next payment), lỗi hiển thị phía Play Store." \
 --ghi-tay "SUB_AND_42@pop_up_chat_screen=PASS:Đóng paywall (X và Back) về đúng màn Chat, giữ nội dung đang gõ, bộ đếm lượt hiện 0 (user Free). Pop-up hết lượt không hiện lại sau khi đóng - spec không yêu cầu; FAIL tự động do điều kiện runner tự đặt (đã sửa config)." \
 --ghi-tay "SUB_AND_41@home_badge_pro=N/A:Điểm chạm không có điều kiện user - mọi user Free đều thấy Get Pro trên Home." \
 --ghi-tay "SUB_AND_41@pop_up_chat_screen=PASS:Đo qua case 60 (12/10 11:55) - user Free còn lượt gửi tin 1 và 2 không bung pop-up/paywall; chỉ tin thứ 3 (hết lượt) mới hiện pop-up." \
 --ghi-tay "SUB_AND_57=FAIL:13/10 chạy 2 lần (18:20, 19:17 cài lại app sạch), RC limit_chat_sub_per_day=1. Bộ đếm 1 -> gửi 1 tin -> 0: ô nhập bị khoá (enabled=false), Send/Mic mờ, không pop-up mua sub/reward (đúng) nhưng KHÔNG có thông báo đã dùng hết lượt trong ngày (spec CHAT-13). Ảnh: artifacts/261013-1917-yaml/*.png, artifacts/261013-1820-yaml/kiem-tay/57_* + video." \
 --ghi-tay "SUB_AND_35=PASS:13/10 - máy B Oppo CPH2375 cùng account huỷ Yearly lúc 18:50 (huỷ tay, runner không bấm được vì Play trên Oppo báo bounds 0). Máy A Samsung: Play hiện Cancelled, hết hạn 19:13; app vẫn Pro (Home không có Get Pro, Settings còn Cancel Subscription). Ảnh: artifacts/261013-1838-yaml/kiem-tay/35_*.png." \
 "$@"
./venv/bin/python scripts/them-sheet-diem-cham-paywall.py tc/TC_Subscription_Android_AIP918_ket_qua.xlsx
cp tc/TC_Subscription_Android_AIP918_ket_qua.xlsx ~/Downloads/
