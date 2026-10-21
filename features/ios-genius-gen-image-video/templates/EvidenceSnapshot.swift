import XCTest

/// Chụp màn hình làm **ảnh bằng chứng** cho case FAIL/BLOCKED và đính vào kết quả test.
///
/// Vì sao cần: `.xcresult` mặc định chỉ giữ **bản ghi màn hình** (mp4) + cây accessibility, không có
/// ảnh tĩnh. Muốn ảnh cho report thì phải trích khung hình từ video — chậm và dễ lệch thời điểm.
/// Gọi `snap(...)` ngay tại chỗ khẳng định verdict là có ảnh đúng khoảnh khắc, tên rõ ràng.
///
/// Ảnh đặt `lifetime = .keepAlways` để **không bị xoá khi test PASS** — case PASS cũng cần ảnh khi
/// report muốn minh hoạ hành vi đúng.
extension XCTestCase {

    /// - Parameter name: tên hiển thị trong xcresult, nên đặt dạng `TC 44 — Save không có toast`.
    func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        print("   📸 \(name)")
    }
}
