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
    @State private var segmentFrames: [Value: CGRect] = [:]
    /// The segment the lens is over. Moved under an explicit animation, so the lens slides even when the
    /// caller changes the selection in a transaction that turns implicit animations off.
    @State private var lensTarget: Value?
    /// Held from mouse-down to release, like the system control: the lens swells on press, not on release.
    @State private var isPressed = false
    /// Where a drag across the track has the lens, in the track's coordinates; nil when not scrubbing.
    @State private var pointerX: CGFloat?
    @State private var trackSize: CGSize = .zero

    /// Room around the control for the swollen lens, so the effect isn't clipped to the track.
    /// Wide segments swell further sideways, so the room grows with them.
    static nonisolated func lensOverhang(widestSegment: CGFloat) -> CGFloat {
        max(12, (widestSegment * (swollenWidthScale - 1) / 2).rounded(.up) + 2)
    }

    static nonisolated var swollenWidthScale: CGFloat {
        1.18
    }

    /// How far the swollen lens stands above the track, top and bottom together, as the system control does.
    static nonisolated var swollenHeightGain: CGFloat {
        10
    }

    /// A drag shorter than this is a click; the segment's button handles it.
    static nonisolated var scrubThreshold: CGFloat {
        3
    }

    /// How long the lens stays swollen after the last selection change before it settles.
    static nonisolated var swellDuration: Duration {
        .milliseconds(220)
    }

    /// The lens needs transparency to read; without it, or with more contrast, the flat fill stands alone.
    static nonisolated func showsLens(reduceTransparency: Bool, increasedContrast: Bool) -> Bool {
        !reduceTransparency && !increasedContrast
    }

    static nonisolated func swells(pressed: Bool, moving: Bool, reduceMotion: Bool) -> Bool {
        (pressed || moving) && !reduceMotion
    }

    /// The lens over a segment: the segment itself at rest; while pressed or moving, wider and taller than the
    /// track. A scrub centres it on the pointer, kept within the track.
    static nonisolated func lensFrame(around segment: CGRect, trackSize: CGSize, swollen: Bool, pointerX: CGFloat? = nil) -> CGRect {
        let midX = pointerX.map { clampedLensX($0, segmentWidth: segment.width, trackWidth: trackSize.width) } ?? segment.midX
        let width = swollen ? segment.width * swollenWidthScale : segment.width
        let height = swollen ? trackSize.height + swollenHeightGain : segment.height
        return CGRect(x: midX - width / 2, y: segment.midY - height / 2, width: width, height: height)
    }

    /// The pointer's x, held far enough inside the track that a segment-wide lens stays on it.
    static nonisolated func clampedLensX(_ x: CGFloat, segmentWidth: CGFloat, trackWidth: CGFloat) -> CGFloat {
        let low = segmentWidth / 2
        let high = max(trackWidth - segmentWidth / 2, low)
        return min(max(x, low), high)
    }

    /// The segment a scrub ends on: the one under the pointer, else the one whose centre is closest.
    static nonisolated func segment(at x: CGFloat, in frames: [Value: CGRect]) -> Value? {
        if let hit = frames.first(where: { $0.value.minX <= x && x <= $0.value.maxX }) {
            return hit.key
        }
        return frames.min { abs($0.value.midX - x) < abs($1.value.midX - x) }?.key
    }

    /// Slides the lens to the new selection and swells it, then settles it once no newer change has come in.
    /// Reduce Motion moves it without either.
    private func moveLens(to value: Value) {
        guard !reduceMotion else {
            lensTarget = value
            return
        }
        moveCount += 1
        let count = moveCount
        withAnimation(ThawMotion.selection) {
            lensTarget = value
            isMoving = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: Self.swellDuration)
            guard count == moveCount else { return }
            withAnimation(ThawMotion.selection) { isMoving = false }
        }
    }

    /// Press swells the lens in place; dragging scrubs it along the track, and release selects the segment
    /// under the pointer. A click without a drag leaves the selection to the segment's button.
    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(SegmentSpace.name))
            .onChanged { drag in
                guard !reduceMotion else { return }
                if !isPressed {
                    withAnimation(ThawMotion.selection) { isPressed = true }
                }
                if abs(drag.translation.width) > Self.scrubThreshold {
                    withAnimation(ThawMotion.interactive) { pointerX = drag.location.x }
                }
            }
            .onEnded { drag in
                if abs(drag.translation.width) > Self.scrubThreshold, let value = Self.segment(at: drag.location.x, in: segmentFrames) {
                    selection = value
                }
                withAnimation(ThawMotion.selection) {
                    isPressed = false
                    pointerX = nil
                }
            }
    }

    var body: some View {
        let lensShown = Self.showsLens(reduceTransparency: reduceTransparency, increasedContrast: contrast == .increased)
        let swollen = Self.swells(pressed: isPressed, moving: isMoving, reduceMotion: reduceMotion)
        let lensSegment = segmentFrames[lensTarget ?? selection]
        let overhang = Self.lensOverhang(widestSegment: segmentFrames.values.map(\.width).max() ?? 0)
        HStack(spacing: sizing.spacing) {
            ForEach(segments, id: \.value) { segment in
                segmentButton(segment)
            }
        }
        .padding(sizing.inset)
        .frame(maxWidth: sizing.maxWidth)
        // Material, not glass: the lens shader samples the rendered layer, and glass isn't in it.
        .thawGlass(.track, in: Capsule(style: .continuous))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { trackSize = $0 }
        .coordinateSpace(.named(SegmentSpace.name))
        .simultaneousGesture(scrub)
        .modifier(LiquidLensEffect(
            lens: lensSegment.map { Self.lensFrame(around: $0, trackSize: trackSize, swollen: swollen, pointerX: pointerX) } ?? .zero,
            strength: swollen ? 1 : 0,
            overhang: overhang,
            isActive: lensShown && lensSegment != nil
        ))
        // The fill and the lens slide on the selection spring; Reduce Motion moves them without it.
        .thawAnimation(ThawMotion.selection, value: selection)
        .onAppear { lensTarget = selection }
        .onChange(of: selection) { _, value in moveLens(to: value) }
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
                if segment.value == (lensTarget ?? selection) {
                    Color.clear.thawGlass(.selection(.accentColor, strength: .selected), in: shape)
                        .matchedGeometryEffect(id: "selection", in: selectionSpace)
                }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(SegmentSpace.name)) } action: { segmentFrames[segment.value] = $0 }
            .contentShape([.interaction, .focusEffect], shape)
        }
        .buttonStyle(.plain)
        .thawSelectionCue(isSelected: isSelected, in: shape)
        .modifier(SegmentHelp(text: segment.help))
        .accessibilityLabel(Text(segment.title))
    }
}

private enum SegmentSpace {
    static let name = "ThawCapsuleSegments"
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
