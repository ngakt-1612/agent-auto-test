import XCTest

/// Chọn ảnh trong picker hệ thống (PHPicker, do SwiftUI `.photosPicker` dựng) mà không cần người bấm.
///
/// **iOS không cho đọc picker.** `.photosPicker` bọc `PHPickerViewController` và iOS dựng nó trong
/// process khác (`View+GalleryPicker.swift:20-27`, nhánh `.fullAccess`). Trong cây element của app
/// nó chỉ là một remote element rỗng, và XCUITest không lấy được hierarchy của process đó — log đo
/// được: `Ignoring failure to get hierarchy for remote element in process NNNNN (Error getting main
/// window kAXErrorServerNotFound)`. Đây là chủ đích thiết kế: picker ở ngoài process chính để app
/// KHÔNG thấy được thư viện ảnh, nên không có `bundleIdentifier` nào mở được cửa này.
///
/// **Nên bấm theo toạ độ.** Cùng cách test này đang dùng cho nút đóng paywall của RevenueCat: tap
/// đi vào màn hình nên rơi đúng lên picker dù không đọc được nó. Bù lại là bấm mù, nên mỗi cú tap
/// đều phải **kiểm chứng** bằng mốc bên phía app (số slot trống giảm) — việc đó do người gọi làm.
/// Sai ô thì gọi lại với `attempt` tăng dần để thử ô khác.
///
/// Nhánh `.limitedAccess` KHÔNG đi qua đây: đó là grid PhotoKit của chính app
/// (`LimitedLibraryPickerView`) nên nằm ngay trong cây element và bấm được trực tiếp.
enum PhotoPickerAutomator {

    /// Tâm các ô ảnh, chuẩn hoá theo khung app. Lưới PHPicker là 3 cột; các mốc dọc bắt đầu từ hàng
    /// thứ hai trở xuống, tránh vùng trên cùng nơi có tiêu đề, nút Cancel và thanh tìm kiếm — bấm
    /// nhầm vào đó là đóng picker hoặc đổi tab.
    private static let cellCenters: [CGVector] = [
        CGVector(dx: 0.50, dy: 0.42), CGVector(dx: 0.17, dy: 0.42), CGVector(dx: 0.83, dy: 0.42),
        CGVector(dx: 0.50, dy: 0.58), CGVector(dx: 0.17, dy: 0.58), CGVector(dx: 0.83, dy: 0.58),
        CGVector(dx: 0.50, dy: 0.28), CGVector(dx: 0.17, dy: 0.28), CGVector(dx: 0.83, dy: 0.28),
        CGVector(dx: 0.50, dy: 0.72), CGVector(dx: 0.17, dy: 0.72), CGVector(dx: 0.83, dy: 0.72),
    ]

    /// Số ô khác nhau thử được trước khi hết cách.
    static var maxAttempts: Int { cellCenters.count }

    /// Bấm một ô ảnh. `attempt` tăng dần qua các lượt gọi ⇒ mỗi lượt bấm một ô khác, nên vừa là cơ
    /// chế thử lại khi bấm trượt, vừa bảo đảm slot 2 nhận **ảnh khác** slot 1 (style 2 ảnh là "ảnh
    /// mặt + ảnh style", trùng ảnh là test sai luồng).
    ///
    /// - Returns: `true` nếu đã bấm. **Không** khẳng định app nhận được ảnh — người gọi kiểm bằng
    ///   mốc riêng, vì bấm mù thì không có cách nào biết ô vừa bấm có phải ảnh hay không.
    @discardableResult
    static func pickPhoto(attempt: Int, in app: XCUIApplication) -> Bool {
        // Nếu một bản iOS nào đó lại cho đọc picker thì dùng đường đọc được — chính xác hơn bấm mù.
        if let grid = readableGrid(appUnderTest: app) {
            let photos = onScreen(grid.query, in: grid.app)
            if !photos.isEmpty {
                let target = photos[attempt % photos.count]
                target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                print("   👉 chọn ảnh #\(attempt % photos.count)/\(photos.count) (đọc được picker ở \(grid.processName))")
                confirmIfNeeded(in: grid.app)
                return true
            }
        }

        let point = cellCenters[attempt % cellCenters.count]
        app.coordinate(withNormalizedOffset: point).tap()
        print("   👉 bấm ô ảnh theo toạ độ (\(point.dx), \(point.dy)) — lượt \(attempt + 1)/\(maxAttempts)")
        confirmIfNeeded(in: app)
        return true
    }

    /// Chế độ một-ảnh của PHPicker tự đóng khi bấm; chế độ nhiều-ảnh cần bấm xác nhận. Không có nút
    /// nào khớp thì bỏ qua, không coi là lỗi.
    private static func confirmIfNeeded(in app: XCUIApplication) {
        for label in ["Add", "Done", "Chọn", "Xong", "Thêm"] {
            guard let confirm = onScreen(app.buttons.matching(identifier: label), in: app).first
            else { continue }
            confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            print("   👉 bấm \"\(label)\" để xác nhận")
            return
        }
    }

    // MARK: - Đường "đọc được picker" (hiện tại iOS không cho, giữ lại cho bản sau)

    private struct Grid {
        let app: XCUIApplication
        let processName: String
        let query: XCUIElementQuery
    }

    /// Các process từng phục vụ UI của PHPicker.
    private static let candidateBundleIDs = [
        "com.apple.PhotosUIService",
        "com.apple.mobileslideshow",
        "com.apple.PhotosViewService",
    ]

    /// `nil` khi không process nào đọc được — trường hợp bình thường trên iOS hiện tại.
    ///
    /// **Phải kiểm `state` trước khi query bất cứ thứ gì.** Query một app không chạy thì XCUITest
    /// THROW ("Failed to get matching snapshots: Application … is not running"), và với
    /// `continueAfterFailure = false` thì một cú throw dừng cả test.
    private static func readableGrid(appUnderTest: XCUIApplication? = nil) -> Grid? {
        // iOS 26 vẽ PHPicker **trong cây element của chính app** (probe 25/09: đọc được
        // `PXGGridLayout-Info` ở process Genius, còn com.apple.PhotosUIService thì "không chạy").
        // Thử app trước, rồi mới tới các process cũ.
        var sources: [(String, XCUIApplication)] = []
        if let appUnderTest { sources.append(("(app under test)", appUnderTest)) }
        sources += candidateBundleIDs.map { ($0, XCUIApplication(bundleIdentifier: $0)) }

        for (bundleID, app) in sources {
            guard app.state == .runningForeground else { continue }
            let shapes: [(String, XCUIElementQuery)] = [
                ("scrollViews.otherElements.images", app.scrollViews.otherElements.images),
                ("collectionViews.cells", app.collectionViews.cells),
                ("cells", app.cells),
            ]
            for (shape, query) in shapes where query.count > 0 {
                if !onScreen(query, in: app).isEmpty {
                    print("   ℹ️ đọc được picker: \(bundleID) → \(shape)")
                    return Grid(app: app, processName: bundleID, query: query)
                }
            }
            // iOS 26: các ô ảnh là `images` mang nhãn "Photo, <ngày>, <giờ>" nằm ngay trong cây app.
            let dated = app.images.allElementsBoundByIndex.filter {
                $0.exists && !$0.frame.isEmpty && $0.label.hasPrefix("Photo, ")
            }
            if !dated.isEmpty {
                print("   ℹ️ đọc được picker: \(bundleID) → images có nhãn \"Photo, …\" (\(dated.count) ô)")
                return Grid(app: app, processName: bundleID,
                            query: app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo, ")))
            }
        }
        return nil
    }

    /// Các element nằm trong cửa sổ — thay cho `isHittable`, thứ **throw** chứ không trả `false` khi
    /// element không có activation point hợp lệ ("Activation point invalid…"). Lưới ảnh luôn có ô đã
    /// cuộn ra ngoài nên hỏi `isHittable` cả lưới là chắc chắn ăn throw.
    private static func onScreen(_ query: XCUIElementQuery, in app: XCUIApplication) -> [XCUIElement] {
        var window = app.windows.firstMatch.frame
        if window.isEmpty { window = XCUIApplication().windows.firstMatch.frame }
        return query.allElementsBoundByIndex.filter { element in
            guard element.exists else { return false }
            let frame = element.frame
            guard frame.width > 1, frame.height > 1 else { return false }
            return window.isEmpty || window.contains(CGPoint(x: frame.midX, y: frame.midY))
        }
    }
}
