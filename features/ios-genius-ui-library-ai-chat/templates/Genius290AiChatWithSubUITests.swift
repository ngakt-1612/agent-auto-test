import XCTest
import Photos

/// AI Chat 2.9.0 — nhóm cần gói (mỗi lần gửi trừ 1 lượt, 20 lượt/ngày).
/// Bật bằng `TEST_RUNNER_RUN_G290_CHAT_SUB=1`.
final class Genius290AiChatWithSubUITests: XCTestCase {

    private var app: XCUIApplication!
    private var i2i: I2IJourneyDriver!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_G290_CHAT_SUB"] == "1", "Bật bằng TEST_RUNNER_RUN_G290_CHAT_SUB=1.")
        continueAfterFailure = true
        app = I2IJourneyDriver.launchApp()
        i2i = I2IJourneyDriver(app: app)
        XCTAssertTrue(G290.reachMain(app), "không vào được luồng chính")
    }

    // MARK: - Element + đo dùng chung

    /// Ô nhập đang dùng: khi màn xem 902 mở, ô soạn khung chat vẫn nằm trong cây (bị che) — lấy ô
    /// của màn xem (bắt đầu sát mép trái vì không có nút dấu cộng).
    private var input: XCUIElement {
        let fields = app.textFields.allElementsBoundByIndex.filter { $0.exists }
        if app.tabBars.buttons.count == 0, let v = fields.first(where: { $0.frame.minX < 50 }) { return v }
        return fields.first { $0.frame.minX >= 50 } ?? app.textFields.firstMatch
    }
    private var send: XCUIElement { app.images["arrow.up"].firstMatch }
    private var inputText: String { (input.value as? String) ?? "" }
    private func at(_ f: CGRect) { app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap() }
    private var premium: Bool { !app.buttons["home-upgrade-cta"].exists }

    private func dump(_ tag: String) {
        guard let root = try? app.snapshot() else { return }
        var st: [XCUIElementSnapshot] = [root], n = 0
        while let e = st.popLast() {
            let v = (e.value as? String) ?? ""
            if !e.frame.isEmpty, !(e.label.isEmpty && e.identifier.isEmpty && v.isEmpty), n < 160 {
                n += 1; print("DUMP|\(tag)|\(e.elementType.rawValue)|\(e.label.prefix(60))|\(e.identifier)|\(v.prefix(30))|\(Int(e.frame.minX)),\(Int(e.frame.minY)),\(Int(e.frame.width))x\(Int(e.frame.height))")
            }
            st.append(contentsOf: e.children.reversed())
        }
    }
    private func badge() -> Int? {
        G290.openTab(app, "Home"); app.swipeDown(); G290.pause(app, 2)
        let l = app.buttons.allElementsBoundByIndex.first { $0.exists && $0.frame.minY < 120 && $0.frame.minX > 200 && $0.label.range(of: #"\d+"#, options: .regularExpression) != nil }?.label ?? ""
        return Int(l.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
    }
    private func openChat() { G290.openTab(app, "Chat"); G290.pause(app, 2) }
    /// Đang tạo: còn chữ "Replying…" hoặc biểu tượng lấp lánh của ô đang tạo.
    private var generating: Bool { app.images["sparkles"].exists || G290.visibleTexts(app).contains { $0.hasPrefix("Replying") } }
    private var regenCount: Int { app.staticTexts.matching(NSPredicate(format: "label == 'Regenerate'")).count }
    private var errorShown: Bool { G290.visibleTexts(app).contains { $0.contains("Couldn") || $0.contains("longer than expected") || $0.contains("No internet") } }
    /// Chờ lượt đang chạy xong: số hàng nút tăng, hoặc có lỗi, hoặc hết ô đang tạo.
    private func waitDone(after base: Int, timeout: TimeInterval = 220) -> Bool {
        G290.waitUntil(app, timeout: timeout) { self.regenCount > base || self.errorShown }
    }
    /// Khung các ô kết quả (vùng ảnh ngay trên hàng Save · Share · Regenerate), từ trên xuống.
    private func resultFrames() -> [CGRect] {
        let saves = app.staticTexts.matching(NSPredicate(format: "label == 'Save'")).allElementsBoundByIndex
        var rows: [CGRect] = []
        for e in saves where e.exists {
            let f = e.frame
            if f.minY > 120 && f.minY < 720 { rows.append(f) }
        }
        rows.sort { $0.minY < $1.minY }
        return rows.map { CGRect(x: 24, y: $0.minY - 230, width: 220, height: 200) }
    }
    /// Thanh "Editing this" của khung chat (khi màn xem mở, thanh của khung chat bên dưới không tính).
    private var editingBar: Bool { app.staticTexts["Editing this"].exists && app.tabBars.buttons.count > 0 }
    private var photoCount: Int { PHAsset.fetchAssets(with: nil).count }
    /// Chạm ô nhập tới khi bàn phím mở (con trỏ về cuối chữ); gõ khi chưa có focus thì XCUITest báo lỗi.
    @discardableResult
    private func focus() -> Bool {
        for _ in 0..<4 {
            if app.keyboards.count > 0 && (input.value(forKey: "hasKeyboardFocus") as? Bool ?? false) { return true }
            input.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        }
        return app.keyboards.count > 0
    }
    private func type(_ text: String) { if focus() { input.typeText(text) } }
    private func clearInput() {
        for _ in 0..<10 where !inputText.isEmpty && inputText != "What's on your mind?" {
            guard focus() else { return }
            input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: min(inputText.count + 5, 300)))
        }
    }
    private func dismissKeyboard() { if app.keyboards.count > 0 { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap(); G290.pause(app, 1) } }
    /// Vuốt một kết quả sang phải `dx` điểm rồi thả.
    private func swipeResult(_ f: CGRect, dx: CGFloat) {
        // Giữ 0,5 s rồi kéo chậm: dò trên máy (test13) — kéo nhanh thì app nhận là chạm và mở màn xem.
        let a = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.minX + 50, dy: f.midY))
        a.press(forDuration: 0.5, thenDragTo: a.withOffset(CGVector(dx: dx, dy: 0)), withVelocity: XCUIGestureVelocity(150), thenHoldForDuration: 0.1)
        G290.pause(app, 1.2)
    }
    /// Gửi rồi chờ xong; trả (số hàng nút trước, sau, có lỗi).
    @discardableResult
    private func sendAndWait(_ text: String, timeout: TimeInterval = 220) -> (before: Int, after: Int, error: Bool) {
        let b = regenCount
        clearInput(); type(text)
        at(send.frame)
        _ = waitDone(after: b, timeout: timeout); G290.pause(app, 2)
        return (b, regenCount, errorShown)
    }

    // MARK: - Lượt gửi đầu tiên + dò cây câu trả lời

    func test01_firstSendAndProbe() {
        guard premium else { G290.verdict("TC-CH02-016", "NA", "máy chưa có gói"); return }
        let before = badge()
        openChat()
        if app.buttons["More"].exists, !app.staticTexts["What's on your mind?"].exists {
            app.buttons["More"].tap(); G290.pause(app, 1)
            if app.buttons["New conversation"].exists { app.buttons["New conversation"].tap(); G290.pause(app, 1) }
            if app.buttons["New conversation"].exists { app.buttons["New conversation"].firstMatch.tap(); G290.pause(app, 2) }
        }
        let prompt = "a cat wearing a wizard hat, watercolor style"
        type(prompt)
        at(send.frame)
        let greetingGone = G290.waitUntil(app, timeout: 3) { !self.app.staticTexts["What's on your mind?"].exists || self.app.staticTexts[prompt].exists }
        let bubble = app.staticTexts[prompt].firstMatch
        let right = bubble.exists && bubble.frame.maxX > 300
        G290.pause(app, 1)
        let gen = generating
        snap("TC-CH02-016 — vừa bấm gửi")
        dump("sending")
        let done = waitDone(after: 0)
        G290.pause(app, 3)
        snap("TC-CH02-016 — kết quả về")
        dump("result")
        let after = badge()
        G290.verdict("TC-CH02-016", pass: greetingGone && right && done,
                     "câu chào mất=\(greetingGone) · bong bóng người dùng bên phải=\(right) · ô đang tạo hiện=\(gen) · có kết quả=\(done)")
        G290.verdict("TC-CH03-011", (before != nil && after != nil) ? ((before! - after! == 1) ? "PASS" : "FAIL") : "NA",
                     "huy hiệu lượt Home \(before.map(String.init) ?? "—") → \(after.map(String.init) ?? "—") sau 1 lần gửi")
    }

    // MARK: - Kết quả, hàng nút, màn xem 902 (0 lượt)

    func test02_resultAndViewer() {
        openChat()
        guard let r = resultFrames().last else { G290.verdict("TC-CH06-001", "NA", "cuộc trò chuyện chưa có kết quả"); return }
        let save = app.staticTexts.matching(NSPredicate(format: "label == 'Save'")).allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }!
        let rowY = save.frame.midY
        let row = ["Save", "Share", "Regenerate"].map { l in app.staticTexts.matching(NSPredicate(format: "label == %@", l)).allElementsBoundByIndex.contains { $0.exists && abs($0.frame.midY - rowY) < 6 } }
        let caption = app.staticTexts.allElementsBoundByIndex.first { $0.exists && $0.frame.minX < 40 && $0.frame.maxY < r.minY + 20 && $0.label.count > 20 }?.label ?? "—"
        snap("TC-CH06-001 — câu trả lời có kết quả")
        G290.verdict("TC-CH06-001", pass: row.allSatisfy { $0 } && caption != "—", "dòng chữ: '\(caption.prefix(60))' · hàng nút Save/Share/Regenerate cùng hàng: \(row)")
        let report = app.buttons["Report"].exists || app.images["Report"].exists || G290.visibleTexts(app).contains("Report")
        G290.verdict("TC-CH06-003", pass: report, "nút Report trên kết quả=\(report)")

        // TC-CH06-007 — Lưu về máy
        let p0 = photoCount
        at(save.frame); _ = SystemPermissionAlertHandler.tapButton("Allow", timeout: 3)
        var toast = "—"
        _ = G290.waitUntil(app, timeout: 6) { if let t = G290.visibleTexts(self.app).first(where: { $0.localizedCaseInsensitiveContains("save") && $0 != "Save" }) { toast = t; return true }; return false }
        _ = G290.waitUntil(app, timeout: 10) { self.photoCount > p0 }
        snap("TC-CH06-007 — bấm Save")
        G290.verdict("TC-CH06-007", pass: photoCount > p0, "Photos \(p0) → \(photoCount) · thông báo: '\(toast)' (spec: 'Đã lưu')")

        // TC-CH06-008 — Chia sẻ
        let share = app.staticTexts.matching(NSPredicate(format: "label == 'Share'")).allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }
        if let share { at(share.frame) }
        let sheet = G290.waitUntil(app, timeout: 8) { self.app.otherElements["ActivityListView"].exists || self.app.buttons["Copy"].exists || self.app.navigationBars["UIActivityContentView"].exists || self.app.cells.count > 3 && self.app.tabBars.count == 0 }
        snap("TC-CH06-008 — bảng chia sẻ")
        G290.verdict("TC-CH06-008", pass: sheet, "bảng chia sẻ iOS mở=\(sheet)")
        if app.buttons["Close"].exists { app.buttons["Close"].tap() } else { app.swipeDown(velocity: .fast) }
        G290.pause(app, 2)

        // TC-CH06-004 / CH08-003 / CH08-006 / CH08-012 / CH08-011 / CH06-005 / CH06-006 — màn xem 902
        guard let img = resultFrames().last else { return }
        at(img); G290.pause(app, 2.5)
        let viewer = app.tabBars.buttons.count == 0
        let vInput = input.exists ? input.frame : .zero
        // Dấu cộng của màn xem sẽ nằm bên trái ô nhập của chính nó; dấu cộng của khung chat bị che.
        let plusInViewer = vInput.minX >= 50
        snap("TC-CH06-004 — màn xem 902 mở từ Chat")
        dump("viewer")
        G290.verdict("TC-CH06-004", pass: viewer, "bấm kết quả → màn xem phủ kín (thanh tab ẩn)=\(viewer)")
        G290.verdict("TC-CH08-003", pass: viewer && vInput.minY > 500 && !plusInViewer,
                     "ô nhập ở đáy=\(vInput.minY > 500) (y=\(Int(vInput.minY)), x=\(Int(vInput.minX))) · có nút dấu cộng=\(plusInViewer) · thanh Editing this (chỉ thấy trong ảnh): xem ảnh")
        let b0 = regenCount
        at(send.frame); G290.pause(app, 2)
        G290.verdict("TC-CH08-006", pass: app.tabBars.buttons.count == 0 && !generating, "ô nhập rỗng, bấm gửi: màn xem vẫn mở=\(app.tabBars.buttons.count == 0) · có lượt tạo mới=\(generating)")
        input.tap(); G290.pause(app, 1.5)
        let kb = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame : .zero
        let above = kb != .zero && input.frame.maxY <= kb.minY + 2
        snap("TC-CH08-012 — bàn phím trên 902")
        G290.verdict("TC-CH08-012", pass: above, "ô nhập maxY \(Int(input.frame.maxY)) · bàn phím minY \(Int(kb.minY)) · không bị che=\(above)")
        type("draft text"); dismissKeyboard()
        // kéo ngắn 1/8 → không đóng
        let mid = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        mid.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4 + 0.12)), withVelocity: .slow, thenHoldForDuration: 0.05)
        G290.pause(app, 1.5)
        let stillOpen = app.tabBars.buttons.count == 0
        G290.verdict("TC-CH06-006", pass: stillOpen, "kéo xuống ~1/8 màn rồi thả: màn xem vẫn mở=\(stillOpen)")
        mid.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4 + 0.4)), withVelocity: .fast, thenHoldForDuration: 0.0)
        let closed = G290.waitUntil(app, timeout: 4) { self.app.tabBars.buttons.count > 0 }
        G290.pause(app, 1)
        snap("TC-CH06-005 — kéo xuống đóng 902")
        G290.verdict("TC-CH06-005", pass: closed && resultFrames().count > 0, "kéo xuống quá 1/4 rồi thả: màn xem đóng=\(closed) · về khung chat thấy kết quả=\(resultFrames().count > 0)")
        G290.verdict("TC-CH08-011", pass: closed && inputText == "draft text", "ô soạn khung chat sau khi kéo đóng: '\(inputText)'")
        clearInput(); dismissKeyboard()
        _ = b0

        // TC-CH08-004 — mở từ Library không có ô nhập
        G290.openTab(app, "Library"); G290.pause(app, 3)
        at(G290.libraryCellRect(0)); G290.pause(app, 2.5)
        let libInput = (app.textFields.count + app.textViews.count) > 0 && input.frame.minY > 500
        snap("TC-CH08-004 — màn xem mở từ Library")
        G290.verdict("TC-CH08-004", pass: app.tabBars.buttons.count == 0 && !libInput, "màn xem từ Library mở=\(app.tabBars.buttons.count == 0) · có ô nhập=\(libInput)")
        app.swipeDown(); G290.pause(app, 1.5)

        // TC-CH01-007 — mở lại app thấy cuộc trò chuyện cũ
        let lastBefore = resultFramesCountInChat()
        app.terminate(); app.launch(); _ = G290.reachMain(app); openChat(); G290.pause(app, 2)
        let lastAfter = resultFrames().count
        let greeting = app.staticTexts["What's on your mind?"].exists && app.staticTexts["Make a birthday card from my photo"].exists
        snap("TC-CH01-007 — mở lại app")
        G290.verdict("TC-CH01-007", pass: lastAfter > 0 && !greeting, "trước khi kill thấy \(lastBefore) kết quả · mở lại thấy \(lastAfter) · câu chào trạng thái trống hiện=\(greeting)")
    }

    private func resultFramesCountInChat() -> Int { openChat(); return resultFrames().count }

    // MARK: - Sửa tiếp, vuốt chọn, sửa trên 902, Tạo lại (tốn lượt)

    func test03_editFlows() {
        openChat()
        if editingBar, let x = app.images.matching(identifier: "xmark").allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minY > 600 }) { at(x.frame); G290.pause(app, 1) }
        let credit0 = badge(); openChat()

        // TC-CH07-001 — gửi tiếp không chọn gì → sửa kết quả gần nhất (lượt 1)
        let r1 = sendAndWait("make the background a beach")
        snap("TC-CH07-001 — sửa tiếp kết quả gần nhất")
        G290.verdict("TC-CH07-001", r1.after == r1.before + 1 && !r1.error ? "PASS" : (r1.error ? "FAIL" : "NA"),
                     "số kết quả \(r1.before) → \(r1.after) · lỗi=\(r1.error) · kết quả cũ vẫn còn=\(r1.after >= 2) — bản sửa: xem ảnh")
        let credit1 = badge(); openChat()
        G290.verdict("TC-CH03-011", (credit0 != nil && credit1 != nil) ? (credit0! - credit1! == 1 ? "PASS" : "FAIL") : "NA",
                     "huy hiệu lượt Home \(credit0.map(String.init) ?? "—") → \(credit1.map(String.init) ?? "—") sau 1 lần gửi có kết quả")

        // TC-CH07-003 — kéo chưa tới ngưỡng
        var frames = resultFrames()
        if frames.count < 2 { app.swipeDown(); G290.pause(app, 1); frames = resultFrames() }
        guard let older = frames.first else { G290.verdict("TC-CH07-002", "NA", "không thấy kết quả để vuốt"); return }
        swipeResult(older, dx: 35)
        let short = editingBar
        G290.verdict("TC-CH07-003", pass: !short, "kéo ~35pt (< 1/5 = 78pt) rồi thả: thanh Editing this=\(short)")
        dismissKeyboard()
        // TC-CH07-002 — kéo qua ngưỡng
        swipeResult(older, dx: 140)
        let sel = editingBar, kb = app.keyboards.count > 0
        snap("TC-CH07-002 — vuốt chọn kết quả cũ")
        G290.verdict("TC-CH07-002", pass: sel && kb, "kéo ~140pt rồi thả: thanh Editing this=\(sel) · bàn phím mở=\(kb) · rung: không đo được")
        // TC-CH07-005 — x bỏ chọn, chữ còn
        type("abc")
        if let x = app.images.matching(identifier: "xmark").allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minY > 300 && $0.frame.minX > 300 }) { at(x.frame) }
        G290.pause(app, 1)
        G290.verdict("TC-CH07-005", pass: !editingBar && inputText == "abc", "bấm x: thanh Editing this còn=\(editingBar) · ô nhập='\(inputText)'")
        clearInput(); dismissKeyboard()
        // TC-CH07-006 — chọn A rồi vuốt B → đổi
        frames = resultFrames()
        if frames.count >= 2 {
            swipeResult(frames[0], dx: 140); dismissKeyboard()
            let barSig1 = G290.regionSignature(CGRect(x: 16, y: 520, width: 60, height: 200))
            frames = resultFrames(); swipeResult(frames[frames.count - 1], dx: 140)
            let barSig2 = G290.regionSignature(CGRect(x: 16, y: 520, width: 60, height: 200))
            G290.verdict("TC-CH07-006", pass: editingBar && G290.signatureDistance(barSig1, barSig2) > 6,
                         String(format: "vuốt kết quả khác: thanh Editing this còn=%@ · ảnh thu nhỏ đổi (khoảng cách %.0f)", editingBar ? "true" : "false", G290.signatureDistance(barSig1, barSig2)))
        } else { G290.verdict("TC-CH07-006", "NA", "chỉ thấy \(frames.count) kết quả trên màn") }
        // TC-CH07-007 — đang chọn mà kèm ảnh → thanh chọn mất
        dismissKeyboard()
        at(app.images.matching(identifier: "plus").allElementsBoundByIndex.first { $0.exists && $0.frame.minY > 600 }?.frame ?? .zero); G290.pause(app, 2)
        _ = PhotoPickerAutomator.pickPhoto(attempt: 1, in: app); G290.pause(app, 2)
        let attached = app.images["xmark.circle.fill"].exists
        snap("TC-CH07-007 — kèm ảnh khi đang chọn kết quả")
        G290.verdict("TC-CH07-007", pass: attached && !editingBar, "ô thu nhỏ ảnh=\(attached) · thanh Editing this còn=\(editingBar)")
        if attached { at(app.images["xmark.circle.fill"].frame); G290.pause(app, 1) }
        // TC-CH07-008 — vuốt tin nhắn người dùng / câu trả lời chữ
        dismissKeyboard()
        if let bubble = app.staticTexts.allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minX > 120 && $0.frame.minY > 120 && $0.frame.maxY < 650 && $0.label.count > 8 }) {
            let f = bubble.frame
            let a = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.minX + 10, dy: f.midY))
            a.press(forDuration: 0.15, thenDragTo: a.withOffset(CGVector(dx: 140, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.2)
            G290.pause(app, 1)
            G290.verdict("TC-CH07-008", pass: !editingBar, "vuốt bong bóng người dùng '\(bubble.label.prefix(30))': thanh Editing this=\(editingBar)")
        }
        dismissKeyboard()

        // TC-CH07-004 — gửi cho kết quả đã chọn (lượt 2)
        frames = resultFrames()
        if let first = frames.first {
            swipeResult(first, dx: 140)
            let chosen = editingBar
            let r = sendAndWait("make it black and white")
            let thumbInMsg = app.images.allElementsBoundByIndex.contains { $0.exists && $0.frame.minX > 200 && $0.frame.width > 30 && $0.frame.width < 140 && $0.frame.minY > 100 && $0.frame.maxY < 700 }
            snap("TC-CH07-004 — gửi cho kết quả đã chọn")
            G290.verdict("TC-CH07-004", chosen && r.after == r.before + 1 && !editingBar ? "PASS" : (r.error ? "FAIL" : "CHECK"),
                         "đã chọn=\(chosen) · số kết quả \(r.before) → \(r.after) · thanh Editing this sau gửi=\(editingBar) · ảnh thu nhỏ trong tin nhắn=\(thumbInMsg) — bản sửa đúng kết quả đã chọn: xem ảnh")
        }

        // TC-CH08-005 — gõ + gửi trên 902 (lượt 3)
        frames = resultFrames()
        if let f = frames.first {
            at(f); G290.pause(app, 2.5)
            let b = regenCount
            type("add sunglasses")
            at(app.images.matching(identifier: "arrow.up").allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }?.frame ?? .zero)
            let closed = G290.waitUntil(app, timeout: 6) { self.app.tabBars.buttons.count > 0 }
            let gen = G290.waitUntil(app, timeout: 6) { self.generating }
            _ = waitDone(after: b); G290.pause(app, 2)
            snap("TC-CH08-005 — gửi từ màn xem")
            G290.verdict("TC-CH08-005", pass: closed && regenCount == b + 1, "màn xem đóng=\(closed) · khung chat hiện lượt đang tạo=\(gen) · số kết quả \(b) → \(regenCount)")
        }

        // TC-CH06-009 — Tạo lại (lượt 4)
        let b9 = regenCount
        if let rg = app.staticTexts.matching(NSPredicate(format: "label == 'Regenerate'")).allElementsBoundByIndex.filter({ $0.exists && $0.frame.minY < 720 }).max(by: { $0.frame.minY < $1.frame.minY }) {
            at(rg.frame); _ = waitDone(after: b9); G290.pause(app, 2)
        }
        snap("TC-CH06-009 — Tạo lại")
        G290.verdict("TC-CH06-009", pass: regenCount == b9 + 1, "bấm Regenerate: số kết quả \(b9) → \(regenCount) · kết quả cũ vẫn còn")

        // TC-CH02-023 + CH06-002 — gửi câu chào (lượt 5?)
        let c0 = badge(); openChat()
        let b23 = regenCount
        clearInput(); type("hello")
        at(send.frame)
        _ = G290.waitUntil(app, timeout: 60) { !self.generating && G290.visibleTexts(self.app).count > 0 && !G290.visibleTexts(self.app).contains { $0.hasPrefix("Replying") } }
        G290.pause(app, 4)
        let reply = app.staticTexts.allElementsBoundByIndex.last { $0.exists && $0.frame.minX < 40 && $0.frame.minY > 150 && $0.frame.maxY < 720 }?.label ?? "—"
        let c1 = badge(); openChat()
        snap("TC-CH02-021 — gửi câu chào")
        G290.verdict("TC-CH06-002", pass: regenCount == b23, "câu trả lời chữ '\(reply.prefix(70))' · thêm hàng nút=\(regenCount != b23)")
        G290.verdict("TC-CH02-021", (c0 != nil && c1 != nil) ? ((regenCount == b23 && c0! - c1! == 1) ? "PASS" : "FAIL") : "NA",
                     "trả lời chữ, không có kết quả=\(regenCount == b23) · lượt \(c0.map(String.init) ?? "—") → \(c1.map(String.init) ?? "—") (spec: trừ 1)")

        // TC-CH04-001 — xin 2 ảnh (lượt 6)
        let r4 = sendAndWait("create 2 images of a cat")
        G290.pause(app, 2)
        let prefilled = inputText, hint = G290.visibleTexts(app).first { $0.localizedCaseInsensitiveContains("one thing at a time") } ?? "—"
        snap("TC-CH04-001 — xin 2 ảnh")
        G290.verdict("TC-CH04-001", pass: r4.after == r4.before + 1 && !prefilled.isEmpty && prefilled != "What's on your mind?" && hint != "—",
                     "số kết quả \(r4.before) → \(r4.after) · ô nhập điền sẵn '\(prefilled)' · dòng nhắc '\(hint)'")
        clearInput(); dismissKeyboard()
    }

    // MARK: - Mất mạng, kèm ảnh, rời tab, video, Library, cuộc trò chuyện mới

    private var trayText: String? { G290.visibleTexts(app).first { $0.contains("Creating") || $0.contains("Ready —") || $0.contains("Couldn") } }

    func test04_networkAttachLibraryNewConversation() {
        let net = SettingsNetworkDriver { self.app }
        defer { _ = net.ensureOn() }
        openChat()
        // TC-CH01-010 + CH05-001 — mất mạng
        let off = net.setAirplaneMode(true)
        openChat(); G290.pause(app, 2)
        let oldVisible = resultFrames().count > 0
        let c = regenCount
        clearInput(); type("a cat")
        let typed = inputText == "a cat"
        at(send.frame); G290.pause(app, 2)
        let offlineMsg = G290.visibleTexts(app).first { $0.localizedCaseInsensitiveContains("internet") } ?? "—"
        let retry = G290.visibleTexts(app).contains("Retry")
        snap("TC-CH05-001 — bấm gửi khi mất mạng")
        G290.verdict("TC-CH01-010", off ? (oldVisible && typed ? "PASS" : "FAIL") : "NA", "mất mạng: màn Chat mở, thấy cuộc trò chuyện cũ=\(oldVisible) · gõ được chữ=\(typed)")
        G290.verdict("TC-CH05-001", off ? (offlineMsg != "—" && regenCount == c ? (retry ? "PASS" : "CHECK") : "FAIL") : "NA",
                     "thông báo '\(offlineMsg)' · nút Retry=\(retry) · số kết quả không đổi=\(regenCount == c)")
        // TC-CH08-008 — mất mạng khi gửi từ 902
        clearInput(); dismissKeyboard()
        if let f = resultFrames().last {
            at(f); G290.pause(app, 2)
            type("add a hat")
            at(app.images.matching(identifier: "arrow.up").allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }?.frame ?? .zero)
            let closed = G290.waitUntil(app, timeout: 5) { self.app.tabBars.buttons.count > 0 }
            G290.pause(app, 1)
            let msg = G290.visibleTexts(app).first { $0.localizedCaseInsensitiveContains("internet") } ?? "—"
            snap("TC-CH08-008 — mất mạng khi gửi từ màn xem")
            G290.verdict("TC-CH08-008", off ? ((closed && msg != "—" && inputText == "add a hat" && editingBar) ? "PASS" : "FAIL") : "NA",
                         "màn xem đóng=\(closed) · thông báo '\(msg)' · ô soạn='\(inputText)' · kết quả vẫn là đối tượng sửa (Editing this)=\(editingBar)")
        }
        _ = net.ensureOn(); G290.pause(app, 4)
        openChat(); clearInput()
        if editingBar, let x = app.images.matching(identifier: "xmark").allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minY > 300 && $0.frame.minX > 300 }) { at(x.frame) }
        dismissKeyboard()

        // TC-CH02-017 — kèm 1 ảnh + yêu cầu sửa (1 lượt)
        let p0 = photoCount
        at(app.images.matching(identifier: "plus").allElementsBoundByIndex.first { $0.exists && $0.frame.minY > 600 }?.frame ?? .zero); G290.pause(app, 2)
        _ = PhotoPickerAutomator.pickPhoto(attempt: 2, in: app); G290.pause(app, 2)
        let r17 = sendAndWait("turn into an oil painting")
        let thumbInMsg = app.images.allElementsBoundByIndex.contains { $0.exists && $0.frame.minX > 200 && $0.frame.width > 30 && $0.frame.width < 160 && $0.frame.minY > 100 && $0.frame.maxY < 700 }
        snap("TC-CH02-017 — kèm ảnh + sửa")
        G290.verdict("TC-CH02-017", r17.after == r17.before + 1 ? (photoCount == p0 ? "PASS" : "FAIL") : (r17.error ? "FAIL" : "NA"),
                     "số kết quả \(r17.before) → \(r17.after) · ảnh thu nhỏ trong tin nhắn=\(thumbInMsg) · Photos \(p0) → \(photoCount) (ảnh gốc không đổi)")

        // TC-CH02-020 — đổi tab khi đang tạo, quay lại thấy kết quả (1 lượt)
        let b22 = regenCount
        clearInput(); type("a red apple on a wooden table")
        at(send.frame); G290.pause(app, 2)
        G290.openTab(app, "Home"); G290.pause(app, 2)
        let tray = trayText ?? "—"
        snap("TC-CH02-020 — rời tab khi đang tạo")
        _ = G290.waitUntil(app, timeout: 200) { (self.trayText ?? "").contains("Ready") || (self.trayText ?? "").contains("Couldn") }
        openChat(); G290.pause(app, 2)
        G290.verdict("TC-CH02-020", pass: regenCount == b22 + 1, "khay khi ở Home: '\(tray)' · quay lại Chat: số kết quả \(b22) → \(regenCount)")

        // TC-CH06-010 — kết quả Chat ở đầu Library + CH08-004 (lọc Photo)
        G290.openTab(app, "Library"); G290.pause(app, 3)
        G290.anyLabeled(app, "Photo").tap(); G290.pause(app, 2)
        let libFirst = G290.regionSignature(G290.libraryCellRect(0))
        snap("TC-CH06-010 — Library sau khi tạo trong Chat")
        at(G290.libraryCellRect(0)); G290.pause(app, 2.5)
        let fields = app.textFields.allElementsBoundByIndex.filter { $0.exists && $0.frame.minY > 500 && $0.isHittable }
        snap("TC-CH08-004 — màn xem mở từ Library")
        G290.verdict("TC-CH08-004", pass: app.tabBars.buttons.count == 0 && fields.isEmpty, "màn xem từ Library (lọc Photo) mở=\(app.tabBars.buttons.count == 0) · có ô nhập=\(!fields.isEmpty)")
        app.swipeDown(); G290.pause(app, 1.5)
        if app.tabBars.buttons.count == 0 { app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 36, dy: 75)).tap(); G290.pause(app, 1.5) }
        openChat()
        let chatLast = resultFrames().last.map { G290.regionSignature($0) } ?? []
        G290.verdict("TC-CH06-010", "CHECK", String(format: "ô đầu Library (lọc Photo) vs kết quả mới nhất trong Chat — khoảng cách %.0f (khác tỉ lệ cắt, so bằng ảnh)", G290.signatureDistance(libFirst, chatLast)))

        // TC-CH01-009 / CH01-008 — cuộc trò chuyện mới: Huỷ rồi xác nhận
        let before = resultFrames().count
        app.buttons["More"].firstMatch.tap(); G290.pause(app, 1)
        app.buttons["New conversation"].firstMatch.tap(); G290.pause(app, 1.5)
        let confirmText = G290.visibleTexts(app).first { $0.contains("Start a new conversation") } ?? "—"
        snap("TC-CH01-008 — hộp thoại cuộc trò chuyện mới")
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].firstMatch.tap() }; G290.pause(app, 1.5)
        G290.verdict("TC-CH01-009", pass: resultFrames().count == before && before > 0, "bấm Huỷ: số kết quả còn \(resultFrames().count)/\(before)")
        app.buttons["More"].firstMatch.tap(); G290.pause(app, 1)
        app.buttons["New conversation"].firstMatch.tap(); G290.pause(app, 1.5)
        let destructive = app.buttons.matching(NSPredicate(format: "label == 'New conversation'")).allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }
        destructive?.tap(); G290.pause(app, 2)
        let empty = app.staticTexts["What's on your mind?"].exists && app.staticTexts["Make a birthday card from my photo"].exists
        G290.openTab(app, "Library"); G290.pause(app, 3)
        let libStill = app.buttons.matching(NSPredicate(format: "label == 'More'")).count > 0
        snap("TC-CH01-008 — sau khi bắt đầu cuộc mới")
        G290.verdict("TC-CH01-008", pass: confirmText != "—" && empty && libStill, "hộp thoại: '\(confirmText)' · Chat về trạng thái trống=\(empty) · Library vẫn có kết quả=\(libStill)")
    }

    // MARK: - Bản chạy độc lập (server chậm: chờ rảnh trước khi gửi, chấm theo câu trả lời cuối)

    private func waitIdle(_ timeout: TimeInterval = 420) -> Bool { G290.waitUntil(app, timeout: timeout) { !self.generating } }
    /// Câu trả lời nằm cuối khung chat: "result" (hàng nút) hay "error" (lỗi/quá thời gian) hay "text".
    private func lastOutcome() -> String {
        let regen = app.staticTexts.matching(NSPredicate(format: "label == 'Regenerate'")).allElementsBoundByIndex.filter { $0.exists }.map(\.frame.maxY).max() ?? -1
        let err = app.staticTexts.allElementsBoundByIndex.filter { $0.exists && ($0.label.contains("Couldn") || $0.label.contains("longer than expected")) }.map(\.frame.maxY).max() ?? -1
        if regen < 0 && err < 0 { return "text" }
        return regen > err ? "result" : "error"
    }
    /// Gửi rồi chờ xong (tối đa 7 phút); trả câu trả lời cuối + có chạy hay không.
    private func sendIdle(_ text: String) -> (started: Bool, outcome: String) {
        _ = waitIdle(); dismissKeyboard()
        clearInput(); type(text)
        at(send.frame)
        let started = G290.waitUntil(app, timeout: 10) { self.generating }
        _ = waitIdle(); G290.pause(app, 3)
        return (started, lastOutcome())
    }
    private func clearSelection() {
        if editingBar, let x = app.images.matching(identifier: "xmark").allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minY > 300 && $0.frame.minX > 300 }) { at(x.frame); G290.pause(app, 1) }
    }
    private func startChat() { openChat(); _ = waitIdle(); clearSelection(); clearInput(); dismissKeyboard() }

    func test05_swipeSelect() {
        startChat()
        var frames = resultFrames()
        if frames.isEmpty { app.swipeDown(); G290.pause(app, 1); frames = resultFrames() }
        guard let f = frames.last else { G290.verdict("TC-CH07-002", "NA", "không thấy kết quả trên màn"); return }
        swipeResult(f, dx: 35)
        G290.verdict("TC-CH07-003", pass: !editingBar, "kéo ~35pt (< 1/5 = 78pt) rồi thả: thanh Editing this=\(editingBar)")
        clearSelection(); dismissKeyboard()
        swipeResult(f, dx: 150)
        let sel = editingBar, kb = app.keyboards.count > 0
        snap("TC-CH07-002 — vuốt chọn kết quả")
        G290.verdict("TC-CH07-002", pass: sel && kb, "kéo ~150pt rồi thả: thanh Editing this=\(sel) · bàn phím mở=\(kb) · rung: không đo được")
        guard sel else { return }
        type("abc"); clearSelection()
        G290.verdict("TC-CH07-005", pass: !editingBar && inputText == "abc", "bấm x: thanh Editing this còn=\(editingBar) · ô nhập='\(inputText)'")
        clearInput(); dismissKeyboard()
        frames = resultFrames()
        if frames.count >= 2 {
            swipeResult(frames[0], dx: 150); dismissKeyboard()
            let s1 = G290.regionSignature(CGRect(x: 16, y: 600, width: 70, height: 110))
            frames = resultFrames(); swipeResult(frames[frames.count - 1], dx: 150); dismissKeyboard()
            let s2 = G290.regionSignature(CGRect(x: 16, y: 600, width: 70, height: 110))
            snap("TC-CH07-006 — vuốt kết quả khác")
            G290.verdict("TC-CH07-006", editingBar ? (G290.signatureDistance(s1, s2) > 6 ? "PASS" : "CHECK") : "FAIL",
                         String(format: "vuốt kết quả khác: thanh Editing this=%@ · ảnh thu nhỏ trên thanh đổi (khoảng cách %.0f)", editingBar ? "true" : "false", G290.signatureDistance(s1, s2)))
        } else { G290.verdict("TC-CH07-006", "NA", "chỉ thấy \(frames.count) kết quả trên màn") }
        if !editingBar, let f2 = resultFrames().last { swipeResult(f2, dx: 150) }
        dismissKeyboard()
        at(app.images.matching(identifier: "plus").allElementsBoundByIndex.first { $0.exists && $0.frame.minY > 500 }?.frame ?? .zero); G290.pause(app, 2)
        _ = PhotoPickerAutomator.pickPhoto(attempt: 10, in: app); G290.pause(app, 2)
        let attached = app.images["xmark.circle.fill"].exists
        snap("TC-CH07-007 — kèm ảnh khi đang chọn kết quả")
        G290.verdict("TC-CH07-007", pass: attached && !editingBar, "ô thu nhỏ ảnh=\(attached) · thanh Editing this còn=\(editingBar)")
        if attached { at(app.images["xmark.circle.fill"].frame); G290.pause(app, 1) }
        dismissKeyboard()
        if let bubble = app.staticTexts.allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minX > 120 && $0.frame.minY > 120 && $0.frame.maxY < 650 && $0.label.count > 8 }) {
            let a = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: bubble.frame.minX + 10, dy: bubble.frame.midY))
            a.press(forDuration: 0.5, thenDragTo: a.withOffset(CGVector(dx: 150, dy: 0)), withVelocity: XCUIGestureVelocity(150), thenHoldForDuration: 0.1)
            G290.pause(app, 1.2)
            G290.verdict("TC-CH07-008", pass: !editingBar, "vuốt bong bóng người dùng '\(bubble.label.prefix(30))': thanh Editing this=\(editingBar)")
        }
        clearSelection()
    }

    func test06_sendForSelected() {
        startChat()
        guard let f = resultFrames().first else { G290.verdict("TC-CH07-004", "NA", "không thấy kết quả"); return }
        swipeResult(f, dx: 150)
        let chosen = editingBar
        guard chosen else { G290.verdict("TC-CH07-004", "NA", "không vuốt chọn được kết quả"); return }
        let r = sendIdle("make it black and white")
        snap("TC-CH07-004 — gửi cho kết quả đã chọn")
        G290.verdict("TC-CH07-004", r.outcome == "result" && !editingBar ? "PASS" : (r.outcome == "error" ? "FAIL" : "CHECK"),
                     "đã chọn=\(chosen) · bắt đầu tạo=\(r.started) · câu trả lời cuối=\(r.outcome) · thanh Editing this sau gửi=\(editingBar) — bản sửa đúng kết quả đã chọn: xem ảnh")
    }

    func test07_editFromViewer() {
        startChat()
        guard let f = resultFrames().first else { G290.verdict("TC-CH08-005", "NA", "không thấy kết quả"); return }
        at(f); G290.pause(app, 2.5)
        type("add sunglasses")
        at(app.images.matching(identifier: "arrow.up").allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }?.frame ?? .zero)
        let closed = G290.waitUntil(app, timeout: 6) { self.app.tabBars.buttons.count > 0 }
        let gen = G290.waitUntil(app, timeout: 8) { self.generating }
        _ = waitIdle(); G290.pause(app, 3)
        let out = lastOutcome()
        snap("TC-CH08-005 — gửi từ màn xem")
        G290.verdict("TC-CH08-005", closed && out == "result" ? "PASS" : (out == "error" ? "FAIL" : "CHECK"), "màn xem đóng=\(closed) · khung chat hiện lượt đang tạo=\(gen) · câu trả lời cuối=\(out)")
    }

    func test08_regenerate() {
        startChat()
        guard let rg = app.staticTexts.matching(NSPredicate(format: "label == 'Regenerate'")).allElementsBoundByIndex.filter({ $0.exists && $0.frame.minY < 720 }).max(by: { $0.frame.minY < $1.frame.minY }) else {
            G290.verdict("TC-CH06-009", "NA", "không thấy nút Regenerate"); return
        }
        let c0 = badge(); openChat()
        at(rg.frame)
        let gen = G290.waitUntil(app, timeout: 8) { self.generating }
        _ = waitIdle(); G290.pause(app, 3)
        let out = lastOutcome(); let c1 = badge(); openChat()
        snap("TC-CH06-009 — Tạo lại")
        G290.verdict("TC-CH06-009", out == "result" ? "PASS" : (out == "error" ? "FAIL" : "CHECK"),
                     "bấm Regenerate: bắt đầu tạo=\(gen) · câu trả lời cuối=\(out) · lượt \(c0.map(String.init) ?? "—") → \(c1.map(String.init) ?? "—")")
    }

    func test09_helloTextOnly() {
        startChat()
        let c0 = badge(); openChat()
        let r = sendIdle("hello")
        let reply = app.staticTexts.allElementsBoundByIndex.filter { $0.exists && $0.frame.minX < 40 && $0.frame.minY > 120 && $0.frame.maxY < 720 && $0.label.count > 10 }.max { $0.frame.minY < $1.frame.minY }?.label ?? "—"
        let c1 = badge(); openChat()
        snap("TC-CH02-021 — gửi câu chào")
        G290.verdict("TC-CH06-002", pass: r.outcome != "result" || reply != "—", "câu trả lời cuối=\(r.outcome) · chữ: '\(reply.prefix(80))'")
        G290.verdict("TC-CH02-021", (c0 != nil && c1 != nil) ? ((r.outcome != "result" && c0! - c1! == 1) ? "PASS" : "FAIL") : "NA",
                     "câu trả lời cuối=\(r.outcome) · chữ '\(reply.prefix(60))' · lượt \(c0.map(String.init) ?? "—") → \(c1.map(String.init) ?? "—") (spec: trả lời chữ, trừ 1)")
    }

    func test10_oneThingAtATime() {
        startChat()
        let r = sendIdle("create 2 images of a cat")
        let pre = inputText, hint = G290.visibleTexts(app).first { $0.localizedCaseInsensitiveContains("one thing at a time") } ?? "—"
        snap("TC-CH04-001 — xin 2 ảnh")
        G290.verdict("TC-CH04-001", r.outcome == "result" ? ((pre.isEmpty || pre == "What's on your mind?" || hint == "—") ? "FAIL" : "PASS") : "NA",
                     "câu trả lời cuối=\(r.outcome) · ô nhập điền sẵn '\(pre)' · dòng nhắc '\(hint)'")
        clearInput(); dismissKeyboard()
        let r2 = sendIdle("create 1 image of a cat and 1 video of a dog dancing")
        let pre2 = inputText, hint2 = G290.visibleTexts(app).first { $0.localizedCaseInsensitiveContains("one thing at a time") } ?? "—"
        snap("TC-CH04-002 — ảnh + video khác chủ thể")
        G290.verdict("TC-CH04-002", r2.outcome == "result" ? ((pre2.localizedCaseInsensitiveContains("dog") && hint2 != "—") ? "PASS" : "FAIL") : "NA",
                     "câu trả lời cuối=\(r2.outcome) · ô nhập điền sẵn '\(pre2)' · dòng nhắc '\(hint2)'")
        clearInput(); dismissKeyboard()
    }

    func test11_attachAndLeaveTab() {
        startChat()
        at(app.images.matching(identifier: "plus").allElementsBoundByIndex.first { $0.exists && $0.frame.minY > 500 }?.frame ?? .zero); G290.pause(app, 2)
        _ = PhotoPickerAutomator.pickPhoto(attempt: 10, in: app); G290.pause(app, 2)
        let p0 = photoCount
        let r = sendIdle("turn into an oil painting")
        let thumb = app.images.allElementsBoundByIndex.contains { $0.exists && $0.frame.minX > 180 && $0.frame.width > 30 && $0.frame.width < 170 && $0.frame.minY > 100 && $0.frame.maxY < 700 }
        snap("TC-CH02-017 — kèm ảnh + sửa")
        G290.verdict("TC-CH02-017", r.outcome == "result" ? (photoCount == p0 ? "PASS" : "FAIL") : (r.outcome == "error" ? "FAIL" : "CHECK"),
                     "câu trả lời cuối=\(r.outcome) · ảnh thu nhỏ trong tin nhắn=\(thumb) · Photos \(p0) → \(photoCount) (ảnh gốc không đổi)")
        // TC-CH02-020 — rời tab khi đang tạo
        _ = waitIdle(); clearInput(); type("a red apple on a wooden table"); at(send.frame)
        _ = G290.waitUntil(app, timeout: 8) { self.generating }
        G290.openTab(app, "Home"); G290.pause(app, 3)
        let tray = trayText ?? "—"
        snap("TC-CH02-020 — rời tab khi đang tạo")
        _ = G290.waitUntil(app, timeout: 420) { (self.trayText ?? "").contains("Ready") || (self.trayText ?? "").contains("Couldn") || self.trayText == nil }
        openChat(); _ = waitIdle(); G290.pause(app, 2)
        let out = lastOutcome()
        snap("TC-CH02-020 — quay lại Chat")
        G290.verdict("TC-CH02-020", out == "result" ? "PASS" : (out == "error" ? "FAIL" : "CHECK"), "khay khi ở Home: '\(tray)' · quay lại Chat câu trả lời cuối=\(out)")
    }

    func test12_libraryAndNewConversation() {
        G290.openTab(app, "Library"); G290.pause(app, 4)
        _ = G290.anyLabeled(app, "Photo").waitForExistence(timeout: 10)
        let photo = G290.anyLabeled(app, "Photo"); if photo.exists { at(photo.frame) }; G290.pause(app, 2)
        snap("TC-CH06-010 — Library sau khi tạo trong Chat")
        at(G290.libraryCellRect(0)); G290.pause(app, 2.5)
        let fields = app.textFields.allElementsBoundByIndex.filter { $0.exists && $0.frame.minY > 500 && $0.isHittable }
        snap("TC-CH08-004 — màn xem mở từ Library")
        G290.verdict("TC-CH08-004", pass: app.tabBars.buttons.count == 0 && fields.isEmpty, "màn xem từ Library (lọc Photo) mở=\(app.tabBars.buttons.count == 0) · có ô nhập=\(!fields.isEmpty)")
        app.swipeDown(); G290.pause(app, 1.5)
        if app.tabBars.buttons.count == 0 { app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 36, dy: 75)).tap(); G290.pause(app, 1.5) }
        startChat()
        let before = resultFrames().count
        app.buttons["More"].firstMatch.tap(); G290.pause(app, 1)
        app.buttons["New conversation"].firstMatch.tap(); G290.pause(app, 1.5)
        let confirmText = G290.visibleTexts(app).first { $0.contains("Start a new conversation") } ?? "—"
        snap("TC-CH01-008 — hộp thoại cuộc trò chuyện mới")
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].firstMatch.tap() }; G290.pause(app, 1.5)
        G290.verdict("TC-CH01-009", pass: before > 0 && resultFrames().count == before, "bấm Huỷ: kết quả trên màn còn \(resultFrames().count)/\(before)")
        app.buttons["More"].firstMatch.tap(); G290.pause(app, 1)
        app.buttons["New conversation"].firstMatch.tap(); G290.pause(app, 1.5)
        app.buttons.matching(NSPredicate(format: "label == 'New conversation'")).allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }?.tap()
        G290.pause(app, 2)
        let empty = app.staticTexts["What's on your mind?"].exists && app.staticTexts["Make a birthday card from my photo"].exists
        G290.openTab(app, "Library"); G290.pause(app, 3)
        let libStill = app.buttons.matching(NSPredicate(format: "label == 'More'")).count > 0
        snap("TC-CH01-008 — sau khi bắt đầu cuộc mới")
        G290.verdict("TC-CH01-008", pass: confirmText != "—" && empty && libStill, "hộp thoại: '\(confirmText)' · Chat về trạng thái trống=\(empty) · Library vẫn có kết quả=\(libStill)")
    }

    /// Dò cử chỉ vuốt chọn (0 lượt): thử nhiều kiểu kéo, ghi kiểu nào hiện thanh Editing this mà KHÔNG mở màn xem.
    func test13_probeSwipeGesture() {
        startChat()
        let variants: [(String, (XCUICoordinate) -> Void)] = [
            ("giữ 0,5s kéo chậm", { a in a.press(forDuration: 0.5, thenDragTo: a.withOffset(CGVector(dx: 160, dy: 0)), withVelocity: XCUIGestureVelocity(150), thenHoldForDuration: 0.1) }),
            ("giữ 0,05s kéo 250pt/s", { a in a.press(forDuration: 0.05, thenDragTo: a.withOffset(CGVector(dx: 160, dy: 0)), withVelocity: XCUIGestureVelocity(250), thenHoldForDuration: 0.0) }),
            ("giữ 0,2s kéo 600pt/s", { a in a.press(forDuration: 0.2, thenDragTo: a.withOffset(CGVector(dx: 170, dy: 0)), withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.0) }),
            ("kéo từ mép trái ô", { a in let b = a.withOffset(CGVector(dx: -30, dy: 0)); b.press(forDuration: 0.1, thenDragTo: b.withOffset(CGVector(dx: 180, dy: 0)), withVelocity: XCUIGestureVelocity(300), thenHoldForDuration: 0.0) }),
        ]
        var log: [String] = [], winner = "—"
        for (name, act) in variants {
            guard let f = resultFrames().last else { break }
            act(app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.minX + 50, dy: f.midY)))
            G290.pause(app, 1.5)
            let viewer = app.tabBars.buttons.count == 0, sel = editingBar && !viewer
            log.append("\(name): màn xem=\(viewer) chọn=\(sel)")
            if viewer { app.swipeDown(); G290.pause(app, 1.5); if app.tabBars.buttons.count == 0 { app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 36, dy: 75)).tap(); G290.pause(app, 1.5) } }
            if sel { winner = name; snap("probe — vuốt chọn được (\(name))"); break }
            dismissKeyboard()
        }
        print("SWIPEPROBE|\(log)|thắng=\(winner)")
    }

    func test14_newConversation() {
        startChat()
        func openConfirm() -> Bool {
            for _ in 0..<3 {
                app.buttons["More"].firstMatch.tap(); G290.pause(app, 1.5)
                let item = app.buttons.matching(NSPredicate(format: "label == 'New conversation'")).firstMatch
                if item.waitForExistence(timeout: 3) { item.tap(); G290.pause(app, 1.5) }
                if G290.visibleTexts(app).contains(where: { $0.contains("Start a new conversation") }) { return true }
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap(); G290.pause(app, 1)
            }
            return false
        }
        let before = resultFrames().count
        guard openConfirm() else { G290.verdict("TC-CH01-008", "NA", "không mở được hộp thoại New conversation"); return }
        let confirmText = G290.visibleTexts(app).first { $0.contains("Start a new conversation") } ?? "—"
        let red = app.buttons.matching(NSPredicate(format: "label == 'New conversation'")).allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }
        red?.tap(); G290.pause(app, 2.5)
        let empty = app.staticTexts["What's on your mind?"].exists && app.staticTexts["Make a birthday card from my photo"].exists
        snap("TC-CH01-008 — sau khi bắt đầu cuộc mới")
        G290.openTab(app, "Library"); G290.pause(app, 3)
        let libStill = app.buttons.matching(NSPredicate(format: "label == 'More'")).count > 0
        G290.verdict("TC-CH01-008", pass: confirmText != "—" && empty && libStill,
                     "trước: \(before) kết quả trên màn · hộp thoại: '\(confirmText)' · Chat về trạng thái trống=\(empty) · Library vẫn có kết quả=\(libStill)")
    }

    // MARK: - Nhóm còn lại

    private var viewerOpen: Bool { app.tabBars.buttons.count == 0 }
    private func closeViewer() {
        guard viewerOpen else { return }
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 36, dy: 75)).tap(); G290.pause(app, 1.5)
        if viewerOpen { app.swipeDown(); G290.pause(app, 1.5) }
    }
    private func viewerSig() -> [Double] { G290.regionSignature(CGRect(x: 60, y: 300, width: 270, height: 200)) }
    private func attachPhoto(_ attempt: Int) -> Bool {
        dismissKeyboard()
        guard let plus = app.images.matching(identifier: "plus").allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minY > 500 }) else { return false }
        at(plus.frame); G290.pause(app, 2.5)
        _ = PhotoPickerAutomator.pickPhoto(attempt: attempt, in: app)
        return app.images["xmark.circle.fill"].waitForExistence(timeout: 8)
    }

    func test15_e2eLibraryAndDeleted() {
        startChat()
        // TC-REG02-001 — tạo → sửa tiếp → xem 902 → Lưu → Library
        let a = sendIdle("a cat in a garden")
        let b = sendIdle("make it night")
        var saved = false, sig902: [Double] = []
        if let f = resultFrames().last {
            at(f); G290.pause(app, 2.5); sig902 = viewerSig()
            let p0 = photoCount
            if let dl = app.buttons.matching(NSPredicate(format: "label == 'Download'")).allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minY < 120 }) { at(dl.frame) }
            saved = G290.waitUntil(app, timeout: 10) { self.photoCount > p0 }
            snap("TC-REG02-001 — lưu từ màn xem")
            closeViewer()
        }
        G290.openTab(app, "Library"); G290.pause(app, 3)
        let photo = G290.anyLabeled(app, "Photo"); if photo.waitForExistence(timeout: 5) { at(photo.frame) }; G290.pause(app, 2)
        at(G290.libraryCellRect(0)); G290.pause(app, 2.5)
        let libSig = viewerSig(); let d = G290.signatureDistance(sig902, libSig)
        snap("TC-CH06-010 — ô đầu Library mở ra")
        closeViewer()
        G290.verdict("TC-CH06-010", sig902.isEmpty ? "NA" : (d < 15 ? "PASS" : "FAIL"), String(format: "ảnh mới nhất của Chat (màn xem) vs ô đầu Library lọc Photo (màn xem): khoảng cách %.1f", d))
        G290.verdict("TC-REG02-001", a.outcome == "result" && b.outcome == "result" && saved && d < 15 ? "PASS" : "FAIL",
                     String(format: "tạo=%@ · sửa tiếp=%@ · Lưu từ 902 vào Photos=%@ · Library có kết quả ở đầu (khoảng cách %.1f)", a.outcome, b.outcome, saved ? "true" : "false", d))

        // TC-CH07-010 + CH06-011 — chọn kết quả mới nhất, xoá nó ở Library, quay lại Chat gửi
        startChat()
        guard let last = resultFrames().last else { return }
        swipeResult(last, dx: 150)
        let chosen = editingBar; dismissKeyboard()
        G290.openTab(app, "Library"); G290.pause(app, 3)
        if photo.exists { at(photo.frame) }; G290.pause(app, 2)
        let more = app.buttons.matching(NSPredicate(format: "label == 'More'")).allElementsBoundByIndex.filter { $0.exists && $0.frame.minY > 140 }.min { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
        more?.tap(); G290.pause(app, 1)
        app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Delete'")).firstMatch.tap(); G290.pause(app, 1)
        if app.alerts.buttons["Delete"].exists { app.alerts.buttons["Delete"].firstMatch.tap() }
        G290.pause(app, 3)
        openChat(); G290.pause(app, 2)
        let deletedNote = G290.visibleTexts(app).first { $0.localizedCaseInsensitiveContains("deleted") || $0.localizedCaseInsensitiveContains("removed") || $0.localizedCaseInsensitiveContains("no longer") } ?? "—"
        snap("TC-CH06-011 — Chat sau khi xoá ở Library")
        G290.verdict("TC-CH06-011", pass: deletedNote != "—", "ô kết quả vừa xoá ở Library hiện: '\(deletedNote)' (spec: 'Tệp đã bị xoá')")
        let c0 = badge(); openChat()
        clearInput(); type("add a hat"); at(send.frame); G290.pause(app, 3)
        let msg = G290.visibleTexts(app).first { $0.contains("Can't find") || $0.localizedCaseInsensitiveContains("find the image") } ?? "—"
        let keep = inputText
        snap("TC-CH07-010 — gửi khi kết quả đã chọn bị xoá")
        _ = waitIdle(120); let c1 = badge(); openChat()
        G290.verdict("TC-CH07-010", chosen ? ((msg != "—" && !editingBar && c0 == c1) ? "PASS" : "FAIL") : "NA",
                     "đã chọn=\(chosen) · thông báo '\(msg)' · thanh Editing this còn=\(editingBar) · ô nhập '\(keep)' · lượt \(c0.map(String.init) ?? "—") → \(c1.map(String.init) ?? "—")")
        clearSelection(); clearInput(); dismissKeyboard()
    }

    func test16_keepDraftWhenViewing() {
        startChat()
        guard attachPhoto(1) || attachPhoto(4) else { G290.verdict("TC-CH08-009", "NA", "không kèm được ảnh"); return }
        type("draft one"); dismissKeyboard()
        let sigThumb = G290.regionSignature(app.images["xmark.circle.fill"].frame.insetBy(dx: -40, dy: -40))
        guard let f = resultFrames().last else { G290.verdict("TC-CH08-009", "NA", "không thấy kết quả"); return }
        at(f); G290.pause(app, 2.5)
        closeViewer()
        let still = app.images["xmark.circle.fill"].exists
        let same = still && G290.signatureDistance(sigThumb, G290.regionSignature(app.images["xmark.circle.fill"].frame.insetBy(dx: -40, dy: -40))) < 12
        snap("TC-CH08-009 — đóng màn xem không gửi")
        G290.verdict("TC-CH08-009", pass: same && inputText == "draft one", "ảnh kèm còn=\(still) (đúng ảnh=\(same)) · ô nhập '\(inputText)'")
        // TC-CH08-010 — gửi từ 902 khi ô soạn khung chat đang có ảnh kèm (1 lượt)
        if let f2 = resultFrames().last {
            at(f2); G290.pause(app, 2.5)
            type("make it brighter")
            at(app.images.matching(identifier: "arrow.up").allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }?.frame ?? .zero)
            _ = G290.waitUntil(app, timeout: 6) { !self.viewerOpen }
            let attachBack = app.images["xmark.circle.fill"].exists
            _ = waitIdle(); G290.pause(app, 2)
            snap("TC-CH08-010 — sau khi gửi từ màn xem")
            G290.verdict("TC-CH08-010", pass: attachBack && lastOutcome() == "result" && !editingBar,
                         "ảnh kèm trở lại ô soạn=\(attachBack) · câu trả lời cuối=\(lastOutcome()) · có kết quả nào được chọn lại=\(editingBar)")
        }
        if app.images["xmark.circle.fill"].exists { at(app.images["xmark.circle.fill"].frame) }
        clearInput(); dismissKeyboard()
    }

    func test17_offlineMidGenerationAndRetry() {
        startChat()
        let net = SettingsNetworkDriver { self.app }
        defer { _ = net.ensureOn() }
        clearInput(); type("a blue wooden house by a lake"); at(send.frame)
        guard G290.waitUntil(app, timeout: 10, { self.generating }) else { G290.verdict("TC-CH05-002", "NA", "không bắt đầu tạo"); return }
        let off = net.setAirplaneMode(true)
        G290.pause(app, 60)
        snap("TC-CH05-002 — mất mạng 60s khi đang tạo")
        _ = net.ensureOn(); openChat()
        _ = waitIdle(); G290.pause(app, 3)
        let out = lastOutcome()
        let retry = app.staticTexts.matching(NSPredicate(format: "label == 'Retry'")).allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }
        snap("TC-CH05-002 — có mạng lại")
        G290.verdict("TC-CH05-002", off ? ((out == "result" || (out == "error" && retry != nil)) ? "PASS" : "FAIL") : "NA",
                     "mất mạng 60s giữa lúc tạo → câu trả lời cuối=\(out) · nút Retry=\(retry != nil) (tiêu chí như BG01-015: hoàn tất hoặc lỗi có thử lại)")
        if out == "error", let r = retry {
            at(r.frame)
            let gen = G290.waitUntil(app, timeout: 10) { self.generating }
            _ = waitIdle(); G290.pause(app, 3)
            snap("TC-CH05-003 — bấm Retry")
            G290.verdict("TC-CH05-003", lastOutcome() == "result" ? "PASS" : "FAIL", "bấm Retry: bắt đầu tạo lại=\(gen) · câu trả lời cuối=\(lastOutcome())")
        }
    }

    func test18_videoContentAndOneThing() {
        startChat()
        // TC-CH02-018 + CH03-012 — video từ ảnh
        let c0 = badge(); openChat()
        _ = attachPhoto(2)
        clearInput(); type("make a video of this person waving"); at(send.frame)
        _ = G290.waitUntil(app, timeout: 10) { self.generating }
        G290.pause(app, 3)
        let hint = G290.visibleTexts(app).first { $0.localizedCaseInsensitiveContains("few minutes") } ?? "—"
        snap("TC-CH02-018 — đang tạo video")
        _ = waitIdle(480); G290.pause(app, 3)
        let out = lastOutcome()
        let play = app.images.allElementsBoundByIndex.contains { $0.exists && ($0.identifier.contains("play") || $0.label.lowercased().contains("play")) && $0.frame.minY > 100 && $0.frame.maxY < 720 }
        let c1 = badge(); openChat()
        snap("TC-CH02-018 — video về")
        G290.verdict("TC-CH02-018", out == "result" ? ((hint != "—" && play) ? "PASS" : "CHECK") : (out == "error" ? "FAIL" : "CHECK"),
                     "dòng báo chờ: '\(hint)' · câu trả lời cuối=\(out) · nút phát trên kết quả=\(play)")
        G290.verdict("TC-CH03-012", (c0 != nil && c1 != nil && out == "result") ? (c0! - c1! == 1 ? "PASS" : "FAIL") : "NA", "lượt \(c0.map(String.init) ?? "—") → \(c1.map(String.init) ?? "—") sau 1 video")
        // TC-CH05-005 — yêu cầu vi phạm nội dung
        let v = sendIdle("a graphic image of a person being stabbed with lots of blood")
        let refusal = app.staticTexts.allElementsBoundByIndex.filter { $0.exists && $0.frame.minX < 40 && $0.frame.minY > 120 && $0.frame.maxY < 720 && $0.label.count > 15 }.max { $0.frame.minY < $1.frame.minY }?.label ?? "—"
        snap("TC-CH05-005 — yêu cầu vi phạm")
        G290.verdict("TC-CH05-005", v.outcome != "result" && refusal != "—" ? "PASS" : (v.outcome == "result" ? "FAIL" : "CHECK"), "câu trả lời cuối=\(v.outcome) · chữ: '\(refusal.prefix(90))'")
        // TC-CH04-005 — câu > 160 ký tự có 'and' không bị tách
        let long = "Please create one calm photo of a small wooden cabin in a snowy pine forest at dusk with warm light in the windows and a thin trail of smoke rising and soft snow falling"
        let l = sendIdle(long)
        let pre = inputText
        snap("TC-CH04-005 — câu dài > 160 ký tự")
        G290.verdict("TC-CH04-005", l.outcome == "result" ? ((pre.isEmpty || pre == "What's on your mind?") ? "PASS" : "FAIL") : "NA", "câu \(long.count) ký tự · câu trả lời cuối=\(l.outcome) · ô nhập sau đó '\(pre)'")
        clearInput(); dismissKeyboard()
    }

    func test19_scrollAndChatTabAgain() {
        startChat()
        for _ in 0..<4 { app.swipeDown(velocity: .fast) }
        G290.pause(app, 1)
        let firstY = app.staticTexts.allElementsBoundByIndex.filter { $0.exists && $0.frame.minY > 90 }.map(\.frame.minY).min() ?? -1
        snap("TC-CH01-011 — kéo quá mép trên")
        G290.verdict("TC-CH01-011", firstY > 0 && firstY < 260 ? "PASS" : "CHECK", "sau khi vuốt nhanh lên đầu: phần tử đầu tiên ở y=\(Int(firstY)) (sát mép trên)")
        G290.openTab(app, "Chat"); G290.pause(app, 1.5)
        let bottomVisible = app.staticTexts.matching(NSPredicate(format: "label == 'Regenerate'")).allElementsBoundByIndex.contains { $0.exists && $0.frame.minY > 400 && $0.frame.maxY < 720 } || G290.visibleTexts(app).contains { $0.contains("Couldn") }
        snap("TC-CH01-004 — bấm tab Chat lần nữa")
        G290.verdict("TC-CH01-004", pass: bottomVisible, "bấm Chat khi đang ở Chat (đang ở đầu danh sách) → cuộn xuống tin nhắn cuối=\(bottomVisible)")
    }

    func test20_libraryAllProbe() {
        G290.openTab(app, "Library"); G290.pause(app, 4)
        let all = G290.anyLabeled(app, "All"); if all.exists { at(all.frame) }; G290.pause(app, 2)
        snap("TC-CH06-010 — Library All sau khi tạo trong Chat")
        dump("libAll")
        let conv = G290.anyLabeled(app, "Conversation"); if conv.exists { at(conv.frame) }; G290.pause(app, 2)
        snap("TC-CH06-010 — Library Conversation")
        dump("libConv")
    }

    // MARK: - Đợt 3

    func test21_e2eOnly() {
        startChat()
        let a = sendIdle("a cat in a garden")
        let b = sendIdle("make it night")
        var saved = false
        if let f = resultFrames().last {
            at(f); G290.pause(app, 2.5)
            let p0 = photoCount
            if let dl = app.buttons.matching(NSPredicate(format: "label == 'Download'")).allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minY < 120 }) { at(dl.frame) }
            saved = G290.waitUntil(app, timeout: 10) { self.photoCount > p0 }
            snap("TC-REG02-001 — lưu từ màn xem"); closeViewer()
        }
        G290.openTab(app, "Library"); G290.pause(app, 3)
        let all = G290.anyLabeled(app, "All"); if all.exists { at(all.frame) }; G290.pause(app, 2)
        let firstConv = G290.visibleTexts(app).first { $0.localizedCaseInsensitiveContains("cat in a garden") } ?? "—"
        snap("TC-REG02-001 — Library sau E2E")
        G290.verdict("TC-REG02-001", a.outcome == "result" && b.outcome == "result" && saved ? "PASS" : (a.outcome == "error" || b.outcome == "error" ? "CHECK" : "FAIL"),
                     "tạo=\(a.outcome) · sửa tiếp=\(b.outcome) · Lưu từ 902 vào Photos=\(saved) · Library có ô cuộc trò chuyện '\(firstConv)'")
    }

    func test22_oneThingImageThenVideoAndTyping() {
        startChat()
        let r = sendIdle("create an image of a cat then make a video of it running")
        let pre = inputText, bar = editingBar
        snap("TC-CH04-003 — ảnh rồi video")
        G290.verdict("TC-CH04-003", r.outcome == "result" ? ((pre.localizedCaseInsensitiveContains("video") && bar) ? "PASS" : "FAIL") : "CHECK",
                     "câu trả lời cuối=\(r.outcome) · ô nhập điền sẵn '\(pre)' · thanh Editing this=\(bar)")
        clearSelection(); clearInput(); dismissKeyboard()
        // TC-CH04-004 — gõ chữ trong lúc chờ kết quả của yêu cầu gộp
        _ = waitIdle(); clearInput(); type("create 2 images of a dog"); at(send.frame)
        _ = G290.waitUntil(app, timeout: 10) { self.generating }
        type("xyz")
        _ = waitIdle(); G290.pause(app, 3)
        let hint = G290.visibleTexts(app).first { $0.localizedCaseInsensitiveContains("one thing at a time") } ?? "—"
        snap("TC-CH04-004 — gõ chữ khi kết quả về")
        G290.verdict("TC-CH04-004", lastOutcome() == "result" ? (inputText == "xyz" ? (hint != "—" ? "PASS" : "FAIL") : "FAIL") : "CHECK",
                     "câu trả lời cuối=\(lastOutcome()) · ô nhập '\(inputText)' (giữ nguyên chữ đang gõ) · dòng nhắc '\(hint)'")
        clearInput(); dismissKeyboard()
    }

    func test23_i2iRegression() {
        G290.openTab(app, "Home")
        guard i2i.enterUpload(slots: 1...1) != nil else { G290.verdict("TC-REG02-002", "NA", "không vào được Upload i2i"); return }
        i2i.openPicker(); _ = SystemPermissionAlertHandler.tapButton("Allow Full Access", timeout: 4)
        guard PhotoPickerAutomator.pickPhoto(attempt: 2, in: app), i2i.waitUntil(timeout: 15, { self.i2i.isGenerateReady() }) else { G290.verdict("TC-REG02-002", "NA", "chọn ảnh không xong"); return }
        i2i.tap(i2i.generateButton)
        let result = app.descendants(matching: .any).matching(identifier: "i2i-result-screen").firstMatch
        let ok = i2i.waitUntil(timeout: 180) { result.exists }
        snap("TC-REG02-002 — Result i2i sau khi dùng Chat")
        if ok { i2i.tap(app.buttons["i2i-result-close"]); G290.pause(app, 2) }
        G290.verdict("TC-REG02-002", pass: ok, "luồng style i2i ở Home ra Result=\(ok) sau khi đã dùng Chat")
    }

    func test24_glassComposer() {
        startChat()
        // Cuộn để ảnh kết quả nằm ngay sau ô nhập, so vùng ô nhập lúc có ảnh phía sau và lúc nền tối.
        guard let comp = app.textFields.allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minX >= 50 })?.frame else { G290.verdict("TC-CH08-001", "NA", "không thấy ô nhập"); return }
        let band = CGRect(x: 20, y: comp.minY - 8, width: 350, height: comp.height + 16)
        app.swipeUp(); G290.pause(app, 1)
        var sigs: [[Double]] = []
        for _ in 0..<5 { sigs.append(G290.regionSignature(band)); app.swipeDown(velocity: XCUIGestureVelocity(300)); G290.pause(app, 1.2) }
        var maxD = 0.0
        for i in 0..<sigs.count { for j in i + 1..<sigs.count { maxD = max(maxD, G290.signatureDistance(sigs[i], sigs[j])) } }
        snap("TC-CH08-001 — ô nhập kính")
        G290.verdict("TC-CH08-001", maxD > 6 ? "PASS" : "CHECK", String(format: "vùng ô nhập đổi theo nội dung phía sau khi cuộn: khoảng cách lớn nhất %.1f (kính trong thấy mờ nội dung sau) · chữ/nút vẫn rõ: xem ảnh", maxD))
    }

    func test25_outOfCredits() {
        startChat()
        var shown = false, sends = 0
        while sends < 22 && !shown {
            sends += 1
            clearInput(); type("a tiny red dot on white, number \(sends)"); at(send.frame)
            shown = G290.waitUntil(app, timeout: 8) { self.app.alerts.count > 0 || G290.visibleTexts(self.app).contains { $0.localizedCaseInsensitiveContains("out of") || $0.localizedCaseInsensitiveContains("creations left") || $0.localizedCaseInsensitiveContains("Get More") } }
            if !shown { _ = waitIdle(); G290.pause(app, 2) }
        }
        let texts = G290.visibleTexts(app)
        print("OUTOFCREDIT|lần gửi \(sends)|\(texts.prefix(15))")
        snap("TC-CH03-008 — hết lượt")
        G290.verdict("TC-CH03-008", shown ? "PASS" : "NA", shown ? "sau \(sends) lần gửi: hộp thoại hết lượt hiện · chữ: \(texts.prefix(6))" : "gửi \(sends) lần chưa thấy hộp thoại hết lượt")
        guard shown else { return }
        let typed = "a tiny red dot on white, number \(sends)"
        // TC-CH03-010 — nút mua thêm mở màn nạp lượt
        let buy = (app.buttons.allElementsBoundByIndex + app.staticTexts.allElementsBoundByIndex).first { $0.exists && ($0.label.localizedCaseInsensitiveContains("get more") || $0.label.localizedCaseInsensitiveContains("top up") || $0.label.localizedCaseInsensitiveContains("buy")) }
        // TC-CH03-009 — đóng hộp thoại → về Chat, chữ còn
        let close = (app.buttons.allElementsBoundByIndex).first { $0.exists && ["Close", "Cancel", "Not now", "Later", "OK"].contains($0.label) }
        if let close { close.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap() }
        G290.pause(app, 2)
        snap("TC-CH03-009 — đóng hộp thoại hết lượt")
        G290.verdict("TC-CH03-009", pass: app.tabBars.buttons.count > 0 && inputText == typed, "đóng hộp thoại: về Chat=\(app.tabBars.buttons.count > 0) · ô nhập '\(inputText)' (giữ nguyên=\(inputText == typed))")
        at(send.frame); _ = G290.waitUntil(app, timeout: 8) { self.app.alerts.count > 0 || G290.visibleTexts(self.app).contains { $0.localizedCaseInsensitiveContains("Get More") || $0.localizedCaseInsensitiveContains("out of") } }
        let buy2 = (app.buttons.allElementsBoundByIndex + app.staticTexts.allElementsBoundByIndex).first { $0.exists && ($0.label.localizedCaseInsensitiveContains("get more") || $0.label.localizedCaseInsensitiveContains("top up") || $0.label.localizedCaseInsensitiveContains("buy")) }
        if let b = buy2 ?? buy, b.exists { b.tap() }
        let topup = G290.waitUntil(app, timeout: 8) { G290.visibleTexts(self.app).contains { $0.localizedCaseInsensitiveContains("Top-up") || $0.contains("Choose a Package") } || self.i2i.paywall.exists }
        snap("TC-CH03-010 — bấm mua thêm")
        G290.verdict("TC-CH03-010", pass: topup, "bấm nút mua thêm → màn nạp lượt mở=\(topup) · \(G290.visibleTexts(app).prefix(5))")
    }

    /// Máy đã hết lượt ngày: kiểm hộp thoại hết lượt rồi để màn nạp lượt mở cho tester mua topup.
    func test26_outOfCreditDialogButtons() {
        startChat()
        let typed = "a small green leaf"
        type(typed); at(send.frame)
        let dlg = G290.waitUntil(app, timeout: 8) { G290.visibleTexts(self.app).contains("Daily limit reached") }
        let during = inputText
        snap("TC-CH03-009 — hộp thoại hết lượt")
        guard dlg else { G290.verdict("TC-CH03-009", "NA", "không hiện hộp thoại hết lượt (còn lượt?)"); return }
        G290.anyLabeled(app, "Maybe later").tap(); G290.pause(app, 2)
        let after = inputText
        let sent = app.staticTexts[typed].exists
        snap("TC-CH03-009 — sau Maybe later")
        G290.verdict("TC-CH03-009", pass: !G290.visibleTexts(app).contains("Daily limit reached") && after == typed && !sent,
                     "Maybe later: hộp thoại đóng · ô nhập lúc hộp thoại hiện '\(during)' · sau khi đóng '\(after)' (spec: chữ đang gõ còn nguyên) · tin nhắn đã gửi=\(sent)")
        clearInput(); type(typed); at(send.frame)
        _ = G290.waitUntil(app, timeout: 8) { G290.visibleTexts(self.app).contains("Daily limit reached") }
        G290.anyLabeled(app, "Get more").tap()
        let topup = G290.waitUntil(app, timeout: 10) { G290.visibleTexts(self.app).contains { $0.contains("Top-up") || $0.contains("Choose a Package") } || self.i2i.paywall.exists }
        snap("TC-CH03-010 — Get more")
        G290.verdict("TC-CH03-010", pass: topup, "bấm Get more → màn nạp lượt mở=\(topup) · \(G290.visibleTexts(app).prefix(6))")
        print("TOPUP|╔ Màn nạp lượt đang mở — tester bấm Purchase + nhập mật khẩu (chờ 300s) ╗")
        _ = G290.waitUntil(app, timeout: 300) { SystemPermissionAlertHandler.tapButton("OK", timeout: 1) || self.app.buttons["OK"].exists }
        if app.buttons["OK"].exists { app.buttons["OK"].firstMatch.tap() }
        G290.pause(app, 3)
        snap("Sau khi mua topup")
        print("TOPUP|xong: \(G290.visibleTexts(app).prefix(6))")
    }

    // MARK: - Đợt 4

    /// TC-CH02-015 — quyền Photos = None: bấm dấu cộng → thông báo kèm nút mở Cài đặt. Trả Full Access sau đó.
    func test27_photoPermissionDenied() {
        let photos = SettingsPhotosDriver(appName: "Genius") { self.app }
        defer { _ = photos.setAccess("Full Access"); app.activate() }
        guard photos.setAccess("None") else { G290.verdict("TC-CH02-015", "NA", "không đặt được quyền Photos = None"); return }
        app.activate(); _ = app.wait(for: .runningForeground, timeout: 10)
        startChat()
        at(app.images.matching(identifier: "plus").allElementsBoundByIndex.first { $0.exists && $0.frame.minY > 500 }?.frame ?? .zero)
        G290.pause(app, 2.5)
        let texts = G290.visibleTexts(app)
        let settingsBtn = (app.buttons.allElementsBoundByIndex + app.staticTexts.allElementsBoundByIndex).first { $0.exists && ($0.label.localizedCaseInsensitiveContains("settings") || $0.label.localizedCaseInsensitiveContains("cài đặt")) && $0.frame.minY > 150 }
        snap("TC-CH02-015 — quyền Photos None, bấm dấu cộng")
        var openedSettings = false
        if let b = settingsBtn {
            at(b.frame)
            let pref = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            openedSettings = pref.wait(for: .runningForeground, timeout: 8)
            snap("TC-CH02-015 — bấm nút mở Cài đặt")
        }
        G290.verdict("TC-CH02-015", pass: settingsBtn != nil && openedSettings,
                     "thông báo: \(texts.filter { $0.count > 12 }.prefix(3)) · nút mở Cài đặt=\(settingsBtn?.label ?? "không") · mở app Settings=\(openedSettings)")
    }

    /// Bật/tắt Reduce Transparency trong Settings › Accessibility › Display & Text Size.
    private func setReduceTransparency(_ on: Bool) -> Bool {
        let pref = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        pref.terminate(); pref.activate(); _ = pref.wait(for: .runningForeground, timeout: 10)
        func tapRow(_ name: String) -> Bool {
            for _ in 0..<8 {
                let r = pref.staticTexts[name].firstMatch
                if r.exists && r.isHittable { r.tap(); G290.pause(app, 1.5); return true }
                pref.swipeUp(); G290.pause(app, 0.6)
            }
            return false
        }
        guard tapRow("Accessibility"), tapRow("Display & Text Size") else { return false }
        for _ in 0..<4 {
            let sw = pref.switches["Reduce Transparency"].firstMatch
            if sw.exists {
                if ((sw.value as? String) == "1") != on { sw.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap(); G290.pause(app, 1) }
                return ((sw.value as? String) == "1") == on
            }
            pref.swipeUp(); G290.pause(app, 0.6)
        }
        return false
    }

    /// TC-CH08-002 — bật Reduce Transparency: vùng ô nhập không đổi theo nội dung phía sau.
    func test28_reduceTransparency() {
        defer { _ = setReduceTransparency(false); app.activate() }
        guard setReduceTransparency(true) else { G290.verdict("TC-CH08-002", "NA", "không bật được Reduce Transparency"); return }
        app.activate(); _ = app.wait(for: .runningForeground, timeout: 10)
        startChat()
        guard let comp = app.textFields.allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minX >= 50 })?.frame else { G290.verdict("TC-CH08-002", "NA", "không thấy ô nhập"); return }
        let band = CGRect(x: 30, y: comp.minY + 2, width: 200, height: max(comp.height - 4, 10))
        var sigs: [[Double]] = []
        for _ in 0..<5 { sigs.append(G290.regionSignature(band)); app.swipeDown(velocity: XCUIGestureVelocity(300)); G290.pause(app, 1.2) }
        var maxD = 0.0
        for i in 0..<sigs.count { for j in i + 1..<sigs.count { maxD = max(maxD, G290.signatureDistance(sigs[i], sigs[j])) } }
        snap("TC-CH08-002 — Reduce Transparency bật")
        G290.verdict("TC-CH08-002", maxD < 6 ? "PASS" : "FAIL", String(format: "bật Reduce Transparency: vùng ô nhập khi cuộn nội dung phía sau — khoảng cách lớn nhất %.1f (nền đặc ⇒ gần 0)", maxD))
    }

    /// TC-CH03-010 — gửi tới khi hết lượt, bấm Get more → màn nạp lượt.
    func test29_getMoreOpensTopup() {
        startChat()
        var shown = false, n = 0
        while n < 12 && !shown {
            n += 1
            clearInput(); type("a tiny blue dot, try \(n)"); at(send.frame)
            shown = G290.waitUntil(app, timeout: 8) { G290.visibleTexts(self.app).contains("Daily limit reached") }
            if !shown { _ = waitIdle(); G290.pause(app, 2) }
        }
        guard shown else { G290.verdict("TC-CH03-010", "NA", "gửi \(n) lần chưa hết lượt"); return }
        snap("TC-CH03-010 — hộp thoại hết lượt")
        G290.anyLabeled(app, "Get more").tap()
        let topup = G290.waitUntil(app, timeout: 10) { G290.visibleTexts(self.app).contains { $0.contains("Top-up") || $0.contains("Choose a Package") } || self.i2i.paywall.exists }
        snap("TC-CH03-010 — Get more")
        G290.verdict("TC-CH03-010", pass: topup, "sau \(n) lần gửi hết lượt · bấm Get more → màn nạp lượt mở=\(topup) · \(G290.visibleTexts(app).prefix(5))")
    }

    /// Dọn máy: trả quyền Photos = Full Access, tắt Reduce Transparency.
    func test30_restoreDeviceSettings() {
        let ok = SettingsPhotosDriver(appName: "Genius") { self.app }.setAccess("Full Access")
        let rt = setReduceTransparency(false)
        print("RESTORE|photos FullAccess=\(ok)|reduceTransparency off=\(rt)")
    }
}
