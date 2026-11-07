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
    /// Which way the lens is travelling, -1 left to 1 right; the highlight leans with it.
    @State private var travelTilt: Double = 0

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

    /// The highlight's lean for a move between two segment centres: full toward the new one, none in place.
    static nonisolated func travelTilt(from oldX: CGFloat?, to newX: CGFloat?) -> Double {
        guard let oldX, let newX, oldX != newX else { return 0 }
        return newX > oldX ? 1 : -1
    }

    /// The highlight's lean while scrubbing, growing with the drag's speed up to full at 600 pt/s.
    static nonisolated func travelTilt(velocity: CGFloat) -> Double {
        min(max(Double(velocity) / 600, -1), 1)
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
        let tilt = Self.travelTilt(from: segmentFrames[lensTarget ?? value]?.midX, to: segmentFrames[value]?.midX)
        withAnimation(ThawMotion.selection) {
            lensTarget = value
            isMoving = true
            travelTilt = tilt
        }
        Task { @MainActor in
            try? await Task.sleep(for: Self.swellDuration)
            guard count == moveCount else { return }
            withAnimation(ThawMotion.selection) {
                isMoving = false
                travelTilt = 0
            }
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
                    withAnimation(ThawMotion.interactive) {
                        pointerX = drag.location.x
                        travelTilt = Self.travelTilt(velocity: drag.velocity.width)
                    }
                }
            }
            .onEnded { drag in
                if abs(drag.translation.width) > Self.scrubThreshold, let value = Self.segment(at: drag.location.x, in: segmentFrames) {
                    selection = value
                }
                withAnimation(ThawMotion.selection) {
                    isPressed = false
                    pointerX = nil
                    travelTilt = 0
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
            tilt: travelTilt,
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

/// How strongly the lens bends what's under it, from 0 (a pass-through) to 1 (mid-move).
struct LensOptics: Equatable {
    var magnification: Double
    var refraction: Double
    var chroma: Double
    /// Blur and brightening inside the lens, 0 to 1.
    var frost: Double

    static func at(strength: Double) -> LensOptics {
        LensOptics(magnification: 1 + 0.1 * strength, refraction: 0.22 * strength, chroma: 1.2 * strength, frost: strength)
    }

    private static let library = ShaderLibrary.bundle(.module)

    /// The liquidLens shader (Shaders/LiquidLens.metal) for a capsule lens at rect, in the layer's coordinates.
    func shader(lens rect: CGRect) -> Shader {
        Self.library.liquidLens(
            .float4(rect.minX, rect.minY, rect.width, rect.height),
            .float(min(rect.width, rect.height) / 2),
            .float(magnification),
            .float(refraction),
            .float(chroma),
            .float(frost)
        )
    }
}

/// Bends the control under the selection lens with the liquidLens shader and draws a glass rim over it.
/// Animatable so the lens rect and strength follow the selection spring, and redirect when interrupted.
struct LiquidLensEffect: ViewModifier, Animatable {
    /// The lens's centre line; the track doesn't move vertically, so it isn't animated.
    let midY: CGFloat
    var midX: CGFloat
    var width: CGFloat
    var height: CGFloat
    var strength: Double
    var tilt: Double
    let overhang: CGFloat
    let isActive: Bool

    init(lens: CGRect, strength: Double, tilt: Double = 0, overhang: CGFloat, isActive: Bool) {
        midY = lens.midY
        midX = lens.midX
        width = lens.width
        height = lens.height
        self.strength = strength
        self.tilt = tilt
        self.overhang = overhang
        self.isActive = isActive
    }

    /// The shader and the rim both read these, so they move together frame by frame and retarget from
    /// wherever they are when a new selection interrupts.
    nonisolated var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, AnimatablePair<Double, Double>>> {
        get { AnimatablePair(AnimatablePair(midX, width), AnimatablePair(height, AnimatablePair(strength, tilt))) }
        set {
            midX = newValue.first.first
            width = newValue.first.second
            height = newValue.second.first
            strength = newValue.second.second.first
            tilt = newValue.second.second.second
        }
    }

    var lens: CGRect {
        CGRect(x: midX - width / 2, y: midY - height / 2, width: width, height: height)
    }

    func body(content: Content) -> some View {
        let optics = LensOptics.at(strength: strength)
        let rect = lens.offsetBy(dx: overhang, dy: overhang)
        // One path whether or not the lens shows, so the control keeps its identity when it turns on or off.
        content
            // Draw into a larger layer so the swollen lens has room outside the track, then give the space back.
            .padding(overhang)
            .layerEffect(
                optics.shader(lens: rect),
                maxSampleOffset: CGSize(width: overhang * 4, height: overhang * 2),
                isEnabled: isActive && strength > 0.001
            )
            // Real glass behind the control, so the parts of the swollen lens past the track refract and
            // frost the window behind it; the shader only sees the control's own layer. The track is
            // material, so this isn't glass under glass.
            .background(alignment: .topLeading) {
                if isActive, strength > 0.001 {
                    Color.clear
                        .glassEffect(.clear, in: Capsule(style: .continuous))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                        .opacity(strength)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .topLeading) {
                if isActive {
                    LensRim(strength: strength, tilt: tilt)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .padding(-overhang)
    }
}

/// The lens's edge, after the system lens: a thin dark outline, a bright arc along the top inside edge
/// with a fainter one along the bottom, and a soft inner glow. The highlight leans toward the direction of
/// travel. Faint at rest, clear mid-move.
struct LensRim: View {
    let strength: Double
    let tilt: Double

    /// Where the highlight's light comes from: the top left at rest, leaning up to a quarter of the width
    /// either way with the travel.
    static func highlightStart(tilt: Double) -> UnitPoint {
        UnitPoint(x: 0.25 + 0.25 * min(max(tilt, -1), 1), y: 0)
    }

    var body: some View {
        let shape = Capsule(style: .continuous)
        let start = Self.highlightStart(tilt: tilt)
        ZStack {
            // Inner glow.
            shape
                .stroke(Color.white.opacity(0.35), lineWidth: 5)
                .blur(radius: 3)
                .clipShape(shape)
            // Top arc bright, bottom arc fainter, clear through the middle.
            shape
                .inset(by: 0.75)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.95), location: 0),
                            .init(color: .white.opacity(0), location: 0.4),
                            .init(color: .white.opacity(0), location: 0.65),
                            .init(color: .white.opacity(0.45), location: 1),
                        ],
                        startPoint: start,
                        endPoint: UnitPoint(x: 1 - start.x, y: 1)
                    ),
                    lineWidth: 1.5
                )
            shape.strokeBorder(Color.black.opacity(0.2), lineWidth: 0.75)
        }
        .opacity(0.3 + 0.7 * strength)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
