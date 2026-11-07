//
//  ThawTogglePills.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// Switches that turn on and off independently, in the capsule a ThawPillPicker
/// draws, for a row where several choices can be on at once.
public struct ThawTogglePills<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: ThawTogglePillStyle.Metrics.spacing) {
            content
        }
        .toggleStyle(ThawTogglePillStyle())
        .padding(ThawTogglePillStyle.Metrics.inset)
        .thawGlass(.control, in: Capsule(style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// One switch drawn as a ThawPillPicker segment: filled and heavier while on.
struct ThawTogglePillStyle: ToggleStyle {
    /// The capsule's measurements, the ones ThawPillPicker used before it became the system's segmented control.
    enum Metrics {
        static let spacing = ThawSpacing.hairline
        static let inset = ThawSpacing.capsuleInset
        static let horizontalPadding = ThawSpacing.row
        static let minWidth: CGFloat = 28
        static let minHeight: CGFloat = 24
    }

    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        let shape = Capsule(style: .continuous)
        return Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .font(ThawType.body.weight(isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, Metrics.horizontalPadding)
                .frame(minWidth: Metrics.minWidth, minHeight: Metrics.minHeight)
                .thawSelectedFill(isOn, in: shape)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .thawSelectionCue(isSelected: isOn, in: shape)
        // A system switch reads its state in the user's language, so ThawUI needs no text of its own.
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
