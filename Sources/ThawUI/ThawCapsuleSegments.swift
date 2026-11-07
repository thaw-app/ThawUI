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
    @State private var isMoving = false
    @State private var moveCount = 0

    /// How long the lens stays swollen after the last selection change before it settles.
    static var swellDuration: Duration {
        .milliseconds(220)
    }

    /// The clear glass lens needs transparency to read; without it, or with more contrast, the flat fill stands alone.
    static func showsLens(reduceTransparency: Bool, increasedContrast: Bool) -> Bool {
        !reduceTransparency && !increasedContrast
    }

    static func swells(moving: Bool, reduceMotion: Bool) -> Bool {
        moving && !reduceMotion
    }

    /// The lens over a segment: the segment itself at rest, wider and taller than the track while it moves.
    static func lensFrame(around segment: CGRect, moving: Bool) -> CGRect {
        guard moving else { return segment }
        let width = segment.width * 1.2
        let height = segment.height + 11
        return CGRect(x: segment.midX - width / 2, y: segment.midY - height / 2, width: width, height: height)
    }

    /// Swells the lens for the move, and settles it once no newer change has come in.
    private func swell() {
        guard !reduceMotion else { return }
        moveCount += 1
        let count = moveCount
        withAnimation(ThawMotion.selection) { isMoving = true }
        Task { @MainActor in
            try? await Task.sleep(for: Self.swellDuration)
            guard count == moveCount else { return }
            withAnimation(ThawMotion.selection) { isMoving = false }
        }
    }

    var body: some View {
        HStack(spacing: sizing.spacing) {
            ForEach(segments, id: \.value) { segment in
                segmentButton(segment)
            }
        }
        .padding(sizing.inset)
        .frame(maxWidth: sizing.maxWidth)
        // Not glass: the lens drawn over the labels has to sample the track, and glass can't sample glass.
        .thawGlass(.track, in: Capsule(style: .continuous))
        .overlayPreferenceValue(SegmentAnchorsKey.self) { anchors in
            GeometryReader { proxy in
                if Self.showsLens(reduceTransparency: reduceTransparency, increasedContrast: contrast == .increased), let anchor = anchors[AnyHashable(selection)] {
                    let frame = Self.lensFrame(around: proxy[anchor], moving: Self.swells(moving: isMoving, reduceMotion: reduceMotion))
                    Color.clear
                        .glassEffect(.clear.interactive(), in: Capsule(style: .continuous))
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        // The fill and the lens slide on the selection spring; Reduce Motion moves them without it.
        .thawAnimation(ThawMotion.selection, value: selection)
        .onChange(of: selection) { swell() }
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
                    Color.clear.thawGlass(.selection(.accentColor, strength: .selected), in: shape)
                        .matchedGeometryEffect(id: "selection", in: selectionSpace)
                }
            }
            .anchorPreference(key: SegmentAnchorsKey.self, value: .bounds) { [AnyHashable(segment.value): $0] }
            .contentShape([.interaction, .focusEffect], shape)
        }
        .buttonStyle(.plain)
        .thawSelectionCue(isSelected: isSelected, in: shape)
        .modifier(SegmentHelp(text: segment.help))
        .accessibilityLabel(Text(segment.title))
    }
}

/// Each segment's bounds, so the lens can sit over the selected one.
private struct SegmentAnchorsKey: PreferenceKey {
    static var defaultValue: [AnyHashable: Anchor<CGRect>] {
        [:]
    }

    static func reduce(value: inout [AnyHashable: Anchor<CGRect>], nextValue: () -> [AnyHashable: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
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
