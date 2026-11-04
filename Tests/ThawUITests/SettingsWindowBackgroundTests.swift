//
//  SettingsWindowBackgroundTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI
import Testing
@testable import ThawUI

@Suite("Settings window background")
@MainActor
struct SettingsWindowBackgroundTests {
    @Test("Black replaces the dark look only and never pins the appearance")
    func colorFollowsTheScheme() {
        #expect(SettingsWindowBackground.black.color(in: .dark) == .black)
        #expect(SettingsWindowBackground.black.color(in: .light) == nil)
        #expect(SettingsWindowBackground.system.color(in: .dark) == nil)
    }

    @Test("The setting picks the background")
    func fromSetting() {
        #expect(SettingsWindowBackground(isBlack: true) == .black)
        #expect(SettingsWindowBackground(isBlack: false) == .system)
    }

    @Test("A black window fills black in dark mode, keeps its usual fill in light mode, and follows macOS")
    func applyToWindow() throws {
        let window = NSWindow(contentRect: .zero, styleMask: .titled, backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false

        SettingsWindowBackground.black.apply(to: window)
        #expect(window.appearance == nil)
        #expect(try brightness(of: window.backgroundColor, in: .darkAqua) == 0)
        #expect(try brightness(of: window.backgroundColor, in: .aqua) > 0.5)

        SettingsWindowBackground.system.apply(to: window)
        #expect(window.appearance == nil)
        #expect(window.backgroundColor == .windowBackgroundColor)
    }

    @Test("Each appearance names the look it holds the window to", arguments: [
        (SettingsWindowAppearance.system, NSAppearance.Name?.none),
        (.light, .aqua),
        (.dark, .darkAqua),
    ])
    func appearanceName(appearance: SettingsWindowAppearance, expected: NSAppearance.Name?) {
        #expect(appearance.appearanceName == expected)
    }

    @Test("A held appearance decides the color scheme; system passes macOS's through")
    func colorScheme() {
        for system in [ColorScheme.light, .dark] {
            #expect(SettingsWindowAppearance.system.colorScheme(system: system) == system)
            #expect(SettingsWindowAppearance.light.colorScheme(system: system) == .light)
            #expect(SettingsWindowAppearance.dark.colorScheme(system: system) == .dark)
        }
    }

    @Test("Holding a window to an appearance sets it, and system lets it follow macOS again")
    func applyAppearance() {
        let window = makeWindow()
        window.backgroundColor = .red

        SettingsWindowAppearance.dark.apply(to: window)
        #expect(window.appearance?.name == .darkAqua)
        SettingsWindowAppearance.light.apply(to: window)
        #expect(window.appearance?.name == .aqua)
        SettingsWindowAppearance.system.apply(to: window)
        #expect(window.appearance == nil)
        #expect(window.backgroundColor == .red)
    }

    @Test("A black window held to dark fills black; held to light it keeps its usual fill")
    func applyBlackWithAppearance() throws {
        let window = makeWindow()

        SettingsWindowBackground.black.apply(to: window, appearance: .dark)
        #expect(window.appearance?.name == .darkAqua)
        #expect(try brightness(of: window.backgroundColor, in: window.effectiveAppearance.name) == 0)

        SettingsWindowBackground.black.apply(to: window, appearance: .light)
        #expect(window.appearance?.name == .aqua)
        #expect(try brightness(of: window.backgroundColor, in: window.effectiveAppearance.name) > 0.5)

        SettingsWindowBackground.system.apply(to: window, appearance: .dark)
        #expect(window.appearance?.name == .darkAqua)
        #expect(window.backgroundColor == .windowBackgroundColor)
    }

    @Test("A black window held to dark draws black even where macOS is light")
    func drawsBlackWhenHeldDark() throws {
        let view = Color.clear
            .settingsWindowBackground(.black, appearance: .dark)
            .environment(\.colorScheme, .light)
            .frame(width: 40, height: 40)
        let render = OffscreenRender(view, size: CGSize(width: 40, height: 40))
        #expect(try isBlack(render.pixels()))
    }

    @Test("A black window held to light draws no black even where macOS is dark")
    func noBlackWhenHeldLight() throws {
        let view = Color.clear
            .settingsWindowBackground(.black, appearance: .light)
            .environment(\.colorScheme, .dark)
            .frame(width: 40, height: 40)
        let render = OffscreenRender(view, size: CGSize(width: 40, height: 40))
        #expect(try !isBlack(render.pixels()))
    }

    @Test("A window that only takes the appearance draws nothing behind its content")
    func appearanceOnlyDrawsNothing() throws {
        let view = Color.clear
            .settingsWindowAppearance(.dark)
            .environment(\.colorScheme, .dark)
            .frame(width: 40, height: 40)
        let render = OffscreenRender(view, size: CGSize(width: 40, height: 40))
        #expect(try !isBlack(render.pixels()))
    }

    @Test("The modifiers hold the hosting window to the appearance once it has one")
    func modifiersApplyToHostingWindow() async {
        let background = makeWindow()
        background.contentView = NSHostingView(rootView: Color.clear.settingsWindowBackground(.black, appearance: .dark))
        let onboarding = makeWindow()
        onboarding.backgroundColor = .red
        onboarding.contentView = NSHostingView(rootView: Color.clear.settingsWindowAppearance(.light))

        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while ContinuousClock.now < deadline, background.appearance == nil || onboarding.appearance == nil {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(background.appearance?.name == .darkAqua)
        #expect(onboarding.appearance?.name == .aqua)
        #expect(onboarding.backgroundColor == .red)
    }

    @Test("A black window draws black behind its content in dark mode only")
    func drawsBlackInDarkModeOnly() throws {
        let dark = OffscreenRender(backgroundView(.dark), size: CGSize(width: 40, height: 40))
        #expect(try isBlack(dark.pixels()))
        let light = OffscreenRender(backgroundView(.light), size: CGSize(width: 40, height: 40))
        #expect(try !isBlack(light.pixels()))
    }

    @Test("A pane backdrop turns black on a black window in dark mode")
    func paneBackdrop() throws {
        let view = SettingsPaneBackdrop(material: .sidebar)
            .environment(\.settingsWindowBackground, .black)
            .environment(\.colorScheme, .dark)
            .frame(width: 40, height: 40)
        let render = OffscreenRender(view, size: CGSize(width: 40, height: 40))
        #expect(try isBlack(render.pixels()))
    }

    @Test("A pane backdrop keeps its material on the system background and in light mode")
    func paneBackdropMaterial() {
        for (background, scheme) in [(SettingsWindowBackground.system, ColorScheme.dark), (.black, .light)] {
            let view = SettingsPaneBackdrop(material: .sidebar)
                .environment(\.settingsWindowBackground, background)
                .environment(\.colorScheme, scheme)
                .frame(width: 40, height: 40)
            let render = OffscreenRender(view, size: CGSize(width: 40, height: 40))
            #expect(render.host.subviews.contains { containsEffectView($0) })
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .titled, backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        return window
    }

    private func backgroundView(_ scheme: ColorScheme) -> some View {
        Color.clear
            .settingsWindowBackground(.black)
            .environment(\.colorScheme, scheme)
            .frame(width: 40, height: 40)
    }

    private func brightness(of color: NSColor, in appearance: NSAppearance.Name) throws -> CGFloat {
        var resolved: NSColor?
        try #require(NSAppearance(named: appearance)).performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB)
        }
        return try #require(resolved).brightnessComponent
    }

    /// RGBA: pure black is opaque with every color byte at zero.
    private func isBlack(_ pixels: Data) -> Bool {
        pixels.enumerated().allSatisfy { index, byte in index % 4 == 3 ? byte == 255 : byte == 0 }
    }

    private func containsEffectView(_ view: NSView) -> Bool {
        view is NSVisualEffectView || view.subviews.contains { containsEffectView($0) }
    }
}
