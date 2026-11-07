//
//  ThawCapsuleSegments.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// One choice in a ThawPillPicker or one tab in a ThawTabStrip.
public struct ThawSegment<Value: Hashable> {
    let value: Value
    let title: LocalizedStringResource
    let systemImage: String?
    let help: LocalizedStringResource?

    public init(_ value: Value, title: LocalizedStringResource, systemImage: String? = nil, help: LocalizedStringResource? = nil) {
        self.value = value
        self.title = title
        self.systemImage = systemImage
        self.help = help
    }
}

/// The glass capsule of segments that ThawPillPicker and ThawTabStrip draw:
/// one plain button per value, the selected one filled and in a heavier weight.
struct ThawCapsuleSegments<Value: Hashable>: View {
    /// How the capsule and its segments take up space.
    enum Sizing: Equatable {
        /// Each segment as wide as its label, which may be a symbol alone.
        case fitted(showsTitles: Bool)
        /// The segments share the width evenly and the capsule fills its container.
        case filling

        var showsTitles: Bool {
            switch self {
            case let .fitted(showsTitles): showsTitles
            case .filling: true
            }
        }

        var spacing: CGFloat {
            self == .filling ? ThawSpacing.tight : ThawSpacing.hairline
        }

        var inset: CGFloat {
            self == .filling ? ThawSpacing.tight : ThawSpacing.capsuleInset
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .filling: ThawSpacing.inset
            case .fitted(showsTitles: true): ThawSpacing.row
            case .fitted(showsTitles: false): ThawSpacing.compact
            }
        }

        var minWidth: CGFloat? {
            self == .filling ? nil : 28
        }

        var maxWidth: CGFloat? {
            self == .filling ? .infinity : nil
        }

        var minHeight: CGFloat {
            self == .filling ? 30 : 24
        }

        var maxHeight: CGFloat? {
            self == .filling ? 30 : nil
        }
    }

    @Binding var selection: Value
    let segments: [ThawSegment<Value>]
    let sizing: Sizing

    @Namespace private var selectionSpace
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLifted = false
    @State private var liftCount = 0

    /// How long the lens stays lifted after the last selection change before it settles.
    static var liftDuration: Duration {
        .milliseconds(170)
    }

    static func indicatorSurface(reduceTransparency: Bool, increasedContrast: Bool) -> SegmentIndicatorSurface {
        reduceTransparency || increasedContrast ? .flat : .glass
    }

    /// While the selection moves, a larger glass lens; at rest, the flat fill. Accessibility settings keep the fill.
    static func indicatorAppearance(
        lifted: Bool,
        reduceTransparency: Bool,
        increasedContrast: Bool,
        reduceMotion: Bool
    ) -> SegmentIndicatorAppearance {
        let lifts = lifted && !reduceMotion && indicatorSurface(reduceTransparency: reduceTransparency, increasedContrast: increasedContrast) == .glass
        return lifts ? .lifted : .resting
    }

    private var appearance: SegmentIndicatorAppearance {
        Self.indicatorAppearance(
            lifted: isLifted,
            reduceTransparency: reduceTransparency,
            increasedContrast: contrast == .increased,
            reduceMotion: reduceMotion
        )
    }

    /// Lifts the lens for the move, and settles it once no newer change has come in.
    private func lift() {
        guard Self.indicatorAppearance(
            lifted: true,
            reduceTransparency: reduceTransparency,
            increasedContrast: contrast == .increased,
            reduceMotion: reduceMotion
        ).showsLens else { return }
        liftCount += 1
        let count = liftCount
        withAnimation(ThawMotion.selection) { isLifted = true }
        Task { @MainActor in
            try? await Task.sleep(for: Self.liftDuration)
            guard count == liftCount else { return }
            withAnimation(.smooth(duration: 0.18)) { isLifted = false }
        }
    }

    var body: some View {
        HStack(spacing: sizing.spacing) {
            ForEach(segments, id: \.value) { segment in
                segmentButton(segment)
            }
        }
        // One indicator moves between segments; Reduce Motion moves it without the slide.
        .thawAnimation(ThawMotion.selection, value: selection)
        .onChange(of: selection) { lift() }
        .padding(sizing.inset)
        .frame(maxWidth: sizing.maxWidth)
        .thawGlass(.control, in: Capsule(style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func segmentButton(_ segment: ThawSegment<Value>) -> some View {
        let isSelected = segment.value == selection
        let shape = Capsule(style: .continuous)
        // Styled on each part: a section header sets its own text colour over the label's.
        let style = isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(ThawInk.supporting)
        let weight: Font.Weight = isSelected ? .semibold : .regular
        return Button {
            selection = segment.value
        } label: {
            HStack(spacing: ThawSpacing.tight) {
                if let systemImage = segment.systemImage {
                    Image(systemName: systemImage)
                        .font(ThawType.symbol.weight(weight))
                        .foregroundStyle(style)
                }
                if sizing.showsTitles {
                    Text(segment.title)
                        .font(ThawType.body.weight(weight))
                        .foregroundStyle(style)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .padding(.horizontal, sizing.horizontalPadding)
            .frame(
                minWidth: sizing.minWidth,
                maxWidth: sizing.maxWidth,
                minHeight: sizing.minHeight,
                maxHeight: sizing.maxHeight
            )
            .background {
                if isSelected {
                    SegmentSelectionIndicator(appearance: appearance, shape: shape)
                        .matchedGeometryEffect(id: "selection", in: selectionSpace)
                }
            }
            .contentShape([.interaction, .focusEffect], shape)
        }
        .buttonStyle(.plain)
        .thawSelectionCue(isSelected: isSelected, in: shape)
        .modifier(SegmentHelp(text: segment.help))
        .accessibilityLabel(Text(segment.title))
    }
}

/// What the sliding selection is drawn with.
enum SegmentIndicatorSurface: Equatable {
    /// A clear glass lens under the flat selection fill.
    case glass
    /// The flat fill alone, which stays legible without transparency or with more contrast.
    case flat
}

/// How the selection indicator looks in one phase of a move.
struct SegmentIndicatorAppearance: Equatable {
    /// Whether a glass lens shows instead of the flat fill.
    let showsLens: Bool
    let scale: CGFloat
    let fillOpacity: Double

    static let lifted = SegmentIndicatorAppearance(showsLens: true, scale: 1.12, fillOpacity: 0)
    static let resting = SegmentIndicatorAppearance(showsLens: false, scale: 1, fillOpacity: 1)
}

/// The selected segment's background: the flat selection fill at rest, a lifted glass lens while it moves.
private struct SegmentSelectionIndicator<S: InsettableShape>: View {
    let appearance: SegmentIndicatorAppearance
    let shape: S

    var body: some View {
        ZStack {
            if appearance.showsLens {
                Color.clear.glassEffect(.regular.interactive(), in: shape)
                    .transition(.opacity)
            }
            Color.clear.thawGlass(.selection(.accentColor, strength: .selected), in: shape)
                .opacity(appearance.fillOpacity)
        }
        .scaleEffect(appearance.scale)
        .shadow(color: .black.opacity(appearance.showsLens ? 0.2 : 0), radius: 6, y: 2)
    }
}

/// A segment's tooltip, left off entirely when it has none, so an empty one
/// never covers a tooltip set further out.
private struct SegmentHelp: ViewModifier {
    let text: LocalizedStringResource?

    func body(content: Content) -> some View {
        if let text {
            content.help(Text(text))
        } else {
            content
        }
    }
}
