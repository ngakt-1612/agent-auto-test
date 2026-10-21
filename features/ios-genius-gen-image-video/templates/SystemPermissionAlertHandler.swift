import XCTest

/// Bấm hộ các popup quyền của hệ thống (ATT, notification) trong lúc app khởi động.
///
/// **Vì sao không dùng `addUIInterruptionMonitor`:** monitor chỉ chạy khi test tương tác với app,
/// mà ở đây app đang tự chặn ở splash chờ người trả lời ATT — test không có gì để tương tác nên
/// monitor không bao giờ được gọi. Poll trực tiếp thì chủ động được.
///
/// **Vì sao poll cả springboard và app:** popup quyền do hệ thống dựng nên thường thuộc process
/// `com.apple.springboard`, nhưng tuỳ phiên bản iOS nó có thể xuất hiện trong hierarchy của app.
/// Kiểm cả hai rẻ hơn là đoán sai.
enum SystemPermissionAlertHandler {

    /// Nhãn nút "đồng ý" theo cả tiếng Anh và tiếng Việt. Popup quyền lấy ngôn ngữ của **thiết bị**,
    /// không phải của app, nên khoá locale cho app bằng `-AppleLanguages` KHÔNG đổi được nhãn ở đây.
    private static let acceptLabels = [
        // Popup quyền Photos có nhãn riêng và KHÔNG khớp "Allow" — phải kê đủ, nếu không nó rơi vào
        // nhánh đoán ở dưới. Đặt bản "toàn quyền" lên trước "Limit" vì app cần đọc cả thư viện.
        "Allow Full Access", "Cho phép Toàn quyền Truy cập", "Cho phép toàn quyền truy cập",
        "Allow Access to All Photos", "Cho phép Truy cập Tất cả Ảnh",
        "Allow", "Cho phép",
        "Allow Tracking", "Cho phép Theo dõi", "Cho phép theo dõi",
        "OK", "Đồng ý",
    ]

    /// Nhãn nghĩa là TỪ CHỐI. Không bao giờ bấm nút chứa những từ này, kể cả ở nhánh đoán — bấm
    /// nhầm một lần là quyền bị deny vĩnh viễn, và iOS sẽ không hỏi lại nữa (chỉ Settings đổi được).
    private static let denyMarkers = [
        "Don't Allow", "Don’t Allow", "Không cho phép", "Không Cho Phép",
        "Ask App Not to Track", "Yêu cầu Ứng dụng Không Theo dõi",
        "Limit Access", "Giới hạn Truy cập", "Select Photos", "Chọn Ảnh",
        "Cancel", "Huỷ", "Hủy",
    ]

    /// Chuỗi ở splash bắn 2 popup liên tiếp: ATT (chặn tới khi trả lời) rồi notification.
    /// Chờ tổng cộng đủ lâu cho cả hai, không cần biết cái nào tới trước.
    ///
    /// - Parameters:
    ///   - expected: số popup dự kiến. Thiếu popup không phải lỗi — máy đã trả lời quyền từ lần
    ///     chạy trước thì hệ thống không hỏi lại nữa.
    ///   - timeoutEach: thời gian chờ mỗi popup.
    @discardableResult
    static func acceptAll(expected: Int = 2, timeoutEach: TimeInterval = 25) -> Int {
        var accepted = 0
        for _ in 0..<expected {
            guard let alert = waitForAlert(timeout: timeoutEach) else { break }
            guard tapAccept(in: alert) else { break }
            accepted += 1
        }
        print("🔓 đã bấm \(accepted)/\(expected) popup quyền")
        return accepted
    }

    /// Nhãn các nút trên popup quyền hệ thống đang hiện — dùng khi test cần BIẾT popup nói gì thay vì
    /// chỉ bấm đồng ý (ví dụ đối chiếu với design trong spec).
    ///
    /// Trả mảng rỗng nếu không có popup nào trong `timeout`.
    static func alertLabels(timeout: TimeInterval = 20) -> [String] {
        guard let alert = waitForAlert(timeout: timeout) else { return [] }
        return alert.buttons.allElementsBoundByIndex.map(\.label)
    }

    /// Bấm một nút CỤ THỂ trên popup quyền hệ thống, kể cả nút từ chối.
    ///
    /// `acceptAll` cố tình không bao giờ bấm nút từ chối. Hàm này dành cho case test chính nhánh từ
    /// chối, nên gọi nó là hành động có chủ đích của test — không phải đường tắt của `acceptAll`.
    @discardableResult
    static func tapButton(_ label: String, timeout: TimeInterval = 20) -> Bool {
        guard let alert = waitForAlert(timeout: timeout) else { return false }
        // iOS dùng dấu nháy cong (U+2019) trong nhãn: nhãn thật là `Don’t Allow`, không phải
        // `Don't Allow` ASCII. Tra thẳng theo chuỗi gọi vào sẽ trượt và in cảnh báo sai lệch, dù
        // popup có đúng nút đó — nên so sánh sau khi chuẩn hoá dấu nháy.
        func normalized(_ text: String) -> String {
            text.replacingOccurrences(of: "\u{2019}", with: "'")
        }
        var button = alert.buttons[label]
        if !button.exists {
            let match = alert.buttons.allElementsBoundByIndex.first {
                normalized($0.label).caseInsensitiveCompare(normalized(label)) == .orderedSame
            }
            if let match { button = match }
        }
        guard button.exists, button.isHittable else {
            print("   ⚠️ popup không có nút \"\(label)\"; đang có: \(alert.buttons.allElementsBoundByIndex.map(\.label))")
            return false
        }
        button.tap()
        print("   → bấm \"\(label)\" trên popup hệ thống")
        return true
    }

    // MARK: - Private

    private static func waitForAlert(timeout: TimeInterval) -> XCUIElement? {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let app = XCUIApplication()
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if springboard.alerts.firstMatch.exists { return springboard.alerts.firstMatch }
            // Chỉ hỏi tới alert TRONG app khi app đang ở foreground. Lúc app vừa bị iOS kill (đổi
            // quyền trong Settings) hay đang chuyển process, query nó THROW
            // ("Error getting main window kAXErrorServerNotFound") và cú throw dừng cả test.
            if app.state == .runningForeground, app.alerts.firstMatch.exists {
                return app.alerts.firstMatch
            }
            // Không dùng `waitForExistence` cho từng candidate: nó ăn hết timeout ở candidate đầu
            // rồi mới thử cái sau. Vòng ngắn thì cả hai đều được kiểm trong mỗi nhịp.
            _ = springboard.alerts.firstMatch.waitForExistence(timeout: 1)
        }
        return nil
    }

    /// Ưu tiên nhãn "đồng ý" đã biết; không khớp nhãn nào thì bấm nút **cuối** — cả popup ATT và
    /// popup notification đều đặt lựa chọn đồng ý ở cuối, nên đó là phỏng đoán an toàn nhất khi
    /// thiết bị chạy ngôn ngữ ngoài danh sách trên.
    private static func tapAccept(in alert: XCUIElement) -> Bool {
        let labels = alert.buttons.allElementsBoundByIndex.map(\.label)
        print("🔔 popup quyền: \(labels)")

        for label in acceptLabels {
            let button = alert.buttons[label]
            if button.exists, button.isHittable {
                button.tap()
                print("   → bấm \"\(label)\"")
                return true
            }
        }

        // Không khớp nhãn nào ⇒ ĐOÁN, nhưng chỉ trong phạm vi an toàn: nút có chứa "allow"/"cho
        // phép" và KHÔNG chứa từ từ-chối nào. Trước đây nhánh này bấm nút cuối vô điều kiện — với
        // popup Photos (`Allow Full Access` / `Limit Access…` / `Don't Allow`) thì nút cuối đúng là
        // `Don't Allow`, tức tự tay deny vĩnh viễn.
        let safe = alert.buttons.allElementsBoundByIndex.first { button in
            let l = button.label.lowercased()
            guard button.exists, button.isHittable else { return false }
            guard !denyMarkers.contains(where: { l.contains($0.lowercased()) }) else { return false }
            return l.contains("allow") || l.contains("cho phép") || l.contains("ok")
        }
        guard let safe else {
            print("   ⚠️ không có nút nào an toàn để bấm — BỎ QUA popup này thay vì đoán bừa")
            return false
        }
        safe.tap()
        print("   → khớp mờ, bấm \"\(safe.label)\"")
        return true
    }
}
