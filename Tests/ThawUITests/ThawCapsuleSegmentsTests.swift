//
//  ThawCapsuleSegmentsTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI
import Testing
@testable import ThawUI

@Suite("Capsule segments")
struct ThawCapsuleSegmentsTests {
    private typealias Sizing = ThawCapsuleSegments<Int>.Sizing

    @Test("A tab strip fills its row and gives every tab the same height")
    func fillingSizing() {
        let sizing = Sizing.filling
        #expect(sizing.showsTitles)
        #expect(sizing.maxWidth == .infinity)
        #expect(sizing.minWidth == nil)
        #expect(sizing.minHeight == 30)
        #expect(sizing.maxHeight == 30)
        #expect(sizing.inset == ThawSpacing.tight)
        #expect(sizing.horizontalPadding == ThawSpacing.inset)
    }

    @Test("A pill picker sizes to its labels, inset like an action group")
    func fittedSizing() {
        let titled = Sizing.fitted(showsTitles: true)
        #expect(titled.showsTitles)
        #expect(titled.maxWidth == nil)
        #expect(titled.inset == ThawSpacing.capsuleInset)
        #expect(titled.spacing == ThawSpacing.hairline)
        #expect(titled.horizontalPadding == ThawSpacing.row)
    }

    @Test("A symbol-only pill keeps a minimum width for its symbol")
    func symbolOnlySizing() {
        let symbols = Sizing.fitted(showsTitles: false)
        #expect(!symbols.showsTitles)
        #expect(symbols.minWidth == 28)
        #expect(symbols.horizontalPadding < Sizing.fitted(showsTitles: true).horizontalPadding)
    }

    @Test("The selection slides on a short spring with a slight bounce")
    func selectionMotion() {
        #expect(ThawMotion.selection == .spring(response: 0.3, dampingFraction: 0.78))
    }

    @Test("The lens shows over the selection only when transparency and contrast allow it")
    func lensVisibility() {
        typealias Segments = ThawCapsuleSegments<Int>
        #expect(Segments.showsLens(reduceTransparency: false, increasedContrast: false))
        #expect(!Segments.showsLens(reduceTransparency: true, increasedContrast: false))
        #expect(!Segments.showsLens(reduceTransparency: false, increasedContrast: true))
    }

    @Test("At rest the lens covers its segment; pressed or moving it swells wider and past the track")
    func lensFrame() {
        typealias Segments = ThawCapsuleSegments<Int>
        let track = CGSize(width: 240, height: 38)
        let segment = CGRect(x: 84, y: 4, width: 80, height: 30)
        #expect(Segments.lensFrame(around: segment, trackSize: track, swollen: false) == segment)
        let swollen = Segments.lensFrame(around: segment, trackSize: track, swollen: true)
        #expect(abs(swollen.width - 94.4) < 0.001)
        #expect(swollen.height == 48)
        #expect(swollen.midX == segment.midX && swollen.midY == segment.midY)
    }

    @Test("A scrub centres the lens on the pointer, kept inside the track")
    func scrubFollowsPointer() {
        typealias Segments = ThawCapsuleSegments<Int>
        let track = CGSize(width: 240, height: 38)
        let segment = CGRect(x: 4, y: 4, width: 80, height: 30)
        #expect(Segments.lensFrame(around: segment, trackSize: track, swollen: true, pointerX: 130).midX == 130)
        #expect(Segments.clampedLensX(-50, segmentWidth: 80, trackWidth: 240) == 40)
        #expect(Segments.clampedLensX(400, segmentWidth: 80, trackWidth: 240) == 200)
        #expect(Segments.clampedLensX(120, segmentWidth: 80, trackWidth: 240) == 120)
    }

    @Test("Releasing a scrub picks the segment under the pointer, or the closest one off its ends")
    func scrubPicksSegment() {
        typealias Segments = ThawCapsuleSegments<Int>
        let frames = [1: CGRect(x: 4, y: 4, width: 80, height: 30), 2: CGRect(x: 86, y: 4, width: 80, height: 30), 3: CGRect(x: 168, y: 4, width: 68, height: 30)]
        #expect(Segments.segment(at: 40, in: frames) == 1)
        #expect(Segments.segment(at: 120, in: frames) == 2)
        #expect(Segments.segment(at: 300, in: frames) == 3)
        #expect(Segments.segment(at: -10, in: frames) == 1)
        #expect(Segments.segment(at: 10, in: [:]) == nil)
    }

    @Test("The lens bends nothing at rest and magnifies, refracts, fringes and frosts mid-move")
    func lensOptics() {
        let rest = LensOptics.at(strength: 0)
        #expect(rest == LensOptics(magnification: 1, refraction: 0, chroma: 0, frost: 0))
        let moving = LensOptics.at(strength: 1)
        #expect(moving.magnification > 1.05 && moving.magnification < 1.15)
        #expect(moving.refraction > 0 && moving.chroma > 0 && moving.frost > 0)
    }

    /// ImageRenderer runs layer shaders; an offscreen window's cached display skips them.
    @MainActor
    private func renderStripes(optics: LensOptics?) throws -> Data {
        let stripes = HStack(spacing: 2) {
            ForEach(0 ..< 25, id: \.self) { index in
                Rectangle().fill(index.isMultiple(of: 2) ? Color.red : Color.blue).frame(width: 6)
            }
        }
        .frame(width: 200, height: 40)
        .background(Color.white)
        let lens = CGRect(x: 40, y: 5, width: 100, height: 30)
        let view = stripes.layerEffect(
            (optics ?? .at(strength: 0)).shader(lens: lens),
            maxSampleOffset: CGSize(width: 48, height: 24),
            isEnabled: optics != nil
        )
        let image = try #require(ImageRenderer(content: view).cgImage)
        return try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    }

    @MainActor
    @Test("The lens shader loads from the module and bends the layer only when it has strength")
    func lensShaderBends() throws {
        let plain = try renderStripes(optics: nil)
        #expect(try renderStripes(optics: .at(strength: 0)) == plain)
        #expect(try renderStripes(optics: .at(strength: 1)) != plain)
    }

    @Test("Animation frames set the lens rect and strength the shader and rim draw from")
    func lensAnimatableData() {
        var effect = LiquidLensEffect(lens: CGRect(x: 0, y: 3, width: 80, height: 24), strength: 0, overhang: 12, isActive: true)
        #expect(effect.lens == CGRect(x: 0, y: 3, width: 80, height: 24))
        var frame = effect.animatableData
        frame.first.first = 100
        frame.first.second = 96
        frame.second.first = 35
        frame.second.second.first = 0.5
        frame.second.second.second = -1
        effect.animatableData = frame
        #expect(effect.lens == CGRect(x: 52, y: -2.5, width: 96, height: 35))
        #expect(effect.strength == 0.5)
        #expect(effect.tilt == -1)
        #expect(effect.animatableData == frame)
    }

    @Test("The swollen lens fits inside the effect's drawing area, however wide the segment")
    func lensFitsOverhang() {
        typealias Segments = ThawCapsuleSegments<Int>
        let track = CGSize(width: 640, height: 38)
        for width in [40.0, 120, 300] {
            let segment = CGRect(x: 4, y: 4, width: width, height: 30)
            let swollen = Segments.lensFrame(around: segment, trackSize: track, swollen: true)
            let overhang = Segments.lensOverhang(widestSegment: width)
            #expect((swollen.height - segment.height) / 2 <= overhang)
            #expect((swollen.width - segment.width) / 2 <= overhang)
        }
    }

    @Test("The highlight leans toward the direction of travel and settles at the top left")
    func highlightTilt() {
        typealias Segments = ThawCapsuleSegments<Int>
        #expect(Segments.travelTilt(from: 40, to: 120) == 1)
        #expect(Segments.travelTilt(from: 120, to: 40) == -1)
        #expect(Segments.travelTilt(from: 40, to: 40) == 0)
        #expect(Segments.travelTilt(from: nil, to: 40) == 0)
        #expect(Segments.travelTilt(velocity: 300) == 0.5)
        #expect(Segments.travelTilt(velocity: -2000) == -1)
        #expect(LensRim.highlightStart(tilt: 0) == UnitPoint(x: 0.25, y: 0))
        #expect(LensRim.highlightStart(tilt: 1) == UnitPoint(x: 0.5, y: 0))
        #expect(LensRim.highlightStart(tilt: -3) == UnitPoint(x: 0, y: 0))
    }

    @Test("Reduce Motion never swells the lens")
    func reduceMotionNoSwell() {
        typealias Segments = ThawCapsuleSegments<Int>
        #expect(Segments.swells(pressed: true, moving: false, reduceMotion: false))
        #expect(Segments.swells(pressed: false, moving: true, reduceMotion: false))
        #expect(!Segments.swells(pressed: true, moving: true, reduceMotion: true))
        #expect(!Segments.swells(pressed: false, moving: false, reduceMotion: false))
    }

    @MainActor
    @Test("Changing the selection moves the one selection indicator to the new segment")
    func indicatorFollowsSelection() throws {
        let picker = ThawPillPicker(selection: .constant(1), options: [.init(1, title: "One"), .init(2, title: "Two"), .init(3, title: "Three")])
        let first = try OffscreenRender(picker, size: CGSize(width: 260, height: 40)).pixels()
        let moved = ThawPillPicker(selection: .constant(3), options: [.init(1, title: "One"), .init(2, title: "Two"), .init(3, title: "Three")])
        let last = try OffscreenRender(moved, size: CGSize(width: 260, height: 40)).pixels()
        #expect(first != last)
    }
}
