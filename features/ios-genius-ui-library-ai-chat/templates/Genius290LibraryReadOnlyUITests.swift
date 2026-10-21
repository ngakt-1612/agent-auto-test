import XCTest

/// Library 2.9.0 khi đã có kết quả — lọc, chế độ chọn, menu ba chấm, hộp thoại xoá (luôn bấm Cancel).
///
/// Không xoá gì: case xoá thật nằm ở suite riêng vì phá dữ liệu tài khoản. 0 credit.
/// Bật bằng `TEST_RUNNER_RUN_G290_LIBRARY_RO=1`.
final class Genius290LibraryReadOnlyUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_G290_LIBRARY_RO"] == "1",
                          "Bật bằng TEST_RUNNER_RUN_G290_LIBRARY_RO=1.")
        continueAfterFailure = true
        app = I2IJourneyDriver.launchApp()
        XCTAssertTrue(G290.reachMain(app), "không vào được luồng chính")
        G290.openTab(app, "Library")
    }

    // MARK: - Đo

    private var moreButtons: [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { $0.exists && $0.label == "More" && $0.frame.minY > 140 && $0.frame.maxY < 760 }
    }
    private var visiblePlayIcons: Int {
        app.images.allElementsBoundByIndex.filter {
            $0.exists && $0.frame.minY > 140 && $0.frame.maxY < 760 && $0.label.localizedCaseInsensitiveContains("play")
        }.count
    }
    private func filterChip(_ label: String) -> XCUIElement {
        app.buttons[label].exists ? app.buttons[label].firstMatch : app.staticTexts[label].firstMatch
    }

    func test01_layoutAndFilters() {
        let images = app.images.allElementsBoundByIndex.prefix(30).filter(\.exists).map(\.label)
        print("🔎 images trong Library: \(images)")
        snap("TC-LIB01-002 — Library có kết quả")

        // TC-LIB01-002 — bố cục khi có kết quả
        let filters = ["All", "Image", "Photo", "Video", "Conversation"].filter { filterChip($0).exists }
        let ok = app.staticTexts["Library"].exists && filterChip("Select").exists && !moreButtons.isEmpty
            && !app.staticTexts["Nothing here yet."].exists && !app.buttons["Start creating"].exists
        G290.verdict("TC-LIB01-002", pass: ok && filters == ["All", "Image", "Video"],
                     "tiêu đề Library + Select + ô có ···=\(ok) · hàng lọc thực tế: \(filters.joined(separator: " · ")) (spec: All · Image · Video) · số ô thấy: \(moreButtons.count)")

        // TC-LIB02-001 — lọc Video
        filterChip("Video").tap(); G290.pause(app, 2)
        let vCells = moreButtons.count, vPlays = visiblePlayIcons
        snap("TC-LIB02-001 — lọc Video")
        G290.verdict("TC-LIB02-001", pass: vCells > 0 && vPlays >= vCells,
                     "lọc Video: \(vCells) ô, \(vPlays) ô có nút play")

        // TC-LIB02-002 — lọc Image (app gọi là Photo)
        let photoLabel = filterChip("Image").exists ? "Image" : "Photo"
        filterChip(photoLabel).tap(); G290.pause(app, 2)
        let pCells = moreButtons.count, pPlays = visiblePlayIcons
        snap("TC-LIB02-002 — lọc \(photoLabel)")
        G290.verdict("TC-LIB02-002", pass: photoLabel == "Image" && pCells > 0 && pPlays == 0,
                     "chip tên '\(photoLabel)' (spec: Image) · \(pCells) ô, \(pPlays) ô có nút play")

        // TC-LIB02-003 — quay lại All
        filterChip("All").tap(); G290.pause(app, 2)
        G290.verdict("TC-LIB02-003", pass: moreButtons.count >= max(vCells, pCells), "All: \(moreButtons.count) ô")

        // TC-LIB02-004 — đổi tab rồi quay lại → bộ lọc về All
        filterChip("Video").tap(); G290.pause(app, 1)
        G290.openTab(app, "Home"); G290.openTab(app, "Library")
        let backToAll = visiblePlayIcons < moreButtons.count || moreButtons.count > vCells
        G290.verdict("TC-LIB02-004", pass: backToAll,
                     "sau khi đổi tab: \(moreButtons.count) ô, \(visiblePlayIcons) ô video (All khi có cả ảnh)")
    }

    func test02_selectModeMenuAndCancel() {
        // TC-LIB03-001 — vào chế độ chọn
        filterChip("Select").tap(); G290.pause(app, 1.5)
        let cancelShown = G290.anyLabeled(app, "Cancel").exists
        let title = ["Select results", "Chọn kết quả"].first { app.staticTexts[$0].exists } ?? "—"
        let tabHidden = app.tabBars.buttons.count == 0
        let deleteBar = bottomDelete()
        snap("TC-LIB03-001 — chế độ chọn")
        G290.verdict("TC-LIB03-001", pass: cancelShown && title != "—" && tabHidden && deleteBar.exists && !deleteEnabled() && moreButtons.isEmpty,
                     "Cancel=\(cancelShown) · tiêu đề '\(title)' · thanh tab ẩn=\(tabHidden) · thanh Delete có=\(deleteBar.exists) bật(đỏ)=\(deleteEnabled()) · ··· còn \(moreButtons.count)")

        // TC-LIB03-002 / 003 / 004 — chọn 3 ô, bỏ 1, chạm không mở xem; bỏ hết thì Delete mờ
        let cells = gridCells()
        let picks = Array(cells.prefix(3))
        picks.forEach { $0.tap(); G290.pause(app, 0.5) }
        let t3 = selectedTitle()
        picks[1].tap(); G290.pause(app, 0.5)
        let t2 = selectedTitle()
        let stillGrid = G290.anyLabeled(app, "Cancel").exists
        snap("TC-LIB03-002 — đã chọn 2")
        G290.verdict("TC-LIB03-002", pass: t3.contains("3") && t2.contains("2") && deleteEnabled(),
                     "tiêu đề sau 3 ô: '\(t3)' · sau bỏ 1: '\(t2)' · Delete bật=\(deleteEnabled())")
        G290.verdict("TC-LIB03-003", pass: stillGrid, "chạm ô trong chế độ chọn vẫn ở lưới (không mở màn xem) = \(stillGrid)")

        // TC-LIB03-009 — Delete → hộp thoại → Cancel: không xoá, giữ lựa chọn
        if deleteBar.exists { deleteBar.tap() }; G290.pause(app, 1)
        let dialog = app.alerts.firstMatch.exists ? app.alerts.firstMatch : app.sheets.firstMatch
        let dialogShown = dialog.exists
        let dialogTexts = dialogShown ? dialog.staticTexts.allElementsBoundByIndex.map(\.label) : []
        snap("TC-LIB03-009 — hộp thoại xoá nhiều")
        if dialog.buttons["Cancel"].exists { dialog.buttons["Cancel"].firstMatch.tap() }; G290.pause(app, 1)
        G290.verdict("TC-LIB03-009", pass: dialogShown && selectedTitle().contains("2"),
                     "hộp thoại: \(dialogTexts) · sau Cancel tiêu đề '\(selectedTitle())'")

        picks[0].tap(); picks[2].tap(); G290.pause(app, 0.5)
        G290.verdict("TC-LIB03-004", pass: !deleteEnabled(), "bỏ chọn hết: Delete bật=\(deleteEnabled())")

        // TC-LIB03-008 — đổi bộ lọc khi đang chọn
        cells.first?.tap(); filterChip("Video").tap(); G290.pause(app, 1)
        G290.verdict("TC-LIB03-008", pass: G290.anyLabeled(app, "Cancel").exists && !deleteEnabled(),
                     "sau đổi lọc: còn chế độ chọn=\(G290.anyLabeled(app, "Cancel").exists) · Delete bật=\(deleteEnabled())")
        filterChip("All").tap()

        // TC-LIB03-007 — Cancel thoát chế độ chọn
        let exitCancel = G290.anyLabeled(app, "Cancel"); if exitCancel.exists { exitCancel.tap() }; G290.pause(app, 1.5)
        G290.verdict("TC-LIB03-007", pass: filterChip("Select").exists && app.tabBars.buttons.count > 0 && !moreButtons.isEmpty,
                     "Select trở lại=\(filterChip("Select").exists) · thanh tab=\(app.tabBars.buttons.count > 0) · ··· hiện lại=\(!moreButtons.isEmpty)")

        // TC-LIB03-011 / 013 / 014 — menu ba chấm chỉ có Delete; chạm ngoài đóng; Delete → hộp thoại 'Delete?'
        moreButtons.first?.tap(); G290.pause(app, 1)
        let menuItems = app.buttons.allElementsBoundByIndex.filter { $0.exists && ["Delete", "Duplicate"].contains($0.label) }.map(\.label)
        snap("TC-LIB03-011 — menu ···")
        G290.verdict("TC-LIB03-011", pass: menuItems == ["Delete"], "mục trong menu: \(menuItems)")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap(); G290.pause(app, 1)
        G290.verdict("TC-LIB03-013", pass: !app.buttons["Duplicate"].exists && app.buttons.matching(identifier: "Delete").count == 0,
                     "sau khi chạm ngoài: menu còn=\(app.buttons["Delete"].exists)")
        moreButtons.first?.tap(); G290.pause(app, 1)
        if app.buttons["Delete"].exists { app.buttons["Delete"].firstMatch.tap() }; G290.pause(app, 1)
        let alert = app.alerts.firstMatch
        let aTexts = alert.exists ? alert.staticTexts.allElementsBoundByIndex.map(\.label) : []
        snap("TC-LIB03-014 — hộp thoại Delete?")
        G290.verdict("TC-LIB03-014", pass: aTexts.contains("Delete?") && alert.buttons["Cancel"].exists && alert.buttons["Delete"].exists,
                     "hộp thoại: \(aTexts) · nút: \(alert.buttons.allElementsBoundByIndex.map(\.label))")
        let before = moreButtons.count
        if alert.buttons["Cancel"].exists { alert.buttons["Cancel"].firstMatch.tap() }; G290.pause(app, 1)
        G290.verdict("TC-LIB03-010", pass: moreButtons.count == before, "Cancel ở hộp thoại: số ô \(before) → \(moreButtons.count)")

        // TC-LIB03-012 — nhấn giữ 0,5s mở menu
        gridCells().first?.press(forDuration: 1.2); G290.pause(app, 1)
        let longPressMenu = app.buttons["Delete"].exists
        snap("TC-LIB03-012 — nhấn giữ")
        G290.verdict("TC-LIB03-012", pass: longPressMenu, "nhấn giữ 1,2s: menu Delete hiện=\(longPressMenu)")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
    }

    // MARK: - Helpers

    /// Toạ độ giữa từng ô lưới: lấy từ nút ··· (góc trên phải ô); ở chế độ chọn nút ··· ẩn nên
    /// dùng lưới 3 cột đo được ở probe (ô ~110x150, hàng đầu từ y≈180).
    private func gridCells() -> [XCUICoordinate] {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let shown = app.buttons.allElementsBoundByIndex.filter { $0.exists && $0.label == "More" && $0.frame.minY > 140 && $0.frame.maxY < 700 }
        if !shown.isEmpty {
            return shown.map { origin.withOffset(CGVector(dx: $0.frame.midX - 45, dy: $0.frame.midY + 70)) }
        }
        return (0..<6).map { i in origin.withOffset(CGVector(dx: 70 + Double(i % 3) * 122, dy: 240 + Double(i / 3) * 160)) }
    }
    /// Thanh hành động ở đáy chế độ chọn: chữ `Delete` là staticText (không phải Button).
    private func bottomDelete() -> XCUIElement {
        let candidates = app.buttons.allElementsBoundByIndex + app.staticTexts.allElementsBoundByIndex
        return candidates.first { $0.exists && $0.label == "Delete" && $0.frame.minY > 600 } ?? app.staticTexts["__none__"]
    }
    /// Bật = chữ Delete đỏ; tắt = xám. Đo màu trong vùng chữ.
    private func deleteEnabled() -> Bool {
        G290.redFraction(of: bottomDelete()) > 0.02
    }
    private func selectedTitle() -> String {
        app.staticTexts.allElementsBoundByIndex.first { $0.exists && ($0.label.contains("selected") || $0.label.hasPrefix("Đã chọn")) }?.label ?? "—"
    }
}
