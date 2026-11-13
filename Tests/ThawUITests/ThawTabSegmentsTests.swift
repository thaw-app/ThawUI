//
//  ThawTabSegmentsTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 René Jiménez
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI
import Testing
@testable import ThawUI

/// A pill picker bound to state, as settings pages bind it; a constant binding can't form the cycle.
private struct StatefulPillPicker: View {
    let options: [ThawSegment<Int>]
    let showsTitles: Bool
    @State private var selection = 1

    var body: some View {
        ThawPillPicker(selection: $selection, options: options, showsTitles: showsTitles)
    }
}

@MainActor
@Suite("Tab segments")
struct ThawTabSegmentsTests {
    private static let options: [ThawSegment<Int>] = [
        .init(1, title: "Above", systemImage: "rectangle"),
        .init(2, title: "Left Side", systemImage: "sidebar.left"),
        .init(3, title: "Right Side", systemImage: "sidebar.right"),
    ]

    private static func fittingSize(of view: some View) -> CGSize {
        let host = NSHostingView(rootView: view)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    @available(macOS 27, *)
    private static func segments(_ sizing: ThawCapsuleSegments<Int>.Sizing, options: [ThawSegment<Int>] = options) -> some View {
        ThawTabSegments(selection: .constant(1), segments: options, sizing: sizing)
    }

    @Test("A pill picker is as wide as its segments, and narrower with symbols alone")
    func fittedWidth() {
        guard #available(macOS 27, *) else { return }
        let titled = Self.fittingSize(of: Self.segments(.fitted(showsTitles: true)))
        let symbols = Self.fittingSize(of: Self.segments(.fitted(showsTitles: false)))
        let two = Self.fittingSize(of: Self.segments(.fitted(showsTitles: true), options: Array(Self.options.prefix(2))))
        #expect(symbols.width > 0)
        #expect(symbols.width < titled.width)
        #expect(two.width < titled.width)
        #expect(symbols.height == titled.height)
    }

    @Test("A tab strip uses the larger control")
    func stripIsTaller() {
        guard #available(macOS 27, *) else { return }
        let pill = Self.fittingSize(of: Self.segments(.fitted(showsTitles: true)))
        let strip = Self.fittingSize(of: Self.segments(.filling))
        #expect(strip.height > pill.height)
    }

    /// Retain cycles in this process that hold a segment, as /usr/bin/leaks reports them; nil when leaks can't run.
    private static func segmentCycles() -> Int? {
        let leaks = Process()
        leaks.executableURL = URL(fileURLWithPath: "/usr/bin/leaks")
        leaks.arguments = ["\(getpid())"]
        let output = Pipe()
        leaks.standardOutput = output
        leaks.standardError = Pipe()
        guard (try? leaks.run()) != nil else { return nil }
        let report = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        leaks.waitUntilExit()
        // 0 is no leaks and 1 is leaks found; anything else means the scan didn't run.
        guard leaks.terminationStatus <= 1 else { return nil }
        return report.split(separator: "\n").count { $0.contains("ROOT CYCLE") && $0.contains("ThawSegment") }
    }

    @Test("Closing a tab strip leaves nothing behind, with titles, symbols or both")
    func closingLeavesNoCycle() async throws {
        let before = try #require(Self.segmentCycles())
        let titled = Self.options.map { ThawSegment($0.value, title: $0.title) }
        for _ in 0 ..< 4 {
            for showsTitles in [true, false] {
                for options in [Self.options, titled] {
                    var render: OffscreenRender<StatefulPillPicker>? = OffscreenRender(
                        StatefulPillPicker(options: options, showsTitles: showsTitles),
                        size: CGSize(width: 420, height: 44)
                    )
                    // The cycle forms only once SwiftUI has finished updating the picker, and frees on a later turn.
                    await render?.settle(within: .milliseconds(100)) { false }
                    _ = try render?.pixels()
                    render = nil
                    try await Task.sleep(for: .milliseconds(100))
                }
            }
        }
        try await Task.sleep(for: .seconds(1))
        #expect(Self.segmentCycles() == before)
    }

    @Test("The pickers draw the system control, with the selection shown")
    func pickersDraw() throws {
        let first = try OffscreenRender(ThawTabStrip(selection: .constant(1), items: Self.options), size: CGSize(width: 420, height: 44)).pixels()
        let last = try OffscreenRender(ThawTabStrip(selection: .constant(3), items: Self.options), size: CGSize(width: 420, height: 44)).pixels()
        #expect(first != last)
    }
}
