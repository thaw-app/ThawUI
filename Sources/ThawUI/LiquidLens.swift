//
//  LiquidLens.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 René Jiménez
//  Licensed under the GNU GPLv3

import SwiftUI

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

    /// The shaders precompiled from Shaders/ by scripts/build-shaders.sh.
    private static let library = Bundle.module.url(forResource: "ThawUI", withExtension: "metallib")
        .map { ShaderLibrary(url: $0) } ?? .bundle(.module)

    /// The liquidLens shader (Shaders/LiquidLens.metal, at the package root) for a capsule lens at rect,
    /// in the layer's coordinates.
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

/// The lens's edge: a specular highlight from the top left, and a faint inner shadow. Faint at rest, clear mid-move.
private struct LensRim: View {
    let strength: Double

    var body: some View {
        let shape = Capsule(style: .continuous)
        ZStack {
            shape
                .stroke(Color.black.opacity(0.12), lineWidth: 2)
                .blur(radius: 1.5)
                .clipShape(shape)
            // Specular: light from the top left, a dimmer bounce at the bottom right.
            shape.strokeBorder(
                LinearGradient(
                    stops: [.init(color: .white.opacity(0.95), location: 0), .init(color: .white.opacity(0.15), location: 0.45), .init(color: .white.opacity(0.4), location: 1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .opacity(0.3 + 0.7 * strength)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
