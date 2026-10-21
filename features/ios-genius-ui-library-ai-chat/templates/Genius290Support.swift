import XCTest

/// Helper dùng chung cho các suite 2.9.0 (Update UI + Library).
///
/// Mỗi case in đúng một dòng `VERDICT|<TC ID>|PASS|FAIL|NA|<thực tế đo được>` để script dựng report
/// đọc thẳng từ log — verdict chỉ in sau khi đọc lại giá trị thật, không in sau cú bấm.
enum G290 {

    /// Vào luồng chính: thấy thanh tab là đủ cho suite UI. `reachHome` lo onboarding/paywall/popup,
    /// nhưng nó chờ card style có id — Home nạp CMS chậm thì card về muộn dù app đã ở luồng chính.
    static func reachMain(_ app: XCUIApplication, timeout: TimeInterval = 150) -> Bool {
        let driver = I2IJourneyDriver(app: app)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if driver.reachHome(timeout: 20) { return true }
            if app.tabBars.buttons["Library"].exists { print("🏠 luồng chính (Home chưa nạp xong card)"); return true }
        }
        return app.tabBars.buttons["Library"].exists
    }

    static func verdict(_ id: String, _ status: String, _ actual: String) {
        print("VERDICT|\(id)|\(status)|\(actual.replacingOccurrences(of: "\n", with: " "))")
    }

    static func verdict(_ id: String, pass: Bool, _ actual: String) {
        verdict(id, pass ? "PASS" : "FAIL", actual)
    }

    /// Nhãn các mục trên thanh tab, theo thứ tự trái → phải.
    static func tabLabels(_ app: XCUIApplication) -> [String] {
        app.tabBars.buttons.allElementsBoundByIndex
            .filter { $0.exists && !$0.frame.isEmpty }
            .sorted { $0.frame.minX < $1.frame.minX }
            .map(\.label)
    }

    @discardableResult
    static func openTab(_ app: XCUIApplication, _ label: String) -> Bool {
        let tab = app.tabBars.buttons[label]
        guard tab.waitForExistence(timeout: 5) else { return false }
        tab.tap()
        pause(app, 1.5)
        return true
    }

    /// Chờ không chặn hàng đợi event của XCUITest (không dùng `Thread.sleep`).
    static func pause(_ app: XCUIApplication, _ seconds: TimeInterval) {
        _ = app.staticTexts["__poll__"].waitForExistence(timeout: seconds)
    }

    static func waitUntil(_ app: XCUIApplication, timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            pause(app, 0.5)
        }
        return condition()
    }

    /// Chữ đang nhìn thấy (staticText + button label) — dùng để tìm nội dung theo vùng.
    static func visibleTexts(_ app: XCUIApplication, limit: Int = 120) -> [String] {
        guard app.state == .runningForeground, let root = try? app.snapshot() else { return [] }
        // Đọc từ MỘT snapshot của cây: duyệt theo chỉ số từng element thì màn đổi giữa chừng
        // (khay, % tiến độ) làm element "index N" biến mất và XCUITest đánh lỗi cả test.
        var texts: [String] = [], buttons: [String] = []
        var stack: [XCUIElementSnapshot] = [root]
        while let node = stack.popLast() {
            if !node.frame.isEmpty, !node.label.isEmpty {
                if node.elementType == .staticText, texts.count < limit { texts.append(node.label) }
                if node.elementType == .button, buttons.count < limit { buttons.append(node.label) }
            }
            stack.append(contentsOf: node.children.reversed())
        }
        return texts + buttons
    }

    /// Màu trung bình (0–255) của vùng element trên ảnh chụp màn hình, bỏ pixel gần đen của nền.
    ///
    /// Dùng để kiểm "mục đang chọn tô tím" bằng số đo thay vì mắt; vùng đo khớp đúng frame element.
    static func averageColor(of element: XCUIElement) -> (r: Double, g: Double, b: Double)? {
        let shot = XCUIScreen.main.screenshot().image
        guard let cg = shot.cgImage, element.exists else { return nil }
        let scale = CGFloat(cg.width) / shot.size.width
        let f = element.frame
        let rect = CGRect(x: f.minX * scale, y: f.minY * scale, width: f.width * scale, height: f.height * scale)
            .integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard !rect.isEmpty, let crop = cg.cropping(to: rect) else { return nil }
        let w = crop.width, h = crop.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        for i in stride(from: 0, to: data.count, by: 4) {
            let pr = Double(data[i]), pg = Double(data[i + 1]), pb = Double(data[i + 2])
            guard pr + pg + pb > 150 else { continue }   // bỏ nền tối, chỉ đo icon + chữ
            r += pr; g += pg; b += pb; n += 1
        }
        guard n > 0 else { return nil }
        return (r / n, g / n, b / n)
    }

    /// Tím = đỏ và lam đều trội hơn lục rõ rệt (tím Genius ~ #C77DFF / #8F53F2).
    static func isPurple(_ c: (r: Double, g: Double, b: Double)) -> Bool {
        c.b - c.g > 30 && c.r - c.g > 20
    }

    /// Tỉ lệ pixel đỏ/hồng (chữ Delete đang bật) trong vùng element.
    static func redFraction(of element: XCUIElement) -> Double {
        colorFraction(of: element) { r, g, b in r - g > 70 && r - b > 30 && r > 150 }
    }

    /// Tỉ lệ pixel thoả `match` trong vùng element trên ảnh chụp màn hình.
    static func colorFraction(of element: XCUIElement, _ match: (Double, Double, Double) -> Bool) -> Double {
        let shot = XCUIScreen.main.screenshot().image
        guard let cg = shot.cgImage, element.exists else { return 0 }
        let scale = CGFloat(cg.width) / shot.size.width
        let f = element.frame
        let rect = CGRect(x: f.minX * scale, y: f.minY * scale, width: f.width * scale, height: f.height * scale)
            .integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard !rect.isEmpty, let crop = cg.cropping(to: rect) else { return 0 }
        let w = crop.width, h = crop.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        var hit = 0, total = 0
        for i in stride(from: 0, to: data.count, by: 4) {
            total += 1
            if match(Double(data[i]), Double(data[i + 1]), Double(data[i + 2])) { hit += 1 }
        }
        return total == 0 ? 0 : Double(hit) / Double(total)
    }

    /// Dấu vân màu thô (lưới 6x6) của một vùng màn hình — so hai ô có phải cùng một kết quả không.
    static func regionSignature(_ rect: CGRect) -> [Double] {
        let shot = XCUIScreen.main.screenshot().image
        guard let cg = shot.cgImage else { return [] }
        let s = CGFloat(cg.width) / shot.size.width
        let r = CGRect(x: rect.minX * s, y: rect.minY * s, width: rect.width * s, height: rect.height * s).integral
        guard let crop = cg.cropping(to: r) else { return [] }
        var data = [UInt8](repeating: 0, count: 6 * 6 * 4)
        guard let ctx = CGContext(data: &data, width: 6, height: 6, bitsPerComponent: 8, bytesPerRow: 24,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: 6, height: 6))
        var out: [Double] = []
        for i in stride(from: 0, to: data.count, by: 4) { out.append(Double(data[i])); out.append(Double(data[i + 1])); out.append(Double(data[i + 2])) }
        return out
    }

    /// Khoảng cách trung bình giữa hai dấu vân (0 = giống hệt). Dưới ~12 coi là cùng ảnh.
    static func signatureDistance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 999 }
        return zip(a, b).map { abs($0 - $1) }.reduce(0, +) / Double(a.count)
    }

    /// Vùng giữa ô thứ `index` của lưới Library 3 cột (né nút ··· và icon play).
    static func libraryCellRect(_ index: Int) -> CGRect {
        let col = index % 3, row = index / 3
        return CGRect(x: 26 + Double(col) * 122, y: 215 + Double(row) * 160, width: 90, height: 70)
    }

    /// Phần tử theo nhãn, chấp cả Button lẫn staticText (nhiều control của Genius là Text + tap gesture).
    static func anyLabeled(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons[label].exists ? app.buttons[label].firstMatch : app.staticTexts[label].firstMatch
    }

    /// Tỉ lệ pixel tím trong vùng element. Đo theo tỉ lệ thay vì trung bình vì viên kính xám của
    /// mục đang chọn chiếm phần lớn vùng và kéo màu trung bình về xám dù icon + chữ tím rõ.
    static func purpleFraction(of element: XCUIElement) -> Double {
        let shot = XCUIScreen.main.screenshot().image
        guard let cg = shot.cgImage, element.exists else { return 0 }
        let scale = CGFloat(cg.width) / shot.size.width
        let f = element.frame
        let rect = CGRect(x: f.minX * scale, y: f.minY * scale, width: f.width * scale, height: f.height * scale)
            .integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard !rect.isEmpty, let crop = cg.cropping(to: rect) else { return 0 }
        let w = crop.width, h = crop.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        var purple = 0, total = 0
        for i in stride(from: 0, to: data.count, by: 4) {
            let r = Double(data[i]), g = Double(data[i + 1]), b = Double(data[i + 2])
            total += 1
            if b - g > 40 && r - g > 30 && r + b > 250 { purple += 1 }
        }
        return total == 0 ? 0 : Double(purple) / Double(total)
    }

    static func describe(_ c: (r: Double, g: Double, b: Double)?) -> String {
        guard let c else { return "không đo được" }
        return String(format: "rgb(%.0f,%.0f,%.0f)", c.r, c.g, c.b)
    }
}
