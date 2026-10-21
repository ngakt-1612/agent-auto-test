import XCTest

/// Các chặng dùng chung của luồng Image Generate: mở app → Home → màn Upload của I2I → chọn ảnh.
///
/// Tách ra vì hai suite cần đúng những bước này: suite gen thật (`I2IGenerateSmokeUITests`) và
/// suite kiểm màn chọn ảnh/quyền (`ImageGenerateUploadUITests`). Mọi assert nằm ở phía test — driver
/// chỉ lái UI và trả về sự thật đo được, để một chỗ hỏng không kéo theo diễn giải sai ở chỗ khác.
struct I2IJourneyDriver {

    let app: XCUIApplication

    /// Splash chờ ATT + notification + remote config trước khi tới Home.
    static let launchTimeout: TimeInterval = 60

    init(app: XCUIApplication) { self.app = app }

    /// Mở app với locale khoá về `en` để nhãn trong app ổn định.
    ///
    /// Nhãn popup quyền của **hệ thống** KHÔNG đổi theo cờ này — nó theo ngôn ngữ thiết bị, nên
    /// `SystemPermissionAlertHandler` phải kê nhãn cả hai thứ tiếng.
    static func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    // MARK: - Home

    var styleCard: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "home-style-card").firstMatch
    }

    var generateButton: XCUIElement { app.buttons["i2i-generate-cta"] }

    /// Nút Retry của trạng thái Home lỗi CMS.
    var retryButton: XCUIElement { app.buttons["Retry"] }

    var paywall: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "paywall-screen").firstMatch
    }

    /// Đi từ splash tới Home, bấm hộ mọi thứ chặn đường.
    ///
    /// Cài lại app xoá container ⇒ `isOnboardingPassed` mất, onboarding hiện lại, và sau nó là chặng
    /// xác thực email rồi paywall. Hàm này đi hết chuỗi đó.
    @discardableResult
    func reachHome(timeout: TimeInterval = launchTimeout) -> Bool {
        // Popup quyền ở splash — máy đã trả lời rồi thì hàm này trả 0, không phải lỗi.
        SystemPermissionAlertHandler.acceptAll(expected: 2)

        let onboardingCta = app.buttons["onboarding-cta"]
        let closeButton = app.buttons["xmark"]
        let deadline = Date().addingTimeInterval(timeout)

        // Query khi app chưa có main window (vừa bị iOS kill do đổi quyền, hoặc đang khởi chạy lại)
        // **throw** `Failed to get matching snapshots: Error getting main window kAXErrorServerNotFound`
        // và cú throw dừng cả test method. Chờ app về foreground trước mỗi vòng thay vì hỏi ngay.
        func appReady() -> Bool {
            app.state == .runningForeground || app.wait(for: .runningForeground, timeout: 5)
        }

        while Date() < deadline, appReady(), !styleCard.exists {
            if onboardingCta.exists, onboardingCta.isHittable {
                onboardingCta.tap()
                print("👉 onboarding CTA")
            } else if paywall.exists {
                dismissPaywall()
            } else if closeButton.exists, closeButton.isHittable {
                closeButton.tap()
                print("👉 đóng màn xác thực email")
            } else if retryButton.exists {
                // Home hiện nút Retry khi CMS trả lỗi (mạng chập). Không bấm thì Home trống style
                // card vĩnh viễn và test báo sai là "không tới được Home".
                tap(retryButton)
                print("👉 bấm Retry ở Home (CMS lỗi)")
                _ = styleCard.waitForExistence(timeout: 8)
            } else if app.tabBars.buttons["Home"].exists, app.tabBars.buttons["Home"].isSelected {
                // 2.9.0: tab For You mở đầu bằng banner / What's new / dải vibes — card ảnh nằm thấp hơn
                // và SwiftUI chưa dựng nó vào cây cho tới khi cuộn tới. Cuộn ngắn rồi dò lại.
                scrollHomeShort()
                print("   ↓ Home chưa có card ảnh trong vùng thấy — cuộn xuống")
            } else if SystemPermissionAlertHandler.acceptAll(expected: 1, timeoutEach: 3) == 0 {
                _ = styleCard.waitForExistence(timeout: 2)
            }
        }
        return styleCard.exists
    }

    /// Nút đóng của paywall RevenueCatUI KHÔNG có identifier và KHÔNG có label (đo được từ
    /// hierarchy: `Button {{324,87},{66,43}}` trơ trọi), nên không query được. Bấm theo toạ độ tương
    /// đối góc trên phải — giòn, nhưng template đến từ dashboard RevenueCat nên không gắn id vào được.
    func dismissPaywall() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.1)).tap()
        print("👉 đóng paywall (bấm theo toạ độ — nút đóng không có id)")
    }

    // MARK: - Vào màn Upload

    /// Bấm style card cho tới khi vào được màn Upload I2I có số slot ảnh nằm trong `slots`.
    ///
    /// Cần khoảng chứ không chỉ mức tối thiểu: suite kiểm màn chọn ảnh cần đúng layout 1 ảnh, còn
    /// suite gen thật cần style 2 ảnh — cùng một hàm phục vụ cả hai.
    ///
    /// - Returns: số slot ảnh của style đã vào, `nil` nếu thử hết `attempts` lượt mà không vào được.
    func enterUpload(slots wanted: ClosedRange<Int> = 1...Int.max, attempts: Int = 14) -> Int? {
        for attempt in 1...attempts {
            // Sub hết hạn ⇒ bấm style premium bị đẩy ra paywall, và paywall KHÔNG che mất card trong
            // hierarchy: card vẫn `exists`, frame vẫn trong cửa sổ, chỉ `isHittable` là false. Không
            // đóng paywall ở đây thì mọi lượt thử sau đều tap vào card bị che, không có gì xảy ra.
            if paywall.exists {
                dismissPaywall()
                _ = styleCard.waitForExistence(timeout: 5)
            }
            var cards = onScreen(app.buttons.matching(identifier: "home-style-card"))
            // Chỉ 4-5 card nằm trong vùng nhìn thấy của Home. Hết một vòng mà chưa gặp style cần thì
            // cuộn xuống để lộ hàng category khác, thay vì bấm lại đúng những card vừa loại.
            if attempt > cards.count, !cards.isEmpty {
                app.swipeUp()
                _ = styleCard.waitForExistence(timeout: 2)
                cards = onScreen(app.buttons.matching(identifier: "home-style-card"))
                print("   ↓ cuộn Home để lộ style khác")
            }
            if cards.isEmpty, app.tabBars.buttons["Home"].exists {
                // 2.9.0: card lớn đầu Home có tâm nằm sau thanh tab nổi, hoặc tab For You mở đầu bằng
                // banner nên card ảnh chưa vào vùng thấy ⇒ cuộn một đoạn ngắn rồi dò lại.
                scrollHomeShort()
                cards = onScreen(app.buttons.matching(identifier: "home-style-card"))
                print("   ↓ cuộn ngắn để card lớn ra khỏi vùng thanh tab (\(cards.count) card bấm được)")
            }
            guard !cards.isEmpty else {
                print("   ⚠️ không có style card nào bấm được — đang ở: \(screenSummary())")
                _ = styleCard.waitForExistence(timeout: 3)
                continue
            }
            // Xoay vòng qua các card thay vì luôn bấm card đầu: card đầu có thể là style video, hoặc
            // style 1 ảnh trong khi đang cần style 2 ảnh.
            tap(cards[(attempt - 1) % cards.count])
            print("👉 bấm style card ở Home (lần \(attempt)/\(cards.count) card bấm được)")

            guard generateButton.waitForExistence(timeout: 12) else {
                print("   ⚠️ chưa vào được Upload — đang ở: \(screenSummary())")
                continue
            }
            // Layout 1 ảnh không có button "Upload Image N" nào ⇒ đếm ra 0, thực chất là 1 slot.
            let slots = max(emptySlotCount(), 1)
            if wanted.contains(slots) {
                print("ℹ️ style này cần \(slots) ảnh")
                return slots
            }
            print("   ↩︎ style cần \(slots) ảnh, cần \(wanted.lowerBound)…\(wanted.upperBound) — thử style khác")
            leaveUpload()
        }
        return nil
    }

    /// Cuộn Home khoảng 1/3 màn — đủ đưa hàng card kế tiếp lên, không trôi qua mất hàng nào.
    func scrollHomeShort() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        _ = styleCard.waitForExistence(timeout: 2)
    }

    /// Rời màn Upload về Home.
    func leaveUpload() {
        // Nút back của màn Upload lộ ra dưới **label** "Back" (đo từ hierarchy thật), không phải
        // identifier `chevron.backward` như các header khác — nên phải thử cả hai trục query, nếu
        // không thì hàm này im lặng không bấm gì và test báo sai là "Back không về được Home".
        let candidates = ["chevron.backward", "xmark", "Back"]
        for name in candidates {
            if let button = onScreen(app.buttons.matching(identifier: name)).first {
                tap(button)
                _ = styleCard.waitForExistence(timeout: 10)
                return
            }
        }
        for name in candidates {
            let button = app.buttons[name]
            if button.exists {
                tap(button)
                _ = styleCard.waitForExistence(timeout: 10)
                return
            }
        }
        print("   ⚠️ không thấy nút back nào ở màn Upload — đang ở: \(screenSummary())")
    }

    // MARK: - Slot ảnh

    /// Đóng PHPicker bằng cách vuốt xuống.
    ///
    /// **Bắt buộc gọi trước khi sang case khác.** PHPicker chạy ngoài process: để nó mở thì mọi query
    /// cây element sau đó throw `Error getting main window kAXErrorServerNotFound` và dừng cả test
    /// method — đó là cách chuỗi quyền chết ở lượt 09:44 sau TC 09.
    @discardableResult
    func dismissPicker(timeout: TimeInterval = 12) -> Bool {
        guard app.state == .runningForeground else { return false }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            .press(forDuration: 0.1,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        let closed = waitUntil(timeout: timeout) { self.generateButton.exists }
        print(closed ? "   ↧ đã đóng picker" : "   ⚠️ vuốt xuống mà picker chưa đóng")
        return closed
    }

    /// Số slot ảnh còn TRỐNG. Slot đã điền không còn là `Button` (`I2IUploadView.swift:204` — nó
    /// thành ảnh + nút X), nên đếm button là đếm đúng slot trống, không cần đọc state của app.
    func emptySlotCount() -> Int {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Upload Image")).count
    }

    /// Nút Generate đã bấm được chưa. `waitForExistence` không dùng được: nút tồn tại từ đầu ở
    /// trạng thái disabled (`isDisabled: !viewModel.isAllImagesSelected`), nên "tồn tại" không có
    /// nghĩa là "bấm được".
    func isGenerateReady() -> Bool {
        generateButton.exists && generateButton.isEnabled && !generateButton.frame.isEmpty
    }

    /// Mở picker cho slot trống kế tiếp, không cần biết đang ở layout nào.
    /// Im lặng khi không có gì bấm được — nghĩa là picker đang mở và che hết UI của app.
    func openPicker() {
        if let gallery = onScreen(app.buttons.matching(identifier: "i2i-gallery-option")).first {
            tap(gallery)
            print("👉 mở Gallery (layout 1 ảnh)")
            return
        }
        guard let slot = onScreen(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Upload Image"))).first else { return }
        tap(slot)
        print("👉 mở slot \"\(slot.label)\"")
        // Layout nhiều ảnh không có card Gallery sẵn — phải qua dialog chọn nguồn.
        let gallery = app.buttons["Gallery"]
        guard gallery.waitForExistence(timeout: 8) else { return }
        if let onScreenGallery = onScreen(app.buttons.matching(identifier: "Gallery")).first {
            tap(onScreenGallery)
            print("   → chọn Gallery trong dialog")
        }
    }

    /// `true` nếu app đang hiện dialog xin quyền Photos CỦA NÓ (`MediaPermissions.swift:120-126`),
    /// tức quyền đang `.denied`/`.restricted`. Nút "Allow Access" của dialog đó chỉ mở Settings hệ
    /// thống nên test không tự vượt qua được.
    func appIsAskingForPhotoPermission() -> Bool {
        app.buttons["Allow Access"].exists || app.buttons["Not Now"].exists
    }

    // MARK: - Tiện ích query

    /// Các element của `query` đang thực sự nằm trong cửa sổ và bấm được — thay cho việc gọi
    /// `isHittable` trực tiếp trên cả tập.
    ///
    /// `isHittable` **throw** chứ không trả `false` khi element không có activation point hợp lệ
    /// ("Activation point invalid and no suggested hit points based on element frame") — card nằm
    /// ngoài vùng nhìn thấy của hàng ngang là ví dụ. Lọc theo frame trước rồi mới hỏi thì an toàn.
    func onScreen(_ query: XCUIElementQuery) -> [XCUIElement] {
        // App có thể đã bị iOS kill giữa lượt test — đổi quyền Photos trong Settings là một trường
        // hợp như vậy. Query một app không chạy thì XCUITest THROW ("Application … is not running")
        // và cú throw đó dừng cả test method, kể cả khi `continueAfterFailure = true`.
        guard app.state == .runningForeground else { return [] }
        let window = app.windows.firstMatch.frame
        let covered = coveredTop()
        return query.allElementsBoundByIndex.filter { element in
            guard element.exists else { return false }
            let frame = element.frame
            guard frame.width > 1, frame.height > 1 else { return false }
            // 2.9.0: thanh tab nổi đè lên nội dung — card có tâm nằm sau thanh tab mà bấm vào tâm là
            // trúng tab (từng mở nhầm Library thay vì màn Upload).
            return window.contains(CGPoint(x: frame.midX, y: frame.midY)) && frame.midY < covered - 8
        }
    }

    /// Mép trên của thanh tab nổi (vùng dưới đó bị che); không có thanh tab thì là đáy cửa sổ.
    func coveredTop() -> CGFloat {
        let window = app.windows.firstMatch.frame
        let bar = app.tabBars.firstMatch
        guard bar.exists, !bar.frame.isEmpty, bar.frame.minY > window.midY else { return window.maxY }
        return bar.frame.minY
    }

    /// Bấm vào tâm element bằng toạ độ.
    ///
    /// **Không dùng `element.tap()` cho element lấy từ `onScreen(_:)`.** Cả `tap()` và `isHittable`
    /// đều tự tính activation point, và với element mà iOS chưa dựng xong layout thì việc đó
    /// **throw** ("Activation point invalid and no suggested hit points based on element frame")
    /// chứ không trả lỗi mềm — cú throw dừng cả test method, kể cả khi
    /// `continueAfterFailure = true`. Đi qua `coordinate` thì không tính activation point.
    /// Trả `false` (không throw) nếu element không còn trên màn — để một bước hỏng không giết
    /// những case sau nó trong cùng method.
    ///
    /// **Vì sao neo toạ độ vào `app` chứ không vào element:** `element.coordinate(...)` chỉ giữ
    /// *tham chiếu*, việc giải quyết element xảy ra **ở thời điểm `.tap()`**. Element biến mất giữa
    /// chừng (toast che, màn đang chuyển) thì cú giải quyết đó THROW "Failed to get matching
    /// snapshot: No matches found" và **dừng cả test method**, kể cả khi
    /// `continueAfterFailure = true` — lượt 23/09 17:25 mất TC 49→57 vì đúng chỗ này ở TC 47.
    /// Chốt `frame` một lần rồi bấm vào toạ độ tuyệt đối: sau đó không truy vấn element lần nào nữa.
    @discardableResult
    func tap(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        let frame = element.frame
        guard frame.width > 0, frame.height > 0 else { return false }
        // Bấm vào tâm phần ĐANG THẤY: phần dưới mép thanh tab nổi bị che, bấm vào đó là trúng tab.
        let visibleBottom = min(frame.maxY, coveredTop() - 4)
        let y = visibleBottom > frame.minY ? (frame.minY + visibleBottom) / 2 : frame.midY
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: y))
            .tap()
        return true
    }

    /// Nhãn/identifier của các nút đang trên màn hình — dữ liệu để biết app đang ở đâu khi một bước
    /// không đi tiếp được.
    func screenSummary() -> String {
        // Cùng lý do như `onScreen(_:)`: app có thể đã bị iOS kill (đổi quyền trong Settings là một
        // trường hợp), và query app không chạy thì THROW chứ không trả rỗng.
        guard app.state == .runningForeground else { return "app không còn chạy (state=\(app.state.rawValue))" }
        let ids = app.buttons.allElementsBoundByIndex.prefix(40).compactMap { button -> String? in
            guard button.exists, !button.frame.isEmpty else { return nil }
            let id = button.identifier
            return id.isEmpty ? (button.label.isEmpty ? nil : "“\(button.label)”") : id
        }
        var seen = Set<String>()
        let unique = ids.filter { seen.insert($0).inserted }
        return unique.isEmpty ? "không có nút nào nhìn thấy được" : unique.joined(separator: ", ")
    }

    /// Poll một điều kiện. Không dùng `Thread.sleep` — nó chặn cả hàng đợi event của XCUITest.
    func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            _ = app.staticTexts["__poll__"].waitForExistence(timeout: 1)
        }
        return condition()
    }
}
