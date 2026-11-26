//
//  ThawHUDTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import Testing
@testable import ThawUI

/// The confirmation capsule, shown and taken down within one main-actor turn so it never reaches the screen.
@Suite("Thaw HUD", .serialized)
@MainActor
struct ThawHUDTests {
    /// The HUD's panel, told apart from other windows by its level and click-through.
    private func hudPanels() -> [NSWindow] {
        NSApplication.shared.windows.filter { $0 is NSPanel && $0.level == .statusBar && $0.ignoresMouseEvents && $0.isVisible }
    }

    @Test("A capsule sits under the menu bar at the placement asked for, sized to its text")
    func placementAndSize() throws {
        let screen = try #require(NSScreen.screens.first)
        ThawHUD.dismiss()
        let before = Set(hudPanels().map(ObjectIdentifier.init))

        ThawHUD.show(symbol: "moon", text: "Zen on", on: screen, placement: .leading)
        let shown = hudPanels().filter { !before.contains(ObjectIdentifier($0)) }
        let panel = try #require(shown.first)
        let frame = panel.frame
        ThawHUD.dismiss()

        #expect(frame.minX == screen.frame.minX + ThawHUDPlacement.edgeInset)
        #expect(frame.width >= 120)
        #expect(frame.height >= 34)
        #expect(frame.maxY < screen.frame.maxY, "the capsule hangs below the bar")
        #expect(!panel.isVisible)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.hasShadow)
    }

    @Test(
        "A capsule keeps the frame show() gave it through layout passes, whatever its text width",
        arguments: [
            "Moved Item to Visible", "Moved Item to Hidden", "Moved Items to Visible", "Moved Itemss to Visible",
            "Moved Itemsss to Visible", "Moved C1 to Visible", "Item didn\u{2019}t stay in Hidden", "Moved",
        ]
    )
    func keepsItsFrameThroughLayout(text: String) async throws {
        let screen = try #require(NSScreen.screens.first)
        ThawHUD.dismiss()
        let before = Set(hudPanels().map(ObjectIdentifier.init))
        defer { ThawHUD.dismiss() }

        ThawHUD.show(symbol: "checkmark", text: LocalizedStringResource(stringLiteral: text), on: screen, displayDuration: .seconds(5))
        let panel = try #require(hudPanels().first { !before.contains(ObjectIdentifier($0)) })
        let shown = panel.frame
        #expect(shown == shown.integral, "the panel is sized in whole points")

        // The hosting view is not the panel's content view, so it can't resize the panel.
        let content = try #require(panel.contentView)
        #expect(type(of: content) == NSView.self)
        #expect(content.frame.size == shown.size)
        #expect(content.subviews.count == 1)

        for _ in 0..<3 {
            panel.contentView?.needsLayout = true
            panel.layoutIfNeeded()
            panel.displayIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(panel.frame == shown, "nothing but show() resized the panel")
    }

    @Test("A second capsule reuses the panel instead of stacking another")
    func reusesPanel() throws {
        let screen = try #require(NSScreen.screens.first)
        ThawHUD.dismiss()
        let before = Set(hudPanels().map(ObjectIdentifier.init))

        ThawHUD.show(symbol: "eye", text: "Hidden items shown", on: screen)
        ThawHUD.show(symbol: "eye.slash", text: "Hidden items hidden", on: screen, placement: .trailing)
        let shown = hudPanels().filter { !before.contains(ObjectIdentifier($0)) }
        let frame = shown.first?.frame
        ThawHUD.dismiss()

        #expect(shown.count == 1)
        if let frame {
            #expect(abs(frame.maxX - (screen.frame.maxX - ThawHUDPlacement.edgeInset)) < 0.5)
        }
        ThawHUD.dismiss()
        #expect(hudPanels().filter { !before.contains(ObjectIdentifier($0)) }.isEmpty, "dismissing twice is harmless")
    }

    @Test("Text alone shows a capsule, and a line wider than the screen stays inside it")
    func symbolIsOptionalAndWidthCapped() throws {
        let screen = try #require(NSScreen.screens.first)
        ThawHUD.dismiss()
        let before = Set(hudPanels().map(ObjectIdentifier.init))

        ThawHUD.show(text: LocalizedStringResource(stringLiteral: String(repeating: "A long sentence. ", count: 200)), on: screen)
        let frame = try #require(hudPanels().first { !before.contains(ObjectIdentifier($0)) }?.frame)
        ThawHUD.dismiss()

        #expect(frame.width <= screen.frame.width - 2 * ThawHUDPlacement.edgeInset)
    }

    @Test("A timed dismissal fades the capsule out, and a new capsule during the fade stays up")
    func fadesOutAndSurvivesAReshow() async throws {
        let screen = try #require(NSScreen.screens.first)
        ThawHUD.dismiss()
        #expect(ThawHUD.fadeDuration == 0.15)

        ThawHUD.show(symbol: "checkmark", text: "Moved", on: screen, displayDuration: .milliseconds(10))
        let panel = try #require(hudPanels().first)
        try await Task.sleep(for: .milliseconds(60))
        ThawHUD.show(symbol: "xmark", text: "Didn't move", tint: .orange, on: screen, displayDuration: .seconds(5))
        try await Task.sleep(for: .milliseconds(300))
        #expect(panel.isVisible, "the second capsule cancelled the first one's fade")
        #expect(panel.alphaValue == 1)
        ThawHUD.dismiss()
        #expect(!panel.isVisible)
    }

    @Test("Showing a capsule asks VoiceOver to read its text, since the capsule itself is hidden from it")
    func announcesItsText() throws {
        let screen = try #require(NSScreen.screens.first)
        let original = ThawHUD.announce
        defer { ThawHUD.announce = original }
        var announced: [String] = []
        ThawHUD.announce = { announced.append($0) }

        ThawHUD.show(symbol: "checkmark", text: "Moved to Hidden", on: screen)
        ThawHUD.dismiss()

        #expect(announced == ["Moved to Hidden"])
    }
}
