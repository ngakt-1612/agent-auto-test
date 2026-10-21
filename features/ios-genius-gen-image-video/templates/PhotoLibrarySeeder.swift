import XCTest
import Photos
import UIKit

/// Nạp ảnh mẫu vào **thư viện của thiết bị** để dựng tiền đề cho những case phụ thuộc dữ liệu:
/// TC 18 (ảnh quá khổ / ảnh tí hon) và TC 40 (ảnh server từ chối).
///
/// Trước đây hai case này ghi BLOCKED với lý do "cần QA đặt sẵn ảnh". Thực ra **test runner là một
/// app thật**, nên nó tự ghi được ảnh qua `PHAssetCreationRequest` — chỉ cần
/// `NSPhotoLibraryAddUsageDescription` trong Info.plist của target UI test (đã thêm ở
/// `project.pbxproj`).
///
/// Ảnh nạp xong nằm **cuối thư viện** (mới nhất) nên `PhotoPickerAutomator` bấm ô đầu tiên là trúng.
enum PhotoLibrarySeeder {

    /// Xin quyền ghi ảnh cho runner. Trả `true` nếu đủ quyền để nạp.
    @discardableResult
    static func requestAddAccess(timeout: TimeInterval = 20) -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .authorized || status == .limited { return true }

        var granted = false
        let done = XCTestExpectation(description: "photo add access")
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { new in
            granted = (new == .authorized || new == .limited)
            done.fulfill()
        }
        // Popup quyền của **runner** cũng là alert hệ thống — bấm hộ.
        SystemPermissionAlertHandler.acceptAll(expected: 1, timeoutEach: timeout)
        _ = XCTWaiter.wait(for: [done], timeout: timeout)
        print(granted ? "   ✓ runner có quyền ghi ảnh" : "   ✗ runner KHÔNG có quyền ghi ảnh")
        return granted
    }

    /// Ảnh JPEG kích thước `size`, tô gradient + nhiễu nhẹ để file không bị nén xuống quá nhỏ.
    /// Dùng cho ảnh "độ phân giải rất cao" của TC 18.
    static func makeImage(width: Int, height: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            let colors = [UIColor.systemTeal.cgColor, UIColor.systemPink.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(
                    gradient, start: .zero,
                    end: CGPoint(x: width, y: height), options: [])
            }
            // Nhiễu: ép bộ nén giữ dung lượng lớn, tránh JPEG nén ảnh phẳng còn vài trăm KB.
            for _ in 0..<(width * height / 400) {
                let x = CGFloat.random(in: 0..<CGFloat(width))
                let y = CGFloat.random(in: 0..<CGFloat(height))
                UIColor(white: .random(in: 0...1), alpha: 1).setFill()
                ctx.fill(CGRect(x: x, y: y, width: 2, height: 2))
            }
        }
    }

    /// Ghi một ảnh vào thư viện, chờ xong. Trả `true` nếu ghi được.
    @discardableResult
    static func add(_ image: UIImage, label: String, quality: CGFloat = 1.0) -> Bool {
        guard let data = image.jpegData(compressionQuality: quality) else { return false }
        let mb = Double(data.count) / 1_048_576
        var ok = false
        let done = XCTestExpectation(description: "add \(label)")
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        } completionHandler: { success, error in
            ok = success
            if let error { print("   ✗ ghi \(label) lỗi: \(error.localizedDescription)") }
            done.fulfill()
        }
        _ = XCTWaiter.wait(for: [done], timeout: 60)
        print(String(format: "   %@ nạp %@ — %.1f MB, %.0fx%.0f",
                     ok ? "✓" : "✗", label, mb, image.size.width, image.size.height))
        return ok
    }
}
