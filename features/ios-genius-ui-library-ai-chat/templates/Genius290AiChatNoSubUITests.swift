import XCTest

/// AI Chat 2.9.0 — nhóm chạy khi máy KHÔNG có gói (0 lượt): trạng thái trống, thanh soạn, chuỗi
/// chào bán 236 → 238 → 237, dải `Try the newest vibes`. Nút gửi là ảnh `arrow.up` không mang
/// trạng thái bật/tắt, nên "bật" đo bằng hành vi: user không gói bấm gửi khi nút bật thì ra paywall,
/// nút tắt thì không có gì xảy ra. Bật bằng `TEST_RUNNER_RUN_G290_CHAT_NOSUB=1`.
final class Genius290AiChatNoSubUITests: XCTestCase {

    private var app: XCUIApplication!
    private var i2i: I2IJourneyDriver!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_G290_CHAT_NOSUB"] == "1", "Bật bằng TEST_RUNNER_RUN_G290_CHAT_NOSUB=1.")
        continueAfterFailure = true
        app = I2IJourneyDriver.launchApp()
        i2i = I2IJourneyDriver(app: app)
        XCTAssertTrue(G290.reachMain(app), "không vào được luồng chính")
    }

    // MARK: - Element của màn Chat

    private var input: XCUIElement { app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch }
    private var send: XCUIElement { app.images["arrow.up"].firstMatch }
    private var plus: XCUIElement { app.images["plus"].firstMatch }
    private var inputText: String { (input.value as? String) ?? "" }
    private let chips = ["Make a birthday card from my photo", "Turn my photo into a film", "Try a black-and-white look"]
    private func at(_ f: CGRect) { app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap() }
    private func texts() -> [String] { G290.visibleTexts(app) }

    private func openChat() {
        G290.openTab(app, "Chat"); G290.pause(app, 2)
        if app.keyboards.count > 0 { app.staticTexts["What's on your mind?"].firstMatch.tap() }
    }
    private var isEmptyInput: Bool { inputText.isEmpty || inputText == "What's on your mind?" }
    /// Xoá sạch ô nhập: chạm sát mép phải để con trỏ về cuối chữ (chạm giữa dòng thì xoá thiếu),
    /// xoá theo lô, đọc lại tới khi rỗng.
    private func clearInput() {
        guard input.exists else { return }
        for _ in 0..<12 where !isEmptyInput {
            input.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.9)).tap()
            input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: min(inputText.count + 5, 300)))
        }
    }
    /// Nhãn mọi element đang thấy (đọc từ một snapshot, tránh lỗi element theo chỉ số biến mất).
    private func allLabels() -> [String] {
        guard let root = try? app.snapshot() else { return [] }
        var out: [String] = [], st: [XCUIElementSnapshot] = [root]
        while let n = st.popLast() { if !n.label.isEmpty { out.append(n.label) }; st.append(contentsOf: n.children) }
        return out
    }
    /// Chiều cao ô soạn: lấy ô nhập (textField/textView) cao nhất nằm ở nửa dưới màn.
    private func inputHeight() -> CGFloat {
        (app.textFields.allElementsBoundByIndex + app.textViews.allElementsBoundByIndex).map(\.frame).filter { $0.minY > 300 }.map(\.height).max() ?? 0
    }
    /// Bấm gửi rồi xem có paywall không (user không gói ⇒ nút bật thì ra paywall).
    private func sendOpensPaywall() -> Bool {
        at(send.frame)
        return i2i.waitUntil(timeout: 6) { self.i2i.paywall.exists }
    }
    /// Đóng paywall đang mở; trả chữ đầu màn kế tiếp để biết đang ở 238 / 237 / Chat.
    private func closeStep() -> String {
        i2i.dismissPaywall(); G290.pause(app, 3)
        let t = texts()
        if i2i.paywall.exists { return "paywall: \(t.prefix(6).joined(separator: " · "))" }
        if t.contains(where: { $0.contains("Top-up") || $0.contains("topup") }) { return "topup: \(t.prefix(6).joined(separator: " · "))" }
        return app.tabBars.buttons["Chat"].exists ? "chat" : "khác: \(t.prefix(6).joined(separator: " · "))"
    }

    // MARK: - TC-CH03 chuỗi chào bán (chạy đầu tiên trong ngày: 237 chỉ chào 1 lần/ngày)

    func test01_paywallChain() {
        openChat()
        let prompt = "a cat in a garden"
        input.tap(); input.typeText(prompt)
        let pw = sendOpensPaywall()
        let t236 = texts().prefix(8).joined(separator: " · ")
        snap("TC-CH03-001 — bấm gửi khi chưa có gói")
        let bubbles = app.staticTexts.matching(NSPredicate(format: "label == %@", prompt)).count
        G290.verdict("TC-CH03-001", pass: pw, "bấm gửi → paywall=\(pw) · chữ trên màn: \(t236)")
        guard pw else { return }
        var steps: [String] = []
        for _ in 0..<4 {
            let s = closeStep(); steps.append(s)
            snap("TC-CH03 — sau lần đóng \(steps.count)")
            if s == "chat" { break }
        }
        print("PAYWALLCHAIN|\(steps)")
        let second = steps.first ?? "—"
        G290.verdict("TC-CH03-002", second.hasPrefix("paywall") ? "PASS" : "FAIL", "đóng 236 → \(second) (spec: last chance 238)")
        let third = steps.count > 1 ? steps[1] : "—"
        G290.verdict("TC-CH03-003", third.hasPrefix("topup") || third.hasPrefix("paywall") ? "PASS" : "FAIL", "đóng 238 → \(third) (spec: topup 237, lần chào đầu trong ngày)")
        let back = steps.last == "chat"
        let kept = inputText == prompt
        let sentNow = app.staticTexts.matching(NSPredicate(format: "label == %@", prompt)).count
        snap("TC-CH03-004 — về Chat sau chuỗi chào bán")
        G290.verdict("TC-CH03-004", pass: back && kept && sentNow <= bubbles,
                     "chuỗi: \(steps.joined(separator: " → ")) · về Chat=\(back) · ô nhập='\(inputText)' (giữ nguyên=\(kept)) · tin nhắn đã gửi: \(sentNow - bubbles)")
        // TC-CH03-005 — lần thứ hai trong ngày không chào topup
        guard sendOpensPaywall() else { G290.verdict("TC-CH03-005", "NA", "lần 2 không mở paywall"); return }
        var steps2: [String] = []
        for _ in 0..<4 { let s = closeStep(); steps2.append(s); if s == "chat" { break } }
        snap("TC-CH03-005 — lần 2 trong ngày")
        G290.verdict("TC-CH03-005", pass: !steps2.contains { $0.hasPrefix("topup") } && steps2.last == "chat",
                     "lần 2: \(steps2.joined(separator: " → ")) · có chào topup=\(steps2.contains { $0.hasPrefix("topup") })")
    }

    // MARK: - TC-CH01 trạng thái trống + TC-CH02 thanh soạn

    func test02_emptyStateAndComposer() {
        openChat()
        let t = texts()
        let title = app.staticTexts.allElementsBoundByIndex.first { $0.exists && $0.frame.minY < 120 && $0.frame.minY > 40 }
        let titleText = title?.label ?? "—", titleCentered = title.map { abs($0.frame.midX - 195) < 30 } ?? false
        let greeting = t.contains("What's on your mind?")
        let chipFrames = chips.compactMap { c in app.staticTexts[c].exists ? app.staticTexts[c].frame : nil }
        let vertical = chipFrames.count == 3 && zip(chipFrames, chipFrames.dropFirst()).allSatisfy { $1.minY > $0.maxY - 2 && abs($1.minX - $0.minX) < 4 }
        let more = app.buttons["More"].exists && app.buttons["More"].frame.minX > 300
        snap("TC-CH01-001 — Chat trống")
        G290.verdict("TC-CH01-001", greeting && chipFrames.count == 3 && vertical && plus.exists && send.exists && more ? (titleText == "Chat" && titleCentered ? "PASS" : "MISMATCH") : "FAIL",
                     "tiêu đề '\(titleText)' (giữa=\(titleCentered); spec 'Chat' ở giữa) · nút ba chấm góc phải=\(more) · câu chào=\(greeting) · 3 chip xếp dọc canh trái=\(vertical) (\(chipFrames.count)/3) · dấu cộng=\(plus.exists) · nút gửi=\(send.exists)")
        let chipIcons = chips.filter { c in app.staticTexts[c].exists }.count == 3 && !app.images.allElementsBoundByIndex.contains { img in
            img.exists && chipFrames.contains { $0.insetBy(dx: -30, dy: 0).intersects(img.frame) }
        }
        G290.verdict("TC-CH01-002", pass: chipIcons, "3 chip chỉ có chữ, không có ảnh/icon trong vùng chip=\(chipIcons)")

        // TC-CH01-003 — tab Chat đang chọn, tím, thanh tab còn
        let tab = app.tabBars.buttons["Chat"]
        let purple = G290.purpleFraction(of: tab)
        G290.verdict("TC-CH01-003", pass: tab.isSelected && purple > 0.02 && app.tabBars.count > 0,
                     "tab Chat được chọn=\(tab.isSelected) · pixel tím \(String(format: "%.1f%%", purple * 100)) · thanh tab hiện=\(app.tabBars.count > 0)")

        // TC-CH01-006 — bấm chip điền vào ô nhập, chưa gửi
        if let f = chipFrames.dropFirst().first { at(f) }
        G290.pause(app, 1.5)
        let filled = inputText == chips[1], keyboard = app.keyboards.count > 0
        snap("TC-CH01-006 — bấm chip")
        G290.verdict("TC-CH01-006", pass: filled && keyboard && !i2i.paywall.exists,
                     "ô nhập='\(inputText)' · bàn phím mở=\(keyboard) · paywall/gửi đi=\(i2i.paywall.exists) · chip vẫn còn trên màn=\(app.staticTexts[chips[0]].exists)")

        // TC-CH02-001/002/003 — nút gửi theo nội dung ô nhập
        clearInput()
        let emptyOpens = sendOpensPaywall(); if emptyOpens { _ = closeAll() }
        G290.verdict("TC-CH02-001", pass: !emptyOpens, "ô nhập trống, bấm gửi → có phản ứng (paywall)=\(emptyOpens)")
        input.tap(); input.typeText("     ")
        let spaceOpens = sendOpensPaywall(); if spaceOpens { _ = closeAll() }
        G290.verdict("TC-CH02-002", pass: !spaceOpens, "5 dấu cách, bấm gửi → có phản ứng=\(spaceOpens)")
        clearInput(); input.typeText("a")
        let oneOpens = sendOpensPaywall()
        snap("TC-CH02-003 — 1 ký tự rồi bấm gửi")
        if oneOpens { _ = closeAll() }
        G290.verdict("TC-CH02-003", pass: oneOpens, "gõ 'a', bấm gửi → nút bật (user không gói ra paywall)=\(oneOpens)")

        // TC-CH02-005/006 — giới hạn 1000 ký tự
        clearInput()
        input.typeText(String(repeating: "a", count: 1000))
        let len1000 = inputText.count
        input.typeText("bc")
        G290.pause(app, 1)
        let len1001 = inputText.count
        let hint = texts().first { $0.contains("1000") } ?? "—"
        snap("TC-CH02-006 — dán quá 1000 ký tự")
        G290.verdict("TC-CH02-005", pass: len1000 == 1000, "gõ 1000 ký tự → ô nhập giữ \(len1000)")
        G290.verdict("TC-CH02-006", pass: len1001 == 1000 && hint != "—", "gõ thêm 2 ký tự → ô nhập \(len1001) ký tự · dòng nhắc: '\(hint)' (spec: 'Tối đa 1000 ký tự')")

        // TC-CH02-007 — ô nhập cao theo số dòng tới mức giới hạn
        clearInput()
        let h0 = inputHeight()
        input.typeText("line1\nline2\nline3")
        let h3 = inputHeight()
        input.typeText("\nline4\nline5\nline6\nline7\nline8\nline9\nline10")
        let h10 = inputHeight()
        snap("TC-CH02-007 — ô nhập 10 dòng")
        G290.verdict("TC-CH02-007", pass: h3 > h0 && h10 >= h3 && h10 < 400,
                     String(format: "chiều cao ô nhập: 1 dòng %.0f → 3 dòng %.0f → 10 dòng %.0f pt (có giới hạn=%@)", h0, h3, h10, h10 < 400 ? "có" : "không"))
        clearInput()

        // TC-CH02-008..011 — dấu cộng, ô thu nhỏ, thay tệp, bỏ tệp
        at(plus.frame); _ = SystemPermissionAlertHandler.tapButton("Allow Full Access", timeout: 4); G290.pause(app, 3)
        let pickerLabels = allLabels()
        let hasVideo = pickerLabels.contains { $0.localizedCaseInsensitiveContains("video") }, hasPhoto = pickerLabels.contains { $0.localizedCaseInsensitiveContains("photo") }
        snap("TC-CH02-008 — thư viện mở từ dấu cộng")
        G290.verdict("TC-CH02-008", hasVideo && hasPhoto ? "PASS" : "CHECK", "thư viện mở · thấy ô ảnh=\(hasPhoto) · thấy ô video=\(hasVideo)")
        _ = i2i.dismissPicker()
        at(plus.frame); G290.pause(app, 2)
        let picked = PhotoPickerAutomator.pickPhoto(attempt: 1, in: app); G290.pause(app, 2)
        let thumbX = app.images["xmark.circle.fill"].firstMatch
        snap("TC-CH02-009 — đã kèm 1 ảnh")
        G290.verdict("TC-CH02-009", pass: picked && thumbX.exists, "chọn ảnh=\(picked) · ô thu nhỏ có nút x=\(thumbX.exists)")
        // TC-CH02-004 — chỉ kèm ảnh, chưa gõ chữ → nút gửi tắt
        let imgOnlyOpens = sendOpensPaywall(); if imgOnlyOpens { _ = closeAll() }
        G290.verdict("TC-CH02-004", pass: thumbX.exists && !imgOnlyOpens, "chỉ kèm ảnh, bấm gửi → có phản ứng=\(imgOnlyOpens)")
        let sigA = G290.regionSignature(thumbX.exists ? thumbX.frame.insetBy(dx: -40, dy: -40) : .zero)
        at(plus.frame); G290.pause(app, 2)
        let picked2 = PhotoPickerAutomator.pickPhoto(attempt: 10, in: app); G290.pause(app, 2)
        let thumbs = app.images.matching(identifier: "xmark.circle.fill").count
        let sigB = G290.regionSignature(thumbX.exists ? thumbX.frame.insetBy(dx: -40, dy: -40) : .zero)
        snap("TC-CH02-010 — chọn tệp khác")
        G290.verdict("TC-CH02-010", pass: picked2 && thumbs == 1 && G290.signatureDistance(sigA, sigB) > 8,
                     String(format: "chọn ảnh khác=%@ · số ô thu nhỏ=%d · ảnh đổi (khoảng cách %.0f)", picked2 ? "true" : "false", thumbs, G290.signatureDistance(sigA, sigB)))
        input.tap(); input.typeText("keep me")
        if thumbX.exists { at(thumbX.frame) }; G290.pause(app, 1)
        snap("TC-CH02-011 — bấm x bỏ tệp")
        G290.verdict("TC-CH02-011", pass: !app.images["xmark.circle.fill"].exists && inputText == "keep me", "sau khi bấm x: ô thu nhỏ còn=\(app.images["xmark.circle.fill"].exists) · ô nhập='\(inputText)'")
        clearInput()
    }

    /// Đóng hết chuỗi paywall về Chat.
    private func closeAll() -> [String] {
        var s: [String] = []
        for _ in 0..<4 where i2i.paywall.exists || !app.tabBars.buttons["Chat"].exists { s.append(closeStep()) }
        return s
    }

    // MARK: - VB01 dải Try the newest vibes

    func test03_vibesStrip() {
        G290.openTab(app, "Home"); app.swipeDown(); app.swipeDown(); G290.pause(app, 3)
        let defaults = ["Cinematic", "Polaroid", "Black and White", "Retro", "Golden Hour", "Neon Night", "Oil Painting"]
        let t = texts()
        let strip = t.first { $0.localizedCaseInsensitiveContains("newest vibes") }
        let seen = defaults.filter { d in t.contains(d) }
        let firstSection = app.staticTexts.allElementsBoundByIndex.first { $0.exists && $0.frame.minX < 60 && $0.frame.minY > 150 && $0.frame.minY < 700 && !$0.label.isEmpty && !["For You", "Trending", "New", "Motion", "Genius", "Pro"].contains($0.label) }?.label ?? "—"
        snap("TC-VB01-002 — Home For You, đầu tab")
        print("VIBES|dải=\(strip ?? "không")|mặc định thấy=\(seen)|dải đầu=\(firstSection)")
        G290.verdict("TC-VB01-002", strip != nil && seen.count == 7 ? "PASS" : "FAIL",
                     "CMS chưa dựng category 'vibes': dải 'Try the newest vibes' hiện=\(strip != nil) · phong cách mặc định thấy \(seen.count)/7 · dải đầu tab For You là '\(firstSection)'")
    }

    // MARK: - Không gói: 902, ví topup, mua gói trên 236

    private var chatInputs: [XCUIElement] { app.textFields.allElementsBoundByIndex.filter { $0.exists } }
    /// Ô kết quả đầu tiên đang thấy trong khung chat (vùng ảnh trên hàng Save).
    private func firstResultFrame() -> CGRect? {
        app.staticTexts.matching(NSPredicate(format: "label == 'Save'")).allElementsBoundByIndex.filter { $0.exists && $0.frame.minY > 300 && $0.frame.minY < 720 }
            .map { CGRect(x: 24, y: $0.frame.minY - 230, width: 220, height: 200) }.first
    }

    /// TC-CH08-007 — người chưa mua gói gõ + gửi từ 902 → paywall, không trừ lượt.
    func test04_paywallFrom902() {
        openChat()
        if firstResultFrame() == nil { app.swipeDown(); G290.pause(app, 1) }
        guard let f = firstResultFrame() else { G290.verdict("TC-CH08-007", "NA", "cuộc trò chuyện không có kết quả để mở 902"); return }
        at(f); G290.pause(app, 2.5)
        guard app.tabBars.buttons.count == 0, let v = chatInputs.first(where: { $0.frame.minX < 50 }) else { G290.verdict("TC-CH08-007", "NA", "không mở được màn xem 902"); return }
        v.tap(); v.typeText("add a hat")
        at(app.images.matching(identifier: "arrow.up").allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }?.frame ?? .zero)
        let pw = i2i.waitUntil(timeout: 8) { self.i2i.paywall.exists }
        snap("TC-CH08-007 — gửi từ 902 khi chưa có gói")
        G290.verdict("TC-CH08-007", pass: pw, "gửi từ 902 → paywall=\(pw) · \(G290.visibleTexts(app).prefix(4))")
        _ = closeAll()
    }

    /// TC-CH03-006 — chưa mua gói nhưng ví topup ≥1: đóng 236 → 238 thì yêu cầu tự gửi, không chào 237.
    func test05_topupWalletSendsAfterChain() {
        openChat(); clearInput()
        let prompt = "a yellow rubber duck"
        input.tap(); input.typeText(prompt)
        guard sendOpensPaywall() else { G290.verdict("TC-CH03-006", "NA", "bấm gửi không ra paywall (còn gói?)"); return }
        var steps: [String] = []
        for _ in 0..<3 {
            i2i.dismissPaywall(); G290.pause(app, 3)
            if i2i.paywall.exists { steps.append(G290.visibleTexts(app).contains { $0.contains("Still not ready") } ? "topup" : "paywall"); continue }
            steps.append("chat"); break
        }
        let sent = G290.waitUntil(app, timeout: 15) { self.app.images["sparkles"].exists || G290.visibleTexts(self.app).contains { $0.hasPrefix("Replying") } || self.app.staticTexts[prompt].exists }
        snap("TC-CH03-006 — đóng chuỗi khi ví còn topup")
        G290.verdict("TC-CH03-006", pass: !steps.contains("topup") && sent,
                     "chuỗi đóng: \(steps) · không chào topup=\(!steps.contains("topup")) · yêu cầu tự gửi đi=\(sent)")
    }

    /// TC-CH03-007 — mua gói ngay trên 236 → đóng paywall, yêu cầu tự gửi (tester nhập mật khẩu).
    func test06_buySubOn236() {
        openChat(); clearInput()
        let prompt = "a green apple on a plate"
        input.tap(); input.typeText(prompt)
        guard sendOpensPaywall() else { G290.verdict("TC-CH03-007", "NA", "bấm gửi không ra paywall"); return }
        snap("TC-CH03-007 — paywall 236")
        print("CHAT|╔ Tester: mua gói trên paywall đang mở, nhập mật khẩu sandbox (chờ 300s) ╗")
        let bought = G290.waitUntil(app, timeout: 300) { SystemPermissionAlertHandler.tapButton("OK", timeout: 1) || !self.i2i.paywall.exists }
        G290.pause(app, 4)
        let sent = G290.waitUntil(app, timeout: 20) { self.app.images["sparkles"].exists || G290.visibleTexts(self.app).contains { $0.hasPrefix("Replying") } || self.app.staticTexts[prompt].exists }
        snap("TC-CH03-007 — sau khi mua gói")
        G290.verdict("TC-CH03-007", bought ? (sent ? "PASS" : "FAIL") : "NA", "mua gói / paywall đóng=\(bought) · yêu cầu tự gửi đi=\(sent)")
    }
}
