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

    /// Room around the control for the swollen lens, so the effect isn't clipped to the track.
    static var lensOverhang: CGFloat {
        12
    }

    /// How long the lens stays swollen after the last selection change before it settles.
    static var swellDuration: Duration {
        .milliseconds(220)
    }

    /// The lens needs transparency to read; without it, or with more contrast, the flat fill stands alone.
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

    var body: some View {
        let lensShown = Self.showsLens(reduceTransparency: reduceTransparency, increasedContrast: contrast == .increased)
        let swollen = Self.swells(moving: isMoving, reduceMotion: reduceMotion)
        let lensSegment = segmentFrames[lensTarget ?? selection]
        HStack(spacing: sizing.spacing) {
            ForEach(segments, id: \.value) { segment in
                segmentButton(segment)
            }
        }
        .padding(sizing.inset)
        .frame(maxWidth: sizing.maxWidth)
        // Material, not glass: the lens shader samples the rendered layer, and glass isn't in it.
        .thawGlass(.track, in: Capsule(style: .continuous))
        .coordinateSpace(.named(SegmentSpace.name))
        .modifier(LiquidLensEffect(
            lens: lensSegment.map { Self.lensFrame(around: $0, moving: swollen) } ?? .zero,
            strength: swollen ? 1 : 0,
            overhang: Self.lensOverhang,
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

    static func at(strength: Double) -> LensOptics {
        LensOptics(magnification: 1 + 0.15 * strength, refraction: 0.22 * strength, chroma: 1.5 * strength)
    }

    private static let library = ShaderLibrary.bundle(.module)

    /// The liquidLens shader (Shaders/LiquidLens.metal) for a capsule lens at rect, in the layer's coordinates.
    func shader(lens rect: CGRect) -> Shader {
        Self.library.liquidLens(
            .float4(rect.minX, rect.minY, rect.width, rect.height),
            .float(min(rect.width, rect.height) / 2),
            .float(magnification),
            .float(refraction),
            .float(chroma)
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
    let overhang: CGFloat
    let isActive: Bool

    init(lens: CGRect, strength: Double, overhang: CGFloat, isActive: Bool) {
        midY = lens.midY
        midX = lens.midX
        width = lens.width
        height = lens.height
        self.strength = strength
        self.overhang = overhang
        self.isActive = isActive
    }

    /// The shader and the rim both read these, so they move together frame by frame and retarget from
    /// wherever they are when a new selection interrupts.
    nonisolated var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, Double>> {
        get { AnimatablePair(AnimatablePair(midX, width), AnimatablePair(height, strength)) }
        set {
            midX = newValue.first.first
            width = newValue.first.second
            height = newValue.second.first
            strength = newValue.second.second
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
            .overlay(alignment: .topLeading) {
                if isActive {
                    LensRim(strength: strength)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .padding(-overhang)
    }
}

/// The lens's edge: a highlight brighter along the top, and a faint inner shadow. Faint at rest, clear mid-move.
private struct LensRim: View {
    let strength: Double

    var body: some View {
        let shape = Capsule(style: .continuous)
        ZStack {
            shape
                .stroke(Color.black.opacity(0.12), lineWidth: 2)
                .blur(radius: 1.5)
                .clipShape(shape)
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.1), .white.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                lineWidth: 0.75
            )
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
