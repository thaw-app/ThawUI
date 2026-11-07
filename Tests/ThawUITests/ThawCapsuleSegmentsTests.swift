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

    @Test("The sliding selection is a glass lens only when transparency and contrast allow it")
    func indicatorSurface() {
        typealias Segments = ThawCapsuleSegments<Int>
        #expect(Segments.indicatorSurface(reduceTransparency: false, increasedContrast: false) == .glass)
        #expect(Segments.indicatorSurface(reduceTransparency: true, increasedContrast: false) == .flat)
        #expect(Segments.indicatorSurface(reduceTransparency: false, increasedContrast: true) == .flat)
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

    @Test("While the selection moves it lifts as a larger glass lens, and it rests as the flat fill")
    func liftAppearance() {
        typealias Segments = ThawCapsuleSegments<Int>
        let lifted = Segments.indicatorAppearance(lifted: true, reduceTransparency: false, increasedContrast: false, reduceMotion: false)
        #expect(lifted.showsLens)
        #expect(lifted.scale == 1.12)
        #expect(lifted.fillOpacity == 0)
        let resting = Segments.indicatorAppearance(lifted: false, reduceTransparency: false, increasedContrast: false, reduceMotion: false)
        #expect(!resting.showsLens)
        #expect(resting.scale == 1)
        #expect(resting.fillOpacity == 1)
    }

    @Test("Reduce Transparency, Increase Contrast and Reduce Motion never lift the lens")
    func liftAccessibility() {
        typealias Segments = ThawCapsuleSegments<Int>
        for (transparency, contrast, motion) in [(true, false, false), (false, true, false), (false, false, true)] {
            let appearance = Segments.indicatorAppearance(lifted: true, reduceTransparency: transparency, increasedContrast: contrast, reduceMotion: motion)
            #expect(!appearance.showsLens)
            #expect(appearance.scale == 1)
            #expect(appearance.fillOpacity == 1)
        }
        #expect(Segments.liftDuration == .milliseconds(170))
    }
}
