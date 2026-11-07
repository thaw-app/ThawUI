//
//  ThawMotion.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI

/// Shared timing curves; apply through thawAnimation or withThawAnimation to honor Reduce Motion.
/// Keep timing and the accessibility gate here rather than duplicating them at call sites.
public enum ThawMotion {
    /// A press acknowledging itself.
    public static let instant: Animation = .easeOut(duration: 0.08)
    /// Hover, focus, and selection feedback.
    public static let quick: Animation = .easeOut(duration: 0.12)
    /// Short, insertion-only settings pane swaps; see SettingsView.paneTransition.
    public static let pane: Animation = .easeOut(duration: 0.1)
    /// A surface responding as an object: the hover lift.
    public static let interactive: Animation = .spring(response: 0.25, dampingFraction: 0.8)
    /// Layout finding its place after a change.
    public static let settle: Animation = .smooth(duration: 0.3)
    /// A segmented choice's selection sliding to the clicked segment, with a slight bounce.
    public static let selection: Animation = .spring(response: 0.3, dampingFraction: 0.78)
    /// Decoration easing in once, such as the search field's beam.
    public static let reveal: Animation = .easeOut(duration: 0.6)
    /// What a fade becomes under Reduce Motion: short, with nothing moving.
    public static let reducedFade: Animation = .easeOut(duration: 0.12)

    /// What a change does under Reduce Motion.
    public enum Reduced: Sendable {
        /// No animation; right for anything that moves or scales.
        case cut
        /// A quick fade; only for a change that alters opacity alone.
        case fade
    }

    /// The animation to use for a change, given whether Reduce Motion is on.
    static func resolved(_ animation: Animation, reduceMotion: Bool, reduced: Reduced) -> Animation? {
        guard reduceMotion else { return animation }
        return reduced == .fade ? reducedFade : nil
    }
}

// MARK: - Applying motion

public extension View {
    /// Animates value changes; under Reduce Motion it cuts, or fades quickly when reduced is .fade.
    func thawAnimation(_ animation: Animation, value: some Equatable, reduced: ThawMotion.Reduced = .cut) -> some View {
        modifier(ThawAnimationModifier(animation: animation, value: value, reduced: reduced))
    }
}

private struct ThawAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value
    let reduced: ThawMotion.Reduced

    func body(content: Content) -> some View {
        content.animation(ThawMotion.resolved(animation, reduceMotion: reduceMotion, reduced: reduced), value: value)
    }
}

public extension View {
    /// Animates only the closure's modifiers, leaving surrounding layout still, unless Reduce Motion is enabled.
    func thawAnimation(
        _ animation: Animation,
        @ViewBuilder body transform: @escaping (PlaceholderContentView<Self>) -> some View
    ) -> some View {
        ThawScopedAnimation(animation: animation, source: self, transform: transform)
    }
}

/// Preserves the concrete source type required by animation's placeholder; a ViewModifier exposes only opaque Content.
private struct ThawScopedAnimation<Source: View, Result: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let source: Source
    let transform: (PlaceholderContentView<Source>) -> Result

    var body: some View {
        source.animation(reduceMotion ? nil : animation, body: transform)
    }
}

/// Honors Reduce Motion outside SwiftUI by reading the equivalent workspace preference.
@MainActor
public func withThawAnimation<Result>(
    _ animation: Animation,
    reduced: ThawMotion.Reduced = .cut,
    _ body: () throws -> Result
) rethrows -> Result {
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    return try withAnimation(ThawMotion.resolved(animation, reduceMotion: reduceMotion, reduced: reduced), body)
}
