//
//  LauncherLook.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 René Jiménez
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI

/// A colour that can be saved: its sRGB components and opacity.
public struct StoredColor: Codable, Hashable, Sendable {
    public var red = 0.0
    public var green = 0.0
    public var blue = 0.0
    public var opacity = 1.0

    public init() {}

    public init(_ color: Color) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .white
        red = Double(resolved.redComponent)
        green = Double(resolved.greenComponent)
        blue = Double(resolved.blueComponent)
        opacity = Double(resolved.alphaComponent)
    }

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    /// The app icon's gradient, where a chosen tint or glass colour starts. Settings saved without one read these.
    public static let iconBlue = StoredColor(Color(red: 0.07, green: 0.40, blue: 0.90))
    public static let iconNavy = StoredColor(Color(red: 0.02, green: 0.10, blue: 0.40))
}

/// How a launcher panel is tinted. Apps name the choices in their own words.
public enum LauncherTintKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case solid
    case gradient

    public var id: String {
        rawValue
    }
}

public struct LauncherGradient: Codable, Hashable, Sendable {
    public var start = StoredColor.iconBlue
    public var end = StoredColor.iconNavy
    public var angle = 180.0

    public init(start: StoredColor = .iconBlue, end: StoredColor = .iconNavy, angle: Double = 180) {
        self.start = start
        self.end = end
        self.angle = angle
    }

    public var style: AnyShapeStyle {
        let radians = angle * .pi / 180
        let start = UnitPoint(x: 0.5 - sin(radians) / 2, y: 0.5 - cos(radians) / 2)
        return AnyShapeStyle(LinearGradient(
            colors: [self.start.color, end.color],
            startPoint: start,
            endPoint: UnitPoint(x: 1 - start.x, y: 1 - start.y)
        ))
    }
}

public struct LauncherTint: Codable, Hashable, Sendable {
    public var kind = LauncherTintKind.none
    public var solid = StoredColor.iconBlue
    public var gradient = LauncherGradient()
    public var opacity = 0.35

    public init(
        kind: LauncherTintKind = .none,
        solid: StoredColor = .iconBlue,
        gradient: LauncherGradient = LauncherGradient(),
        opacity: Double = 0.35
    ) {
        self.kind = kind
        self.solid = solid
        self.gradient = gradient
        self.opacity = opacity
    }

    /// The fill for the panel's shape, drawn between the glass and the
    /// content; nil when no tint is set.
    public var backgroundStyle: AnyShapeStyle? {
        switch kind {
        case .none: nil
        case .solid: AnyShapeStyle(solid.color.opacity(opacity))
        case .gradient: AnyShapeStyle(gradient.style.opacity(opacity))
        }
    }
}

public struct LauncherBorder: Codable, Hashable, Sendable {
    public var color = StoredColor(Color.white.opacity(0.6))
    public var width = 1.0

    public init(color: StoredColor = StoredColor(Color.white.opacity(0.6)), width: Double = 1) {
        self.color = color
        self.width = width
    }
}

/// The glass, tint, border and shadow a launcher panel draws.
public struct LauncherLook: Equatable, Sendable {
    public var glass: LauncherGlass
    public var tint: LauncherTint
    public var border: LauncherBorder?
    public var hasShadow: Bool

    public init(
        glass: LauncherGlass = LauncherGlass(),
        tint: LauncherTint = LauncherTint(),
        border: LauncherBorder? = nil,
        hasShadow: Bool = true
    ) {
        self.glass = glass
        self.tint = tint
        self.border = border
        self.hasShadow = hasShadow
    }

    /// The panel's own glass with nothing added: a launcher before anyone customises it.
    public static let standard = LauncherLook()
}
