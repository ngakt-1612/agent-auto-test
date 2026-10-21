import XCTest

/// Lái trạng thái mạng của thiết bị qua app Settings. XCUITest không có API đổi mạng.
///
/// Dùng chung cho mọi suite cần tiền đề offline. Mỗi hàm dưới đây sinh ra từ một lỗi đã mất nhiều
/// lượt chạy mới tìm ra — đọc comment trước khi sửa.
struct SettingsNetworkDriver {

    private enum Label {
        static let airplane = "Airplane Mode"
        static let wifi = "Wi-Fi"
    }

    /// App đang test, lấy lười vì suite gán `app` trong lúc chạy.
    let appUnderTest: () -> XCUIApplication?

    init(_ appUnderTest: @escaping () -> XCUIApplication?) {
        self.appUnderTest = appUnderTest
    }

    /// Đưa máy về trạng thái có mạng — tiền đề của mọi case cần backend.
    @discardableResult
    func ensureOn() -> Bool { setAirplaneMode(false) }

    /// Mở app Settings và **đưa về trang gốc**.
    ///
    /// Cần thiết vì `settings.launch()` mở lại đúng trang mở lần trước, không phải trang gốc: lượt
    /// chạy 19:01 thấy Settings đứng ở trang Photos (do case quyền để lại) nên vừa không thấy dòng
    /// Cellular, vừa query trúng element sai.
    func settingsRoot() -> XCUIApplication? {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.terminate()
        settings.launch()
        guard settings.wait(for: .runningForeground, timeout: 20) else { return nil }

        // Lùi hết các trang con còn mở.
        for _ in 1...6 {
            if settings.switches[Label.airplane].exists { return settings }
            let back = settings.navigationBars.buttons.firstMatch
            guard back.exists, back.isHittable else { break }
            back.tap()
            _ = settings.switches[Label.airplane].waitForExistence(timeout: 3)
        }
        if settings.switches[Label.airplane].exists { return settings }
        print("   ⚠️ không về được trang gốc Settings. Đang hiện: "
              + "\(settings.staticTexts.allElementsBoundByIndex.prefix(8).map(\.label))")
        return nil
    }

    /// Bấm đúng **núm** của một switch trong Settings.
    ///
    /// Element mang label "Airplane Mode" có frame của **cả hàng** (rộng 358), còn UISwitch thật là
    /// một element **không label** nằm ở mép phải (x≈297, rộng 63) — đo được ở lượt chạy 19:13. Nên
    /// `element.tap()` và bấm giữa hàng đều rơi vào vùng chữ, switch không đổi giá trị: 4 lượt bấm,
    /// `value` vẫn `0`. Bấm vào phần bên phải của hàng, hoặc vào chính element switch không label
    /// nếu tìm được.
    static func tapSwitch(_ row: XCUIElement, in settings: XCUIApplication) {
        let knob = settings.switches.allElementsBoundByIndex.first {
            $0.label.isEmpty && row.frame.intersects($0.frame)
        }
        if let knob, knob.frame.width > 1 {
            knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()
        }
    }

    /// Bật/tắt **Network Link Conditioner** với một preset (ví dụ "3G", "Very Bad Network").
    ///
    /// NLC nằm ở `Settings → Developer → Network Link Conditioner`; probe 16:44 xác nhận máy này có
    /// (preset thấy được: 100% Loss, 3G, DSL, Edge, High Latency DNS, LTE, Very Bad Network).
    /// Trả `true` nếu switch Enable đọc lại đúng trạng thái muốn.
    @discardableResult
    func setNetworkLinkConditioner(_ on: Bool, preset: String = "3G") -> Bool {
        guard let settings = settingsRoot() else { return false }
        var developer: XCUIElement?
        for _ in 1...8 {
            let row = settings.staticTexts["Developer"]
            if row.exists { developer = row; break }
            settings.swipeUp()
        }
        guard let developer else {
            print("   ⚠️ không thấy Settings → Developer")
            return false
        }
        developer.tap()
        var nlcRow: XCUIElement?
        for _ in 1...8 {
            let row = settings.staticTexts["Network Link Conditioner"]
            if row.exists { nlcRow = row; break }
            settings.swipeUp()
        }
        guard let nlcRow else {
            print("   ⚠️ không thấy Network Link Conditioner")
            return false
        }
        nlcRow.tap()

        if on {
            // Chọn preset trước rồi mới bật: bật trước thì iOS áp preset đang chọn sẵn.
            let row = settings.staticTexts[preset]
            if row.waitForExistence(timeout: 8) {
                settings.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                    .withOffset(CGVector(dx: settings.frame.midX, dy: row.frame.midY)).tap()
                print("   → chọn preset \(preset)")
            } else {
                print("   ⚠️ không thấy preset \(preset)")
            }
        }
        let toggle = settings.switches.firstMatch
        guard toggle.waitForExistence(timeout: 8) else {
            print("   ⚠️ trang NLC không có switch nào")
            return false
        }
        let want = on ? "1" : "0"
        for _ in 1...3 {
            if (toggle.value as? String) == want {
                print("   ✓ Network Link Conditioner = \(on ? "ON (\(preset))" : "OFF")")
                return true
            }
            Self.tapSwitch(toggle, in: settings)
            _ = settings.staticTexts["__wait__"].waitForExistence(timeout: 1)
        }
        print("   ✗ bấm switch NLC 3 lượt mà value vẫn \(toggle.value ?? "nil")")
        return false
    }

    /// Bật/tắt Wi-Fi qua Settings > Wi-Fi. Trả `true` nếu đọc lại switch đúng trạng thái muốn.
    @discardableResult
    func setWiFi(_ on: Bool, settings passed: XCUIApplication? = nil) -> Bool {
        guard let settings = passed ?? settingsRoot() else { return false }

        var toggle = settings.switches[Label.wifi].firstMatch
        if !toggle.exists {
            // Ở trang gốc, "Wi-Fi" là hàng điều hướng (giá trị là tên mạng), không phải switch.
            let row = settings.staticTexts[Label.wifi].firstMatch
            guard row.exists else {
                print("   ⚠️ không thấy hàng Wi-Fi ở trang gốc Settings")
                return false
            }
            row.tap()
            toggle = settings.switches[Label.wifi].firstMatch
            if !toggle.waitForExistence(timeout: 8) {
                // Switch trên trang Wi-Fi không mang nhãn "Wi-Fi" (đo được lượt 19:40). Trang này chỉ
                // có một switch ở trên cùng — lấy switch có y nhỏ nhất, kèm in ra để lưu vết.
                let all = settings.switches.allElementsBoundByIndex.filter { $0.frame.width > 1 }
                print("   ⓘ switch trên trang Wi-Fi: "
                      + "\(all.prefix(6).map { "\($0.label)=\(($0.value as? String) ?? "?") \($0.frame)" })")
                guard let top = all.min(by: { $0.frame.minY < $1.frame.minY }) else {
                    print("   ⚠️ trang Wi-Fi không có switch nào")
                    return false
                }
                toggle = top
            }
        }

        let want = on ? "1" : "0"
        var applied = (toggle.value as? String) == want
        for attempt in 1...3 where !applied {
            Self.tapSwitch(toggle, in: settings)
            print("   → \(on ? "bật" : "tắt") Wi-Fi (lượt \(attempt))")
            _ = settings.staticTexts["__wait__"].waitForExistence(timeout: 5)
            applied = (toggle.value as? String) == want
        }
        print("   \(applied ? "✓" : "✗") Wi-Fi đang \((toggle.value as? String) == "1" ? "ON" : "OFF")")
        return applied
    }

    /// Bật/tắt Airplane Mode qua app Settings — XCUITest không có API đổi trạng thái mạng.
    ///
    /// **Đọc lại switch sau khi bấm và thử lại tối đa 3 lượt.** TC 33 từng kết luận sai là "bật chế
    /// độ máy bay mà gen vẫn thành công": cú bấm có thể không áp dụng, và hàm cũ không kiểm chứng
    /// nên không phân biệt được "mạng vẫn sống" với "chưa bật được chế độ máy bay".
    @discardableResult
    func setAirplaneMode(_ on: Bool) -> Bool {
        guard let settings = settingsRoot() else {
            appUnderTest()?.activate()
            return false
        }

        let toggle = settings.switches[Label.airplane]
        guard toggle.waitForExistence(timeout: 10) else {
            print("   ⚠️ không thấy switch \"\(Label.airplane)\" ở trang gốc Settings")
            appUnderTest()?.activate()
            return false
        }

        let want = on ? "1" : "0"
        var applied = (toggle.value as? String) == want
        for attempt in 1...3 where !applied {
            Self.tapSwitch(toggle, in: settings)
            print("   → \(on ? "bật" : "tắt") Airplane Mode (lượt \(attempt))")
            // Radio cần vài giây để thực sự lên/xuống; chờ bằng element không bao giờ tồn tại.
            _ = settings.staticTexts["__wait__"].waitForExistence(timeout: 5)
            applied = (toggle.value as? String) == want
        }
        print("   \(applied ? "✓" : "✗") Airplane Mode đang \((toggle.value as? String) == "1" ? "ON" : "OFF")")

        // **Airplane Mode một mình KHÔNG cắt được mạng của máy này.** Probe 0 credit
        // (`test_probeOfflineReallyOffline`) đo được: bật Airplane Mode rồi mở lại app thì Home vẫn
        // tải đủ style card. Lý do: máy đang nối Wi-Fi (hàng Wi-Fi ở Settings có giá trị "Kieu Nga"),
        // và iOS giữ Wi-Fi bật xuyên qua chế độ máy bay khi Wi-Fi từng được bật lại trong lúc đó.
        setWiFi(!on, settings: settings)
        if !applied {
            let switches = settings.switches.allElementsBoundByIndex.prefix(8)
                .map { "\($0.label)=\(($0.value as? String) ?? "?") frame=\($0.frame)" }
            print("   ⓘ chẩn đoán: alerts=\(settings.alerts.allElementsBoundByIndex.map(\.label))"
                  + " switches=\(switches)")
        }

        appUnderTest()?.activate()
        _ = appUnderTest()?.wait(for: .runningForeground, timeout: 20)
        return applied
    }

}

/// Lái quyền Photos của app trong Settings — dùng để dựng tiền đề cho các case cần quyền đã
/// cấp/bị thu hồi mà **không phải gỡ app** (gỡ app xoá luôn entitlement sub đã mua).
struct SettingsPhotosDriver {

    let appUnderTest: () -> XCUIApplication?
    /// Tên app hiện trong Settings.
    let appName: String

    init(appName: String, _ appUnderTest: @escaping () -> XCUIApplication?) {
        self.appName = appName
        self.appUnderTest = appUnderTest
    }

    /// Mở trang cài đặt của app trong Settings — `Settings > Apps > <App>` trên iOS 26.
    ///
    /// **Dùng lại trang đang mở nếu Settings đã ở đó**: nút "Allow Access" trong app mở Settings
    /// thẳng vào trang này, và lượt 18:08 hụt vì hàm cũ luôn `terminate()` rồi tìm lại từ trang gốc
    /// — ô tìm kiếm không trả kết quả nào và cả case TC 09 mất verdict.
    private func openAppPage(_ settings: XCUIApplication) -> Bool {
        if settings.state == .runningForeground, settings.staticTexts["Photos"].exists {
            print("   ⓘ Settings đang ở sẵn trang của app — dùng luôn")
            return true
        }
        settings.terminate()
        settings.launch()
        guard settings.wait(for: .runningForeground, timeout: 20) else { return false }

        // Đi qua danh sách **Apps** trước, không qua ô tìm kiếm của trang gốc: app vừa cài lại
        // chưa vào chỉ mục tìm kiếm của Settings (đo được 18:20: gõ "Genius" ra "No Results for
        // “Genius”" trong khi app vẫn nằm trong danh sách Apps).
        if tapAppsList(settings), openRow(named: appName, in: settings) { return true }

        // Đường lùi: ô tìm kiếm của trang gốc (dùng được khi app đã được lập chỉ mục).
        let search = settings.searchFields.firstMatch
        if search.waitForExistence(timeout: 10), search.isHittable {
            search.tap()
            search.typeText(appName)
            if openRow(named: appName, in: settings) { return true }
        }
        print("""
               ⚠️ không mở được trang cài đặt của app "\(appName)".
                 Settings đang hiện: \(settings.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }.prefix(12))
            """)
        return false
    }

    /// Mở mục "Apps" ở trang gốc Settings (cuộn tới nếu chưa lộ ra).
    private func tapAppsList(_ settings: XCUIApplication) -> Bool {
        for _ in 1...4 {
            let apps = settings.staticTexts["Apps"]
            if apps.exists, apps.isHittable {
                apps.tap()
                // Danh sách Apps có ô tìm kiếm riêng — gõ tên để khỏi cuộn qua hàng trăm app.
                let search = settings.searchFields.firstMatch
                if search.waitForExistence(timeout: 6), search.isHittable {
                    search.tap()
                    search.typeText(appName)
                }
                return true
            }
            settings.swipeUp()
        }
        return false
    }

    /// Bấm hàng app trong danh sách rồi xác nhận đã ở trang của app (có hàng "Photos").
    private func openRow(named name: String, in settings: XCUIApplication) -> Bool {
        let row = settings.cells.containing(.staticText, identifier: name).firstMatch
        if row.waitForExistence(timeout: 8), row.isHittable {
            row.tap()
            return settings.staticTexts["Photos"].waitForExistence(timeout: 10)
        }
        // Hàng có thể lộ ra dưới dạng staticText khi cell không mang nhãn.
        if let text = settings.staticTexts.allElementsBoundByIndex.first(where: { $0.label == name }),
           text.exists {
            text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return settings.staticTexts["Photos"].waitForExistence(timeout: 10)
        }
        return false
    }

    /// Bật/tắt switch **Camera** trên trang cài đặt của app, rồi **đọc lại `value`** để xác nhận —
    /// bấm switch không đồng nghĩa switch đã đổi (đo được ở nhánh Airplane Mode).
    ///
    /// Dùng chung đường điều hướng với `setAccess` thay vì tự dò lại trang app.
    @discardableResult
    func setCameraAccess(_ on: Bool) -> Bool {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        guard openAppPage(settings) else { return false }

        let toggle = settings.switches["Camera"]
        guard toggle.waitForExistence(timeout: 10) else {
            print("""
                   ⚠️ không thấy switch Camera trên trang app.
                     switches: \(settings.switches.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }.prefix(8))
                """)
            return false
        }
        let want = on ? "1" : "0"
        for attempt in 1...3 {
            if (toggle.value as? String) == want {
                print("   ✓ switch Camera = \(want) (sau \(attempt - 1) lượt bấm)")
                return true
            }
            // Bấm đúng **núm** switch: element mang nhãn "Camera" có frame của cả hàng, bấm giữa
            // hàng thì value không đổi (đo được 18:26: 3 lượt bấm, value vẫn 0).
            SettingsNetworkDriver.tapSwitch(toggle, in: settings)
            _ = settings.staticTexts["__wait__"].waitForExistence(timeout: 1)
        }
        print("   ✗ bấm switch Camera 3 lượt mà value vẫn \(toggle.value ?? "nil")")
        return false
    }

    /// Đặt quyền Photos của app thành `level` (`"Full Access"` / `"Limited Access"` / `"None"`).
    ///
    /// Trả `true` nếu trang app đọc lại đúng mức đã chọn. iOS **kill app** khi quyền Photos đổi nên
    /// người gọi phải `launch()` lại — `activate()` không dựng lại được process đã chết.
    @discardableResult
    func setAccess(_ level: String) -> Bool {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        guard openAppPage(settings) else { return false }
        settings.staticTexts["Photos"].tap()

        // In toàn bộ trang lựa chọn quyền: đã hai lượt bấm "Full Access" mà giá trị không đổi, nên
        // cần biết chính xác trang này gồm những element gì thay vì đoán tiếp.
        _ = settings.staticTexts.firstMatch.waitForExistence(timeout: 6)
        print("""
               ⓘ trang quyền Photos:
                 staticTexts: \(settings.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }.prefix(12))
                 cells:       \(settings.cells.count)
                 buttons:     \(settings.buttons.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }.prefix(8))
            """)

        // Lựa chọn trên trang này là **button với nhãn ghép**, không phải cell:
        //   ["Limited Access, Selected photos and add access", "Full Access, 1.114 Photos, 18 Videos"]
        // Nên tra chính xác "Full Access" là trượt — khớp theo **tiền tố nhãn**.
        //
        // "None" là ngoại lệ: nó **không có dòng mô tả** nên iOS không dựng button nhãn ghép cho
        // hàng đó — trên cây chỉ còn `staticText` "None" nằm trong cell. Tra theo trục button sẽ
        // trượt và hàm im lặng trả `false` (đo được 11:33: buttons chỉ có Limited/Full trong khi
        // staticTexts có đủ ["None", "Limited Access", "Full Access"]). Thử button trước, rồi cell.
        let option = settings.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", level)).firstMatch
        // `cells.containing(...)` **throw** khi không khớp ("Failed to get matching snapshot") chứ
        // không trả rỗng, và một cú throw dừng cả test method — nên dò bằng `staticTexts` trực tiếp.
        // Hàng "None" không có dòng mô tả nên không mang identifier lẫn nhãn ghép — mọi cách tra
        // theo subscript/predicate đều **throw** "Failed to get matching snapshot" khi trượt, và một
        // cú throw dừng cả test method. Duyệt mảng đã resolve là cách duy nhất không throw.
        let optionText = settings.staticTexts.allElementsBoundByIndex.first { $0.label == level }
        let target: XCUIElement
        if option.waitForExistence(timeout: 8) {
            target = option
        } else if let optionText {
            target = optionText
        } else {
            print("""
                   ⚠️ không thấy lựa chọn "\(level)" cho Photos.
                     buttons:     \(settings.buttons.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }.prefix(8))
                     staticTexts: \(settings.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }.prefix(12))
                """)
            return false
        }
        // Hàng "None" không có dòng mô tả nên iOS chỉ dựng `staticText` cho nó: bấm vào giữa CHỮ
        // không chọn được (đo được 18:55 và 19:0x — trang app đọc lại vẫn "Full Access"). Bấm vào
        // giữa HÀNG theo toạ độ cửa sổ, cùng cao độ với chữ, thì trúng cell thật.
        let rowPoint = settings.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: settings.frame.midX, dy: target.frame.midY))
        rowPoint.tap()
        print("   → chọn \"\(target.label.isEmpty ? level : target.label)\" (bấm giữa hàng, y=\(Int(target.frame.midY)))")

        // Nâng quyền lên Full Access thì iOS hỏi xác nhận bằng alert **ở tầng springboard**, không
        // phải alert của Settings (đo được: `alerts springboard: ["Give “Genius” full access to your
        // Photo Library?"]`). Không trả lời alert này thì lựa chọn bị bỏ và trang vẫn ở mức cũ.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let confirm = springboard.alerts.firstMatch
        if confirm.waitForExistence(timeout: 6) {
            let labels = confirm.buttons.allElementsBoundByIndex.map(\.label)
            print("   ⓘ alert xác nhận (springboard): \(confirm.label) · nút \(labels)")
            let yes = ["Allow Full Access", "Allow", "Continue", "OK", "Change to Full Access"]
            if let name = yes.first(where: { confirm.buttons[$0].exists }) {
                confirm.buttons[name].tap()
                print("   → bấm \"\(name)\"")
            } else if let last = confirm.buttons.allElementsBoundByIndex.last {
                // Không khớp nhãn nào ⇒ bấm nút khẳng định theo vị trí, và ghi lại để lần sau khớp đúng.
                last.tap()
                print("   → bấm nút cuối \"\(last.label)\" (không khớp nhãn nào trong danh sách)")
            }
        }

        // Trọng tài là **dòng giá trị trên trang app**, không phải trang lựa chọn: lượt 18:55 đọc
        // nhầm chính chỗ này — trang lựa chọn liệt kê đủ cả "None", "Limited Access", "Full Access"
        // nên `onPage.contains(level)` luôn đúng và hàm báo thành công trong khi quyền chưa đổi
        // (`button selected: false`). Dấu nhận biết trang lựa chọn: có dòng mô tả
        // "Selected photos and add access".
        let back = settings.navigationBars.buttons.firstMatch
        if back.exists, back.isHittable { back.tap() }

        var pageTexts: [String] = []
        var onAppPage = false
        for _ in 1...10 {
            pageTexts = settings.staticTexts.allElementsBoundByIndex.map(\.label)
            if pageTexts.contains("Photos"), !pageTexts.contains("Selected photos and add access") {
                onAppPage = true
                break
            }
            if back.exists, back.isHittable { back.tap() }
            _ = settings.staticTexts["__wait__"].waitForExistence(timeout: 1)
        }
        let applied = onAppPage && pageTexts.contains(level)
        print("""
               \(applied ? "✓" : "✗") quyền Photos của app = "\(level)"? (đang ở trang app: \(onAppPage))
                 dòng trên trang app: \(pageTexts.prefix(8))
            """)
        return applied
    }
}
