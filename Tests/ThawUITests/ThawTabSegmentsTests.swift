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

    @Test("The pickers draw the system control, with the selection shown")
    func pickersDraw() throws {
        let first = try OffscreenRender(ThawTabStrip(selection: .constant(1), items: Self.options), size: CGSize(width: 420, height: 44)).pixels()
        let last = try OffscreenRender(ThawTabStrip(selection: .constant(3), items: Self.options), size: CGSize(width: 420, height: 44)).pixels()
        #expect(first != last)
    }
}
