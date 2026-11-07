//
//  ThawCapsuleSegmentsTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI
import Testing
@testable import ThawUI

@Suite("Capsule segments")
struct ThawCapsuleSegmentsTests {
    private typealias Sizing = ThawCapsuleSegments<Int>.Sizing

    @Test("A tab strip fills its row and gives every tab the same height")
    func fillingSizing() {
        let sizing = Sizing.filling
        #expect(sizing.showsTitles)
        #expect(sizing.maxWidth == .infinity)
        #expect(sizing.minWidth == nil)
        #expect(sizing.minHeight == 30)
        #expect(sizing.maxHeight == 30)
        #expect(sizing.inset == ThawSpacing.tight)
        #expect(sizing.horizontalPadding == ThawSpacing.inset)
    }

    @Test("A pill picker sizes to its labels, inset like an action group")
    func fittedSizing() {
        let titled = Sizing.fitted(showsTitles: true)
        #expect(titled.showsTitles)
        #expect(titled.maxWidth == nil)
        #expect(titled.inset == ThawSpacing.capsuleInset)
        #expect(titled.spacing == ThawSpacing.hairline)
        #expect(titled.horizontalPadding == ThawSpacing.row)
    }

    @Test("A symbol-only pill keeps a minimum width for its symbol")
    func symbolOnlySizing() {
        let symbols = Sizing.fitted(showsTitles: false)
        #expect(!symbols.showsTitles)
        #expect(symbols.minWidth == 28)
        #expect(symbols.horizontalPadding < Sizing.fitted(showsTitles: true).horizontalPadding)
    }

    @Test("The selection slides on a short spring with a slight bounce")
    func selectionMotion() {
        #expect(ThawMotion.selection == .spring(response: 0.3, dampingFraction: 0.78))
    }

    @Test("A clear glass lens shows over the selection only when transparency and contrast allow it")
    func lensVisibility() {
        typealias Segments = ThawCapsuleSegments<Int>
        #expect(Segments.showsLens(reduceTransparency: false, increasedContrast: false))
        #expect(!Segments.showsLens(reduceTransparency: true, increasedContrast: false))
        #expect(!Segments.showsLens(reduceTransparency: false, increasedContrast: true))
    }

    @Test("At rest the lens covers its segment; while moving it swells wider and taller than the track")
    func lensFrame() {
        typealias Segments = ThawCapsuleSegments<Int>
        let segment = CGRect(x: 40, y: 3, width: 80, height: 24)
        #expect(Segments.lensFrame(around: segment, moving: false) == segment)
        let moving = Segments.lensFrame(around: segment, moving: true)
        #expect(moving.width == 96)
        #expect(moving.height == 35)
        #expect(moving.midX == segment.midX && moving.midY == segment.midY)
        #expect(Segments.swellDuration == .milliseconds(220))
    }

    @Test("Reduce Motion never swells the lens")
    func reduceMotionNoSwell() {
        typealias Segments = ThawCapsuleSegments<Int>
        #expect(Segments.swells(moving: true, reduceMotion: false))
        #expect(!Segments.swells(moving: true, reduceMotion: true))
        #expect(!Segments.swells(moving: false, reduceMotion: false))
    }

    @MainActor
    @Test("Changing the selection moves the one selection indicator to the new segment")
    func indicatorFollowsSelection() throws {
        let picker = ThawPillPicker(selection: .constant(1), options: [.init(1, title: "One"), .init(2, title: "Two"), .init(3, title: "Three")])
        let first = try OffscreenRender(picker, size: CGSize(width: 260, height: 40)).pixels()
        let moved = ThawPillPicker(selection: .constant(3), options: [.init(1, title: "One"), .init(2, title: "Two"), .init(3, title: "Three")])
        let last = try OffscreenRender(moved, size: CGSize(width: 260, height: 40)).pixels()
        #expect(first != last)
    }
}
