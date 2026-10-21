import XCTest

/// Event tracking màn 910 Library + khay tạo nền (spec `genius-eventtracking-library.xlsx`, bản 2.9.0).
///
/// Suite KHÔNG tự chấm event: trên máy thật test không đọc được sandbox của app. App ghi mọi event
/// vào `~/Documents/<sink>.jsonl` (EVENT_SINK_PATH, xem `AnalyticsTracker`), script kéo file về bằng
/// `devicectl copy from` rồi `evaluate-event-tracking-library.py` ghép event với các mốc
/// `ETSTEP|<bước>|<epoch ms>` in ra ở đây — mỗi mốc in NGAY TRƯỚC thao tác của bước đó.
/// Bật bằng `TEST_RUNNER_RUN_G290_ET_LIB=1`.
final class Genius290EventTrackingLibraryUITests: XCTestCase {

    private var app: XCUIApplication!
    private var i2i: I2IJourneyDriver!
    private var i2v: I2VJourneyDriver!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_G290_ET_LIB"] == "1", "Bật bằng TEST_RUNNER_RUN_G290_ET_LIB=1.")
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        let sink = "et-\(name.components(separatedBy: " ").last?.trimmingCharacters(in: CharacterSet(charactersIn: "]")) ?? "run")-\(Int(Date().timeIntervalSince1970)).jsonl"
        app.launchEnvironment["EVENT_SINK_PATH"] = "~/Documents/\(sink)"
        print("ETSINK|Documents/\(sink)")
        app.launch()
        i2i = I2IJourneyDriver(app: app)
        i2v = I2VJourneyDriver(app: app)
        XCTAssertTrue(G290.reachMain(app), "không tới được luồng chính")
    }

    // MARK: - Mốc + thao tác

    private func step(_ label: String) { print("ETSTEP|\(label)|\(Int64(Date().timeIntervalSince1970 * 1000))") }
    private func note(_ key: String, _ value: String) { print("ETNOTE|\(key)|\(value.replacingOccurrences(of: "\n", with: " "))") }

    /// Chốt frame một lần rồi bấm toạ độ tuyệt đối (neo vào element sẽ throw nếu element biến mất).
    @discardableResult
    private func tapText(_ label: String, minY: CGFloat = 0) -> Bool {
        let el = (app.buttons.allElementsBoundByIndex + app.staticTexts.allElementsBoundByIndex)
            .first { $0.exists && $0.label == label && $0.frame.minY >= minY && !$0.frame.isEmpty }
        guard let f = el?.frame else { print("⚠️ không thấy '\(label)'"); return false }
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
        return true
    }
    private func at(_ x: CGFloat, _ y: CGFloat) { app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap() }

    /// Nút ··· của các ô đang hiện trên lưới, theo thứ tự đọc.
    private var moreButtons: [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { $0.exists && $0.label == "More" && $0.frame.minY > 140 && $0.frame.maxY < 740 }
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
    }
    private var trayText: String? { G290.visibleTexts(app).first { $0.contains("Creating") || $0.contains("Ready") || $0.contains("Couldn") } }
    private var isEmptyState: Bool { app.staticTexts["Nothing here yet."].exists }
    private var onLibrary: Bool { G290.anyLabeled(app, "All").exists && G290.anyLabeled(app, "Photo").exists }
    private func back() {
        if let b = app.buttons.allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minX < 70 && $0.frame.minY > 30 && $0.frame.minY < 140 && $0.frame.width < 70 }) { i2i.tap(b) }
        else { at(35, 70) }
        G290.pause(app, 1.5)
    }
    /// Rời màn đang mở về thanh tab (Result / Chat / Generating).
    private func backToTabs() {
        for _ in 0..<3 where !app.tabBars.buttons["Library"].isHittable { back() }
    }

    // MARK: - 1. Duyệt Library (không xoá, không tốn credit)

    func test01_browseFilterSelectDeleteCancel() {
        step("open_library"); G290.openTab(app, "Library"); G290.pause(app, 5)
        note("empty_state", "\(isEmptyState)"); note("more_count", "\(moreButtons.count)")
        snap("ET — Library mở lần đầu")
        if isEmptyState {
            step("start_creating"); tapText("Start creating"); G290.pause(app, 3)
            snap("ET — bấm Start creating"); backToTabs(); G290.openTab(app, "Library"); G290.pause(app, 4)
        }
        guard !isEmptyState, moreButtons.count >= 2 else { note("abort", "Library có <2 ô — bỏ các bước lọc/chọn/xoá"); return }

        for (label, key) in [("Photo", "image"), ("Video", "video"), ("Conversation", "conversation"), ("All", "all")] {
            step("filter_\(key)"); tapText(label); G290.pause(app, 2.5)
        }
        step("filter_all_again"); tapText("All"); G290.pause(app, 2)   // đang ở All: chạm lại không đổi lọc

        step("select"); tapText("Select"); G290.pause(app, 1.5)
        snap("ET — chế độ chọn")
        step("select_cancel"); tapText("Cancel"); G290.pause(app, 1.5)

        // Xoá từ menu ··· rồi Cancel trên hộp thoại — không mất dữ liệu.
        if let more = moreButtons.first {
            step("item_menu_delete"); i2i.tap(more); G290.pause(app, 1)
            tapText("Delete"); G290.pause(app, 1.5)
            snap("ET — hộp thoại xoá 1 ô")
            step("dialog_cancel_one")
            if app.alerts.buttons["Cancel"].exists { app.alerts.buttons["Cancel"].firstMatch.tap() } else { tapText("Cancel") }
            G290.pause(app, 1.5)
        }

        // Chọn nhiều 2 ô → Delete → Cancel.
        // Nút ··· ẩn trong chế độ chọn → chốt vị trí ô TRƯỚC khi bấm Select.
        let cells = moreButtons.prefix(2).map { $0.frame }
        step("select_multi"); tapText("Select"); G290.pause(app, 1.5)
        cells.forEach { at($0.midX - 45, $0.midY + 70); G290.pause(app, 0.6) }
        note("selected_title", app.staticTexts.allElementsBoundByIndex.first { $0.exists && $0.label.contains("selected") }?.label ?? "—")
        step("multi_delete"); tapText("Delete", minY: 600); G290.pause(app, 1.5)
        snap("ET — hộp thoại xoá 2 ô")
        step("dialog_cancel_multi")
        if app.alerts.buttons["Cancel"].exists { app.alerts.buttons["Cancel"].firstMatch.tap() } else { tapText("Cancel") }
        G290.pause(app, 1.5)
        step("select_cancel_multi"); tapText("Cancel"); G290.pause(app, 1.5)

        // Mở 1 ô media → Result, rồi quay lại.
        tapText("Photo"); G290.pause(app, 2.5)
        if let f = moreButtons.first?.frame {
            step("item_open_media"); at(f.midX - 45, f.midY + 70); G290.pause(app, 4)
            snap("ET — mở ô ảnh"); note("after_item_open_media", G290.visibleTexts(app, limit: 15).joined(separator: " · "))
            step("back_from_media"); backToTabs(); G290.pause(app, 3)
        }

        // Mở 1 ô cuộc trò chuyện → tab Chat.
        if !onLibrary { G290.openTab(app, "Library"); G290.pause(app, 3) }
        tapText("Conversation"); G290.pause(app, 3)
        if let f = moreButtons.first?.frame {
            step("item_open_conversation"); at(f.midX - 45, f.midY + 40); G290.pause(app, 4)
            snap("ET — mở ô cuộc trò chuyện"); note("after_item_open_conversation", G290.visibleTexts(app, limit: 15).joined(separator: " · "))
            backToTabs()
        } else { note("conversation", "lọc Conversation không có ô nào") }

        // Rời tab có đo thời gian ở màn, rồi vào lại tab.
        step("reenter_library"); G290.openTab(app, "Library"); G290.pause(app, 6)
        step("leave_to_home"); G290.openTab(app, "Home"); G290.pause(app, 2)
        step("end")
    }

    // MARK: - 2. Khay tạo nền + ô đang tạo + xoá thật (1 credit video + 1 credit ảnh)

    func test02_genTrayPendingAndRealDelete() {
        G290.openTab(app, "Home")
        step("start_video")
        guard i2v.enterVideoUploadAnyRoute(), i2v.pickPhotosUntilReady(), i2v.startGenerate() else {
            note("abort", i2v.common.paywall.exists ? "ra paywall — hết sub/credit" : "không bắt đầu được lượt video"); return
        }
        // `startGenerate` vẫn trả true khi Generate bung paywall (hết gói/lượt) — chặn lại ở đây.
        guard !i2v.common.paywall.exists else { note("abort", "Generate ra paywall — hết sub/credit"); return }
        step("leave_video_generating")
        if i2v.generatingBackButton.exists { i2v.tap(i2v.generatingBackButton) } else { back() }
        G290.pause(app, 2); note("tray_after_leave_video", trayText ?? "—"); snap("ET — khay sau khi rời Generating video")

        // Lượt ảnh song song → khay 2 lượt.
        step("start_image")
        if i2i.enterUpload(slots: 1...1) != nil {
            i2i.openPicker()
            if PhotoPickerAutomator.pickPhoto(attempt: 3, in: app), i2i.waitUntil(timeout: 15, { self.i2i.isGenerateReady() }) {
                i2i.tap(i2i.generateButton)
                _ = G290.waitUntil(app, timeout: 10) { self.app.staticTexts["Generating"].exists }
                step("leave_image_generating"); at(35, 70); G290.pause(app, 1.5)
                note("tray_after_leave_image", trayText ?? "—")
            }
        }

        // Chạm khay khi còn chạy.
        if let t = app.staticTexts.allElementsBoundByIndex.first(where: { $0.exists && $0.label.contains("Creating") })?.frame {
            step("tray_click_running"); at(t.midX, t.midY); G290.pause(app, 2)
            note("after_tray_click_running", onLibrary ? "Library" : G290.visibleTexts(app, limit: 12).joined(separator: " · "))
            snap("ET — chạm khay đang tạo")
            backToTabs()
        } else { note("tray_running", "không thấy khay 'Creating'") }

        // Chạm ô đang tạo ở đầu lưới Library.
        G290.openTab(app, "Library"); G290.pause(app, 2)
        if let p = app.staticTexts.allElementsBoundByIndex.first(where: { $0.exists && $0.label.hasSuffix("%") && $0.frame.minY > 140 && $0.frame.maxY < 660 })?.frame {
            step("pending_cell_click"); at(p.midX, p.midY - 30); G290.pause(app, 3)
            snap("ET — chạm ô đang tạo"); note("after_pending_click", G290.visibleTexts(app, limit: 12).joined(separator: " · "))
            backToTabs()
        } else { note("pending_cell", "không thấy ô đang tạo (%)") }

        // Chờ xong → chạm khay "Ready".
        G290.openTab(app, "Home")
        let done = G290.waitUntil(app, timeout: 420) { (self.trayText ?? "").contains("Ready") }
        note("tray_done_text", trayText ?? "—")
        if done, let t = app.staticTexts.allElementsBoundByIndex.first(where: { $0.exists && $0.label.contains("Ready") })?.frame {
            step("tray_click_done"); at(t.midX, t.midY); G290.pause(app, 3)
            note("after_tray_click_done", onLibrary ? "Library" : G290.visibleTexts(app, limit: 12).joined(separator: " · "))
            snap("ET — chạm khay đã xong"); backToTabs()
        }
        // Nếu lượt còn lại cũng xong, khay hiện "Ready" lần nữa — chạm nốt để không sót lượt.
        if G290.waitUntil(app, timeout: 300, { (self.trayText ?? "").contains("Ready") }),
           let t = app.staticTexts.allElementsBoundByIndex.first(where: { $0.exists && $0.label.contains("Ready") })?.frame {
            step("tray_click_done_2"); at(t.midX, t.midY); G290.pause(app, 3); backToTabs()
        }

        // Xoá thật đúng 1 ô mới nhất (kết quả vừa tạo trong lượt này) qua menu ···.
        G290.openTab(app, "Library"); G290.pause(app, 4)
        let before = app.buttons.matching(NSPredicate(format: "label == 'More'")).count
        if let more = moreButtons.first {
            step("real_delete_menu"); i2i.tap(more); G290.pause(app, 1); tapText("Delete"); G290.pause(app, 1.5)
            step("real_delete_confirm")
            if app.alerts.buttons["Delete"].exists { app.alerts.buttons["Delete"].firstMatch.tap() }
            G290.pause(app, 4)
            note("real_delete_count", "\(before) → \(app.buttons.matching(NSPredicate(format: "label == 'More'")).count)")
            snap("ET — sau khi xoá thật 1 ô")
        }
        step("end")
    }

    // MARK: - 4. Xoá thật đúng 1 ô mới nhất (ảnh vừa tạo ở case 2) qua menu ···

    func test04_realDeleteNewestItem() {
        G290.openTab(app, "Library"); G290.pause(app, 5)
        tapText("Photo"); G290.pause(app, 3)   // ô mới nhất ở lọc Photo = ảnh I2I vừa tạo
        guard let more = moreButtons.first else { note("abort", "không thấy ô nào"); return }
        let f = more.frame
        let before = app.buttons.matching(NSPredicate(format: "label == 'More'")).count
        step("real_delete_menu"); at(f.midX, f.midY); G290.pause(app, 1.5)
        snap("ET — menu ··· của ô mới nhất")
        guard tapText("Delete") else { note("abort", "menu ··· không có Delete"); return }
        G290.pause(app, 1.5)
        step("real_delete_confirm")
        if app.alerts.buttons["Delete"].exists { app.alerts.buttons["Delete"].firstMatch.tap() }
        G290.pause(app, 4)
        note("real_delete_count", "\(before) → \(app.buttons.matching(NSPredicate(format: "label == 'More'")).count)")
        snap("ET — sau khi xoá thật 1 ô")
        step("end")
    }

    // MARK: - 3. Mất mạng: tải Library lỗi + thử lại trên khay lỗi (1 credit video, có thể hoàn)

    func test03_offlineLoadFailAndTrayRetry() {
        let net = SettingsNetworkDriver { self.app }
        defer { _ = net.ensureOn() }

        // Lượt video chạy nền, rồi cắt mạng để lượt hỏng → khay "Couldn't finish".
        G290.openTab(app, "Home")
        let started = i2v.enterVideoUploadAnyRoute() && i2v.pickPhotosUntilReady() && i2v.startGenerate()
        if started { if i2v.generatingBackButton.exists { i2v.tap(i2v.generatingBackButton) } else { back() } }
        note("video_started", "\(started)")

        step("airplane_on"); let off = net.setAirplaneMode(true); note("airplane_on", "\(off)")
        app.activate(); G290.pause(app, 3)
        step("open_library_offline"); G290.openTab(app, "Library"); G290.pause(app, 6)
        note("library_offline_texts", G290.visibleTexts(app, limit: 12).joined(separator: " · "))
        snap("ET — Library khi mất mạng")

        if started {
            let failed = G290.waitUntil(app, timeout: 240) { (self.trayText ?? "").contains("Couldn") }
            note("tray_failed", "\(failed) · \(trayText ?? "—")"); snap("ET — khay lỗi")
            if failed {
                step("tray_retry_offline"); tapText("Retry"); G290.pause(app, 3)
                note("after_retry_offline", G290.visibleTexts(app, limit: 10).joined(separator: " · "))
            }
        }
        step("airplane_off"); _ = net.ensureOn(); app.activate(); G290.pause(app, 8)
        if (trayText ?? "").contains("Couldn") {
            step("tray_retry_online"); tapText("Retry"); G290.pause(app, 4)
            note("after_retry_online", trayText ?? "—")
        }
        step("open_library_online"); G290.openTab(app, "Home"); G290.pause(app, 1); G290.openTab(app, "Library"); G290.pause(app, 5)
        step("end")
    }
}
