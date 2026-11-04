//
//  SettingsWindowBackground.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI

/// What the settings window draws behind its panes. Black replaces the dark look with pure black
/// for OLED displays, whether the window follows macOS or is held to dark; light mode and the
/// sidebar, toolbar and rows keep their usual look.
public enum SettingsWindowBackground: Equatable {
    case system
    case black

    public init(isBlack: Bool) {
        self = isBlack ? .black : .system
    }

    /// The color behind the panes in a color scheme. Nil leaves the window's own background.
    public func color(in scheme: ColorScheme) -> Color? {
        self == .black && scheme == .dark ? .black : nil
    }

    /// Sets the color AppKit fills the window with before SwiftUI draws, so a resize never
    /// flashes grey at the edges, and holds the window to the appearance. With the default
    /// `.system` the window keeps following macOS between light and dark.
    @MainActor
    public func apply(to window: NSWindow, appearance: SettingsWindowAppearance = .system) {
        appearance.apply(to: window)
        window.backgroundColor = self == .black ? Self.blackInDarkMode : .windowBackgroundColor
    }

    private static let blackInDarkMode = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .black : .windowBackgroundColor
    }
}

/// Whether a settings window follows macOS between light and dark or keeps one of them.
/// Holding it to an appearance also sets the color scheme inside it, sheets included.
public enum SettingsWindowAppearance: Equatable, Sendable {
    case system
    case light
    case dark

    /// The appearance the window is held to. Nil follows macOS.
    public var appearanceName: NSAppearance.Name? {
        switch self {
        case .system: nil
        case .light: .aqua
        case .dark: .darkAqua
        }
    }

    /// The color scheme inside the window, given the one macOS uses now.
    public func colorScheme(system: ColorScheme) -> ColorScheme {
        switch self {
        case .system: system
        case .light: .light
        case .dark: .dark
        }
    }

    /// Holds the window to this appearance, or lets it follow macOS again for `.system`.
    /// Leaves the window's background color alone.
    @MainActor
    public func apply(to window: NSWindow) {
        window.appearance = appearanceName.flatMap(NSAppearance.init(named:))
    }
}

public extension EnvironmentValues {
    @Entry var settingsWindowBackground = SettingsWindowBackground.system
}

public extension View {
    /// Draws the background behind this view, holds the hosting window to it, and
    /// passes it down to panes that draw their own backdrop.
    ///
    /// The window follows macOS between light and dark unless `appearance` holds it to one.
    /// Black stays black behind the panes when the window is held to dark, and a window held
    /// to light keeps its usual background.
    func settingsWindowBackground(
        _ background: SettingsWindowBackground,
        appearance: SettingsWindowAppearance = .system
    ) -> some View {
        modifier(SettingsWindowBackgroundModifier(background: background, appearance: appearance))
    }

    /// Holds the hosting window to the appearance without drawing a background or changing the
    /// window's own fill. For windows, such as onboarding, that take the settings window's light
    /// or dark look but keep their own background.
    func settingsWindowAppearance(_ appearance: SettingsWindowAppearance) -> some View {
        modifier(SettingsWindowAppearanceModifier(appearance: appearance))
    }
}

private struct SettingsWindowBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var systemScheme
    let background: SettingsWindowBackground
    let appearance: SettingsWindowAppearance
    @State private var window: NSWindow?

    func body(content: Content) -> some View {
        content
            .background {
                // The held appearance decides before the window has taken it.
                if let color = background.color(in: appearance.colorScheme(system: systemScheme)) {
                    color.ignoresSafeArea()
                }
            }
            .environment(\.settingsWindowBackground, background)
            .onWindowChange { window in
                // Apply to the window handed in: @State written here may not read back until the next update.
                self.window = window
                apply(to: window)
            }
            .onChange(of: background) {
                apply(to: window)
            }
            .onChange(of: appearance) {
                apply(to: window)
            }
    }

    private func apply(to window: NSWindow?) {
        if let window {
            background.apply(to: window, appearance: appearance)
        }
    }
}

private struct SettingsWindowAppearanceModifier: ViewModifier {
    let appearance: SettingsWindowAppearance
    @State private var window: NSWindow?

    func body(content: Content) -> some View {
        content
            .onWindowChange { window in
                // Apply to the window handed in: @State written here may not read back until the next update.
                self.window = window
                if let window {
                    appearance.apply(to: window)
                }
            }
            .onChange(of: appearance) {
                if let window {
                    appearance.apply(to: window)
                }
            }
    }
}

/// A pane's own behind-window material, or the window's black when the settings window is black
/// in dark mode, so no pane shows the desktop through it.
public struct SettingsPaneBackdrop: View {
    @Environment(\.settingsWindowBackground) private var windowBackground
    @Environment(\.colorScheme) private var colorScheme
    public let material: NSVisualEffectView.Material

    public init(
        material: NSVisualEffectView.Material
    ) {
        self.material = material
    }

    public var body: some View {
        if let color = windowBackground.color(in: colorScheme) {
            color
        } else {
            BehindWindowMaterialBackground(material: material)
        }
    }
}
