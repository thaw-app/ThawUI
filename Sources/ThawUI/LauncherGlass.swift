//
//  LauncherGlass.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 René Jiménez
//  Licensed under the GNU GPLv3
//
//  Ported to the launcher from Thaw 3's menu bar glass: MenuBarGlassStyle, the system glass lookup of
//  MenuBarAppearanceManager, ThawBar's glass surface and the dark fade of the menu bar overlay. The
//  launcher is one rounded rectangle, so a single glass view stands in for Thaw's one per component
//  of the menu bar's shape, and the fade is a SwiftUI gradient rather than a drawn view.

import AppKit
import SwiftUI

/// Which glass the launcher panel is made of.
public enum LauncherGlassStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case regular
    case clear
    /// Clear Liquid Glass without a color wash.
    case liquid
    /// Clear Liquid Glass with a dark-to-clear vertical fade.
    case dynamic

    public var id: String {
        rawValue
    }

    public var nsGlassStyle: NSGlassEffectView.Style {
        switch self {
        case .regular: .regular
        case .clear, .liquid, .dynamic: .clear
        }
    }

    public var usesTint: Bool {
        self == .liquid || self == .dynamic
    }

    public var usesDarkFade: Bool {
        self == .dynamic
    }

    public var effectOpacity: Double {
        switch self {
        case .regular, .clear: 1
        case .liquid, .dynamic: 0.45
        }
    }
}

/// The launcher's glass: the style, whether it follows the system's, and the
/// colour the Liquid styles may be washed with.
public struct LauncherGlass: Codable, Hashable, Sendable {
    public var style = LauncherGlassStyle.regular
    /// Whether the style follows Liquid Glass in System Settings instead of `style`.
    public var followsSystem = false
    public var isColored = false
    public var color = StoredColor.iconBlue
    public var opacity = 0.35

    public init(
        style: LauncherGlassStyle = .regular,
        followsSystem: Bool = false,
        isColored: Bool = false,
        color: StoredColor = .iconBlue,
        opacity: Double = 0.35
    ) {
        self.style = style
        self.followsSystem = followsSystem
        self.isColored = isColored
        self.color = color
        self.opacity = opacity
    }

    /// NSGlassTintAmount is 0 for Clear, 1 for Tinted, and intermediate during animation.
    public static var systemGlassIsTinted: Bool {
        UserDefaults.standard.double(forKey: "NSGlassTintAmount") >= 0.5
    }

    /// The style that is drawn: Regular while the system's glass is Tinted and Clear while it is
    /// Clear when following the system, the chosen one otherwise.
    public func resolvedStyle(systemGlassIsTinted: Bool = LauncherGlass.systemGlassIsTinted) -> LauncherGlassStyle {
        guard followsSystem else { return style }
        return systemGlassIsTinted ? .regular : .clear
    }

    /// The wash over the glass; nil unless the style takes one and it is turned on.
    public func tintColor(for style: LauncherGlassStyle) -> NSColor? {
        guard style.usesTint, isColored else { return nil }
        return NSColor(color.color).withAlphaComponent(opacity)
    }
}

/// The glass behind the launcher for every style but Regular, which stays the panel's own.
public struct LauncherGlassBackdrop: View {
    let style: LauncherGlassStyle
    let tint: NSColor?
    let cornerRadius: CGFloat
    var cornerStyle = RoundedCornerStyle.continuous
    /// The share of the launcher's height this glass covers: two pieces carry one fade between them.
    var span: ClosedRange<CGFloat> = 0 ... 1

    public init(
        style: LauncherGlassStyle,
        tint: NSColor?,
        cornerRadius: CGFloat,
        cornerStyle: RoundedCornerStyle = .continuous,
        span: ClosedRange<CGFloat> = 0 ... 1
    ) {
        self.style = style
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.cornerStyle = cornerStyle
        self.span = span
    }

    public var body: some View {
        let length = span.upperBound - span.lowerBound
        LauncherGlassSurface(style: style, tint: tint, cornerRadius: cornerRadius)
            .overlay {
                if style.usesDarkFade {
                    // Keep the upper third dense for legible titles on bright wallpaper; reveal glass through the lower half.
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.96), location: 0),
                            .init(color: .black.opacity(0.88), location: 0.3),
                            .init(color: .black.opacity(0.42), location: 0.62),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: UnitPoint(x: 0.5, y: (0 - span.lowerBound) / length),
                        endPoint: UnitPoint(x: 0.5, y: (1 - span.lowerBound) / length)
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: cornerStyle))
            .allowsHitTesting(false)
    }
}

private struct LauncherGlassSurface: NSViewRepresentable {
    let style: LauncherGlassStyle
    let tint: NSColor?
    let cornerRadius: CGFloat

    func makeNSView(context _: Context) -> SurfaceView {
        SurfaceView()
    }

    func updateNSView(_ view: SurfaceView, context _: Context) {
        view.glass.style = style.nsGlassStyle
        view.glass.cornerRadius = cornerRadius
        view.glass.alphaValue = style.effectOpacity
        view.glass.tintColor = tint
    }

    final class SurfaceView: NSView {
        let glass = NSGlassEffectView()

        override init(frame: NSRect) {
            super.init(frame: frame)
            glass.frame = bounds
            glass.autoresizingMask = [.width, .height]
            addSubview(glass)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }
    }
}
