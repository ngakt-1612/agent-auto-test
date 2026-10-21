//
//  EventSinkClient.swift
//  iosAppUITests (out-of-process UI tests).
//  Launches the app with the event-sink environment and reads back the JSONL
//  file the wrapper writes. Simulator-only: the app writes to host /tmp.
//

import Foundation
import XCTest

struct SinkEvent: Decodable {
    let name: String
    let params: [String: String]?
    let ts: Int64
}

final class EventSinkClient {

    let sinkPath: String

    init() {
        sinkPath = "/tmp/app-events-\(UUID().uuidString).jsonl"
    }

    func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["EVENT_SINK_PATH"] = sinkPath
        // Optional convention: the app may skip onboarding when this is set.
        app.launchEnvironment["UI_TEST_SKIP_ONBOARDING"] = "1"
        app.launch()
        return app
    }

    func events() -> [SinkEvent] {
        guard let data = FileManager.default.contents(atPath: sinkPath),
              let text = String(data: data, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return text.split(separator: "\n").compactMap { line in
            guard let lineData = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(SinkEvent.self, from: lineData)
        }
    }

    @discardableResult
    func waitForEvent(
        _ name: String,
        params: [String: String] = [:],
        timeout: TimeInterval = 5
    ) -> SinkEvent? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let match = events().last(where: { event in
                event.name == name && params.allSatisfy { key, value in
                    event.params?[key] == value
                }
            }) {
                return match
            }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return nil
    }

    func assertEvent(
        _ name: String,
        params: [String: String] = [:],
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = waitForEvent(name, params: params, timeout: timeout)
        XCTAssertNotNil(
            found,
            "Event '\(name)'\(params.isEmpty ? "" : " with params \(params)") not found. Captured: \(events().map(\.name))",
            file: file, line: line
        )
    }
}
