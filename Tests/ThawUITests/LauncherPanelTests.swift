//
//  LauncherPanelTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 René Jiménez
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI
import Testing
@testable import ThawUI

struct LauncherListStepTests {
    @Test("The arrows, Page Up and Page Down, Home and End have steps; other keys don't")
    func keySteps() {
        #expect(LauncherListStep.delta(for: .downArrow) == 1)
        #expect(LauncherListStep.delta(for: .upArrow) == -1)
        #expect(LauncherListStep.delta(for: .pageDown) == LauncherListStep.page)
        #expect(LauncherListStep.delta(for: .pageUp) == -LauncherListStep.page)
        #expect(LauncherListStep.delta(for: .returnKey) == nil)
    }

    @Test("A move is held to the rows there are")
    func clamping() throws {
        #expect(LauncherListStep.moved(0, by: -1, count: 5) == 0)
        #expect(LauncherListStep.moved(4, by: 1, count: 5) == 4)
        #expect(LauncherListStep.moved(2, by: LauncherListStep.page, count: 5) == 4)
        #expect(try LauncherListStep.moved(3, by: #require(LauncherListStep.delta(for: .home)), count: 5) == 0)
        #expect(try LauncherListStep.moved(1, by: #require(LauncherListStep.delta(for: .end)), count: 5) == 4)
        #expect(LauncherListStep.moved(3, by: 1, count: 0) == 0)
    }
}

struct PanelPieceHeightsTests {
    @Test("A launcher's pieces add up to the panel's height, field and gap first")
    func launcherHeights() {
        let heights = PanelPieceHeights.launcher(height: 474)
        #expect(heights.field == PanelPieceHeights.launcherField)
        #expect(heights.gap == PanelPieceHeights.launcherGap)
        #expect(heights.total == 474)
        #expect(heights.fieldSpan.lowerBound == 0)
        #expect(heights.resultsSpan.upperBound == 1)
        #expect(heights.fieldSpan.upperBound < heights.resultsSpan.lowerBound, "the gap sits between the spans")
    }

    @Test("Collapsed, only the field's piece counts")
    func collapsed() {
        #expect(PanelPieceHeights.launcher(height: 474, isCollapsed: true).total == PanelPieceHeights.launcherField)
    }
}

struct LauncherLookTests {
    @Test("Following the system draws Regular while its glass is tinted and Clear while it is clear")
    func followsSystemGlass() {
        let glass = LauncherGlass(style: .dynamic, followsSystem: true)
        #expect(glass.resolvedStyle(systemGlassIsTinted: true) == .regular)
        #expect(glass.resolvedStyle(systemGlassIsTinted: false) == .clear)
        #expect(LauncherGlass(style: .dynamic).resolvedStyle(systemGlassIsTinted: true) == .dynamic)
    }

    @Test("Only the Liquid styles take a wash, and only when it is turned on")
    func glassWash() {
        let colored = LauncherGlass(isColored: true)
        #expect(colored.tintColor(for: .liquid) != nil)
        #expect(colored.tintColor(for: .regular) == nil)
        #expect(LauncherGlass().tintColor(for: .liquid) == nil)
    }

    @Test("No tint draws no fill")
    func tintFill() {
        #expect(LauncherTint().backgroundStyle == nil)
        #expect(LauncherTint(kind: .solid).backgroundStyle != nil)
        #expect(LauncherTint(kind: .gradient).backgroundStyle != nil)
    }

    @Test("A colour survives being saved")
    func storedColorRoundTrip() throws {
        let color = StoredColor.iconBlue
        let decoded = try JSONDecoder().decode(StoredColor.self, from: JSONEncoder().encode(color))
        #expect(decoded == color)
    }
}

@MainActor
struct PanelSectionsTests {
    @Test("In pieces and in one panel, the sections draw")
    func drawsBothWays() {
        let pieces = PanelPieces(look: .standard, corners: .rounded, heights: .launcher(height: 300))
        for withPieces in [true, false] {
            let view = PanelSections { Text(verbatim: "Field") } content: { Text(verbatim: "Rows") }
                .frame(width: 400, height: 300)
                .modifier(PanelLook(look: .standard, pieces: withPieces ? pieces : nil))
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
            host.layoutSubtreeIfNeeded()
            #expect(host.fittingSize.width > 0)
        }
    }

    @Test("The results list lays out its rows under section headings")
    func resultListLaysOut() {
        struct Row: Identifiable {
            let id: Int
            let section: String
        }
        let rows = [Row(id: 1, section: "Recent"), Row(id: 2, section: "Menu Bar"), Row(id: 3, section: "Menu Bar")]
        var selected = -1
        let list = LauncherResultList(
            rows: rows,
            selection: 1,
            section: \.section,
            select: { selected = $0 },
            activate: { _ in },
            rowContent: { row, isSelected in
                PaletteRow(title: "\(row.id)", selected: isSelected) { EmptyView() } trailing: { EmptyView() }
            }
        )
        let host = NSHostingView(rootView: list.frame(width: 400, height: 300))
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.width > 0)
        list.select(2)
        #expect(selected == 2)
    }
}
