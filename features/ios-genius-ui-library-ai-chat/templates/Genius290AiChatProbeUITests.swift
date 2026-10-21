import XCTest

/// Dò cây accessibility của màn Chat (901) và dải `Try the newest vibes` ở Home — màn Chat không có
/// accessibility identifier, nút dấu cộng / nút gửi là ảnh gắn cử chỉ chạm. 0 lượt.
/// Bật bằng `TEST_RUNNER_RUN_G290_CHAT_PROBE=1`.
final class Genius290AiChatProbeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_G290_CHAT_PROBE"] == "1", "Bật bằng TEST_RUNNER_RUN_G290_CHAT_PROBE=1.")
        continueAfterFailure = true
        app = I2IJourneyDriver.launchApp()
        XCTAssertTrue(G290.reachMain(app), "không vào được luồng chính")
    }

    /// In mọi element có nhãn/id/giá trị trong một snapshot: loại · nhãn · id · giá trị · frame · bật.
    private func dump(_ tag: String) {
        guard let root = try? app.snapshot() else { return }
        var stack: [XCUIElementSnapshot] = [root], lines: [String] = []
        while let n = stack.popLast() {
            let v = (n.value as? String) ?? ""
            if !n.frame.isEmpty, n.frame.minY < 900, !(n.label.isEmpty && n.identifier.isEmpty && v.isEmpty) {
                lines.append("\(n.elementType.rawValue)|\(n.label)|\(n.identifier)|\(v.prefix(40))|\(Int(n.frame.minX)),\(Int(n.frame.minY)),\(Int(n.frame.width))x\(Int(n.frame.height))|\(n.isEnabled ? 1 : 0)")
            }
            stack.append(contentsOf: n.children.reversed())
        }
        print("DUMP|\(tag)|\(lines.count) element")
        lines.prefix(150).forEach { print("DUMP|\(tag)|\($0)") }
        snap("probe — \(tag)")
    }

    func test01_dumpChatAndVibes() {
        G290.openTab(app, "Chat"); G290.pause(app, 3)
        dump("chat")
        if let more = app.buttons.allElementsBoundByIndex.first(where: { $0.exists && $0.frame.minY < 140 && $0.frame.minX > 300 }) {
            more.tap(); G290.pause(app, 1.5); dump("chat-menu")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); G290.pause(app, 1)
        }
        G290.openTab(app, "Home"); app.swipeDown(); app.swipeDown(); G290.pause(app, 3)
        dump("home")
    }
}
