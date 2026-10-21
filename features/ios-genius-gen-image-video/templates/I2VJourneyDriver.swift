import XCTest

/// Các chặng dùng chung của luồng **Video Generate** (I2V): mở app → Home → style video → màn
/// Upload của I2V.
///
/// Dùng lại `I2IJourneyDriver` cho những chặng KHÔNG phụ thuộc feature (splash → Home, paywall, các
/// tiện ích query an toàn). Chỉ phần **nhận diện màn** là riêng: Home trộn style ảnh, style video và
/// style motion trong cùng một lưới `home-style-card`, và chỉ style `.video` mới dẫn tới I2V
/// (`HomeView.swift` — `case .video: router.navigateToI2VUpload()`).
struct I2VJourneyDriver {

    let app: XCUIApplication
    /// Phần dùng chung với luồng ảnh — không sao chép lại reachHome/onScreen/tap/waitUntil.
    let common: I2IJourneyDriver

    init(app: XCUIApplication) {
        self.app = app
        self.common = I2IJourneyDriver(app: app)
    }

    static func launchApp() -> XCUIApplication { I2IJourneyDriver.launchApp() }

    // MARK: - Mốc nhận biết màn (identifier gắn trong `Features/I2V/**`)

    /// Nút Generate của màn Upload I2V — cũng là mốc "đang ở màn Upload của luồng video".
    var generateButton: XCUIElement { app.buttons["i2v-generate-cta"] }
    var galleryOption: XCUIElement { app.buttons["i2v-gallery-option"] }
    var cameraOption: XCUIElement { app.buttons["i2v-camera-option"] }
    var uploadBackButton: XCUIElement { app.buttons["i2v-upload-back"] }
    var generatingBackButton: XCUIElement { app.buttons["i2v-generating-back"] }
    /// Mốc của màn Upload luồng **ảnh** — dùng để biết đã bấm nhầm style ảnh.
    var i2iGenerateButton: XCUIElement { app.buttons["i2i-generate-cta"] }

    func marker(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
    var generatingScreen: XCUIElement { marker("i2v-generating-screen") }
    var generatingFailed: XCUIElement { marker("i2v-generating-failed") }
    var resultScreen: XCUIElement { marker("i2v-result-screen") }

    // MARK: - Home

    @discardableResult
    func reachHome(timeout: TimeInterval = I2IJourneyDriver.launchTimeout) -> Bool {
        common.reachHome(timeout: timeout)
    }

    /// Vào màn Upload của I2V bằng **card style video** trên Home.
    ///
    /// Card video mang identifier riêng (`home-style-card-video`, gắn ở `CategorySectionView` theo
    /// `styleType == .video`) — trước đó mọi card dùng chung một id nên test bấm mò cả lưới và chỉ
    /// rơi vào style ảnh (đo được 17:52: 11 lượt bấm, lượt nào cũng ra màn Upload I2I).
    ///
    /// Card nằm trong hàng cuộn NGANG nên "không thấy" chưa chắc là "không có": mỗi vòng vừa cuộn
    /// dọc để lộ category khác, vừa vuốt ngang trên hàng đang hiện.
    ///
    /// **Style video nằm ở ĐÁY Home** (khu World Cup): kiểm kê `styleType` đọc từ `element.value`
    /// cho thấy 532 lượt card IMAGE trước khi gặp 4 card VIDEO, và chúng chỉ lộ ra ở **vòng cuộn
    /// thứ 14**. Vì vậy số lượt mặc định phải đủ sâu — 3 lượt như bản đầu là trượt sạch.
    ///
    /// - Returns: `true` nếu đang đứng ở màn Upload của I2V.
    @discardableResult
    func enterVideoUpload(attempts: Int = 20) -> Bool {
        // Khi user đã chạm 1 style, Home mặc định chip "For You" — mục này chỉ có style ảnh.
        // Chuyển sang "Trending" (danh mục đầy đủ, có khu video) trước khi dò.
        let trending = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Trending'")).firstMatch
        if trending.exists, trending.frame.minY < 450 {
            trending.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            _ = common.styleCard.waitForExistence(timeout: 4)
        }
        for attempt in 1...attempts {
            dismissBlockingDialogs()
            // Tra theo MỌI kiểu element, không chỉ `buttons`: card video bọc AVPlayer nên có thể
            // không lộ ra dưới dạng button trong cây accessibility.
            let cards = onScreen(app.descendants(matching: .any).matching(identifier: "home-style-card-video"))
            guard let card = cards.first else {
                // Chưa thấy card video: vuốt ngang hàng đang hiện (card video có thể nằm ngoài mép
                // phải), rồi cuộn dọc để lộ category tiếp theo.
                if let anyCard = onScreen(app.buttons.matching(identifier: "home-style-card")).first {
                    anyCard.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
                        .press(forDuration: 0.05,
                               thenDragTo: anyCard.coordinate(withNormalizedOffset: CGVector(dx: -1.5, dy: 0.5)))
                }
                app.swipeUp()
                _ = common.styleCard.waitForExistence(timeout: 2)
                print("   ↓ chưa thấy card video — vuốt ngang hàng + cuộn Home (lượt \(attempt)/\(attempts))")
                continue
            }
            tap(card)
            print("👉 bấm card style VIDEO ở Home (lượt \(attempt))")

            let landed = waitUntil(timeout: 12) {
                self.generateButton.exists || self.i2iGenerateButton.exists || self.common.paywall.exists
            }
            if generateButton.exists {
                print("ℹ️ đã vào màn Upload của luồng VIDEO (i2v)")
                return true
            }
            if common.paywall.exists {
                print("   ↩︎ style video premium đẩy ra paywall — đóng rồi thử card khác")
                common.dismissPaywall()
                _ = common.styleCard.waitForExistence(timeout: 8)
                continue
            }
            if i2iGenerateButton.exists {
                print("   ⚠️ card mang id video nhưng mở màn Upload ẢNH — lùi ra")
                common.leaveUpload()
                continue
            }
            print("   ⚠️ bấm xong không tới màn nào (landed=\(landed)) — đang ở: \(screenSummary())")
        }
        print("""
               ✗ không vào được Upload I2V sau \(attempts) lượt.
                 Số card video thấy được ở lượt cuối: \(onScreen(app.descendants(matching: .any).matching(identifier: "home-style-card-video")).count)
                 Đang ở: \(screenSummary())
            """)
        return false
    }

    /// Vào màn Upload video bằng đường nào cũng được: ưu tiên **card trên Home** (đúng entry point
    /// spec mô tả), lùi về **deep link** khi CMS không trả style video nào.
    ///
    /// Trả về đường đã dùng để report ghi đúng điều kiện của verdict.
    @discardableResult
    func enterVideoUploadAnyRoute(homeAttempts: Int = 20) -> Bool {
        if enterVideoUpload(attempts: homeAttempts) { return true }
        print("   ↪︎ Home không có card style video — chuyển sang deep link")
        return enterVideoUploadViaDeepLink()
    }

    /// Đường vào thứ hai: **deep link** `geniusopenapp:///i2v` (`DeepLinkHandler.resolve` —
    /// path "i2v" → `.feature(.i2vUpload)`).
    ///
    /// Cần vì CMS của tài khoản/thiết bị này không trả style nào có `styleType == .video` (đo được
    /// 18:1x: 40-44 card trên Home, 0 card video; See All cũng 0) ⇒ **không có entry point video
    /// trên Home để bấm**. Deep link mở thẳng màn Upload I2V nên đo được phần còn lại của luồng.
    ///
    /// Lưu ý khi đọc verdict: case nào spec đòi "từ Home nhấn entry point" thì đường này KHÔNG
    /// thay thế được — nó chỉ dựng tiền đề cho các case phía sau.
    @discardableResult
    func enterVideoUploadViaDeepLink() -> Bool {
        let url = URL(string: "geniusopenapp:///i2v")!
        // `XCUISystem.open` bắn deep link thẳng qua SpringBoard — không phải gõ vào Safari (lượt
        // 18:05 hụt ở đúng chỗ đó: "Neither element nor any descendant has keyboard focus", thanh
        // địa chỉ thu gọn không nhận typeText).
        XCUIDevice.shared.system.open(url)

        // iOS có thể hỏi xác nhận mở app — alert ở tầng springboard.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 6) {
            print("   ⓘ alert mở app: \(alert.label) · nút \(alert.buttons.allElementsBoundByIndex.map(\.label))")
            for name in ["Open", "Mở"] where alert.buttons[name].exists {
                alert.buttons[name].tap()
                break
            }
        }
        guard app.wait(for: .runningForeground, timeout: 30) else {
            print("   ✗ deep link không đưa được app lên foreground")
            return false
        }
        // Splash → Home → push i2vUpload.
        let landed = waitUntil(timeout: 90) { self.generateButton.exists }
        print(landed ? "ℹ️ deep link mở thẳng màn Upload VIDEO"
                     : "   ✗ deep link không tới màn Upload video — đang ở: \(screenSummary())")
        return landed
    }

    /// Đóng những thứ chen ngang che Home: dialog xin đánh giá (Rate Now / Not really) và paywall.
    /// Không đóng thì cú tap rơi vào lớp phủ và test kết luận sai là "bấm card không vào được màn".
    func dismissBlockingDialogs() {
        if common.paywall.exists {
            common.dismissPaywall()
            _ = common.styleCard.waitForExistence(timeout: 5)
        }
        for label in ["Not really", "Not Now", "Maybe later"] {
            let button = app.buttons[label]
            if button.exists, button.isHittable {
                tap(button)
                print("   ✕ đóng dialog chen ngang (\(label))")
                _ = common.styleCard.waitForExistence(timeout: 5)
            }
        }
    }

    // MARK: - Màn Upload

    /// Rời màn Upload I2V về Home. Ưu tiên id gắn cho nút back của header, sau đó tới các nhãn
    /// chung — nút back có thể lộ ra dưới **label** chứ không có identifier.
    func leaveUpload() {
        for candidate in [uploadBackButton] where candidate.exists {
            tap(candidate)
            _ = common.styleCard.waitForExistence(timeout: 10)
            return
        }
        common.leaveUpload()
    }

    /// Số slot ảnh còn trống (layout nhiều ảnh). Layout 1 ảnh trả 0.
    func emptySlotCount() -> Int { common.emptySlotCount() }

    /// Nút Generate đã bấm được chưa — nó tồn tại từ đầu ở trạng thái disabled nên "tồn tại" không
    /// đồng nghĩa "bấm được".
    func isGenerateReady() -> Bool {
        generateButton.exists && generateButton.isEnabled && !generateButton.frame.isEmpty
    }

    /// Mở thư viện ảnh, không cần biết đang ở layout 1 ảnh hay nhiều ảnh.
    @discardableResult
    func openPicker() -> Bool {
        if let gallery = onScreen(app.buttons.matching(identifier: "i2v-gallery-option")).first {
            tap(gallery)
            print("👉 mở Gallery (layout 1 ảnh)")
            return true
        }
        guard let slot = onScreen(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Upload Image"))).first else {
            print("   ⚠️ không thấy chỗ chọn ảnh — đang ở: \(screenSummary())")
            return false
        }
        tap(slot)
        print("👉 mở slot \"\(slot.label)\"")
        // Layout nhiều ảnh đi qua dialog chọn nguồn.
        let gallery = app.buttons["Gallery"]
        guard gallery.waitForExistence(timeout: 8) else { return false }
        if let onScreenGallery = onScreen(app.buttons.matching(identifier: "Gallery")).first {
            tap(onScreenGallery)
            print("   → chọn Gallery trong dialog")
        }
        return true
    }

    /// Bấm nguồn ảnh Camera ở cả hai layout. Layout nhiều ảnh phải mở dialog chọn nguồn trước.
    func tapCameraSource() -> Bool {
        for _ in 1...3 {
            if let camera = onScreen(app.buttons.matching(identifier: "i2v-camera-option")).first {
                tap(camera)
                return true
            }
            if let camera = onScreen(app.buttons.matching(identifier: "Camera")).first {
                tap(camera)
                return true
            }
            if let slot = onScreen(app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Upload Image"))).first {
                tap(slot)
            }
            _ = app.buttons["Camera"].waitForExistence(timeout: 6)
        }
        print("   ⚠️ không thấy nguồn Camera. Đang có: \(screenSummary())")
        return false
    }

    /// Chọn **một** ảnh từ thư viện: mở picker rồi bấm mù tới khi APP nhận được ảnh.
    ///
    /// Mốc "đã nhận" nằm ở phía app (Generate bật, hoặc số slot trống giảm) — PHPicker chạy ngoài
    /// process nên không đọc được gì bên trong nó.
    @discardableResult
    func pickOnePhoto(startingAttempt: Int = 0) -> Bool {
        let emptyBefore = emptySlotCount()
        guard openPicker() else { return false }
        // Quyền Photos còn `notDetermined` thì iOS chặn picker bằng popup hệ thống. Trả lời hộ,
        // nếu không mọi cú bấm toạ độ sau đó rơi vào popup và hàm báo sai là "thư viện không có ảnh".
        SystemPermissionAlertHandler.acceptAll(expected: 1, timeoutEach: 15)
        for offset in 0..<PhotoPickerAutomator.maxAttempts {
            PhotoPickerAutomator.pickPhoto(attempt: startingAttempt + offset, in: app)
            if waitUntil(timeout: 10, {
                self.isGenerateReady() || self.emptySlotCount() < emptyBefore
            }) { return true }
            print("   ↻ ô vừa bấm không phải ảnh — thử ô khác")
        }
        return false
    }

    /// Chọn **đủ số ảnh** style yêu cầu: lặp `pickOnePhoto` tới khi nút Generate bật.
    ///
    /// Style video không phải lúc nào cũng cần 1 ảnh — lượt 11:1x rơi vào style **2 ảnh** nên chọn
    /// một ảnh xong Generate vẫn disabled và cả suite dừng ở "không bắt đầu được lượt gen".
    @discardableResult
    func pickPhotosUntilReady(maxSlots: Int = 4) -> Bool {
        for index in 0..<maxSlots {
            if isGenerateReady() { return true }
            guard pickOnePhoto(startingAttempt: index) else { return false }
        }
        return isGenerateReady()
    }

    /// Bấm Generate rồi chờ màn Loading. `false` khi nút chưa bấm được hoặc không sang Loading.
    @discardableResult
    func startGenerate(timeout: TimeInterval = 20) -> Bool {
        guard isGenerateReady() else {
            print("   ⚠️ nút Generate chưa bấm được — đang ở: \(screenSummary())")
            return false
        }
        tap(generateButton)
        let started = waitUntil(timeout: timeout) {
            self.generatingScreen.exists || self.resultScreen.exists || self.common.paywall.exists
        }
        print(started ? "👉 đã bấm Generate" : "   ⚠️ bấm Generate mà không sang màn nào")
        return started
    }

    /// Kết cục của một lượt gen — phân biệt tường minh để verdict không lẫn "app lỗi" với "hết quota".
    enum GenerateOutcome: String {
        case result, failed, paywall, timeout
    }

    /// Chờ một lượt gen kết thúc. Video render lâu hơn ảnh nên timeout mặc định 7 phút.
    func waitForGenerateOutcome(timeout: TimeInterval = 420) -> GenerateOutcome {
        var outcome = GenerateOutcome.timeout
        _ = waitUntil(timeout: timeout) {
            if self.resultScreen.exists { outcome = .result; return true }
            if self.generatingFailed.exists { outcome = .failed; return true }
            if self.common.paywall.exists { outcome = .paywall; return true }
            return false
        }
        print("ℹ️ lượt gen kết thúc: \(outcome.rawValue)")
        return outcome
    }

    /// Khung video ở màn Result và trạng thái phát đọc được (`playing` / `paused`).
    var resultPlayer: XCUIElement { marker("i2v-result-player") }
    func playbackState() -> String { (resultPlayer.value as? String) ?? "‹không đọc được›" }

    /// Đóng PHPicker bằng cách vuốt xuống. **Bắt buộc gọi trước khi sang case khác**: PHPicker chạy
    /// ngoài process, để mở thì mọi query sau đó throw `kAXErrorServerNotFound` và dừng cả method.
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

    /// Share sheet hệ thống đã mở chưa.
    ///
    /// Nhận bằng **chính các mục của sheet**, dò cả `buttons` lẫn `staticTexts` ở app và springboard.
    /// Chỉ dò ["AirDrop", "Copy", "Options"] là hụt: với file video, hàng đầu của sheet là danh sách
    /// app đích (Mail / Notes / Journal / Drive) và chúng lộ ra dưới dạng **staticText** — đo được
    /// 14:21, suýt ghi nhầm thành bug "Share không mở sheet ở luồng camera".
    func shareSheetIsOpen() -> Bool {
        let markers = ["AirDrop", "Copy", "Options", "Save Video", "Save to Files",
                       "Mail", "Messages", "Notes", "Journal", "Drive", "More"]
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for name in markers {
            if app.buttons[name].exists || app.staticTexts[name].exists { return true }
            if springboard.buttons[name].exists || springboard.staticTexts[name].exists { return true }
        }
        return app.otherElements["ActivityListView"].exists
    }

    /// `true` khi app đang hiện dialog xin quyền Photos **của chính nó** ⇒ quyền đang denied.
    func appIsAskingForPhotoPermission() -> Bool { common.appIsAskingForPhotoPermission() }

    // MARK: - Tiện ích query (uỷ quyền cho driver chung)

    func onScreen(_ query: XCUIElementQuery) -> [XCUIElement] { common.onScreen(query) }
    @discardableResult
    func tap(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool { common.tap(element, timeout: timeout) }
    func screenSummary() -> String { common.screenSummary() }
    func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        common.waitUntil(timeout: timeout, condition)
    }
}
