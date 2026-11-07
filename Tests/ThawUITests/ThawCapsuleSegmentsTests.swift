//
//  ThawCapsuleSegmentsTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI
import Testing
@testable import ThawUI

/// The segmented choice behind ThawPillPicker and ThawTabStrip, drawn by the system's segmented picker.
@Suite("Capsule segments")
struct ThawCapsuleSegmentsTests {
    private typealias Segments = ThawCapsuleSegments<Int>

    @Test("A tab strip fills its row at the large size; pills keep their width at the regular size")
    func sizing() {
        #expect(Segments.Sizing.filling.maxWidth == .infinity)
        #expect(Segments.Sizing.filling.controlSize == .large)
        #expect(Segments.Sizing.filling.showsTitles)
        #expect(Segments.Sizing.fitted(showsTitles: true).maxWidth == nil)
        #expect(Segments.Sizing.fitted(showsTitles: true).controlSize == .regular)
        #expect(!Segments.Sizing.fitted(showsTitles: false).showsTitles)
    }

    @MainActor
    @Test("Each segment shows its title, its title and symbol, or its symbol alone")
    func labels() {
        let titled = ThawSegment(1, title: "One")
        let symbolled = ThawSegment(2, title: "Two", systemImage: "star")
        #expect(Segments.label(for: titled, showsTitles: true) == .title)
        #expect(Segments.label(for: symbolled, showsTitles: true) == .titleAndSymbol("star"))
        #expect(Segments.label(for: symbolled, showsTitles: false) == .symbol("star"))
        #expect(Segments.label(for: titled, showsTitles: false) == .title, "a segment with no symbol keeps its title")
    }

    @MainActor
    @Test("The pickers draw with titles, symbols alone, and filling their row")
    func draws() {
        let options = [ThawSegment(1, title: "One", systemImage: "1.circle"), ThawSegment(2, title: "Two", systemImage: "2.circle")]
        let view = VStack {
            ThawPillPicker(selection: .constant(1), options: options)
            ThawPillPicker(selection: .constant(2), options: options, showsTitles: false)
            ThawTabStrip(selection: .constant(1), items: options)
        }
        #expect(NSHostingView(rootView: view.frame(width: 320)).fittingSize.height > 0)
    }
}
