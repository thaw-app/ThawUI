//
//  ThawMotionTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI
import Testing
@testable import ThawUI

/// Which animation a change gets with and without Reduce Motion.
@Suite("Motion")
struct ThawMotionTests {
    @Test("Without Reduce Motion a change keeps its own animation")
    func fullMotion() {
        #expect(ThawMotion.resolved(ThawMotion.settle, reduceMotion: false, reduced: .cut) == ThawMotion.settle)
        #expect(ThawMotion.resolved(ThawMotion.settle, reduceMotion: false, reduced: .fade) == ThawMotion.settle)
    }

    @Test("Reduce Motion cuts movement, and keeps a quick fade for a change that only fades")
    func reducedMotion() {
        #expect(ThawMotion.resolved(ThawMotion.settle, reduceMotion: true, reduced: .cut) == nil)
        #expect(ThawMotion.resolved(ThawMotion.settle, reduceMotion: true, reduced: .fade) == ThawMotion.reducedFade)
        #expect(ThawMotion.reducedFade == .easeOut(duration: 0.12))
    }

    @MainActor
    @Test("withThawAnimation runs its body whatever the setting")
    func withAnimationRunsBody() {
        var ran = 0
        withThawAnimation(ThawMotion.reveal, reduced: .fade) { ran += 1 }
        withThawAnimation(ThawMotion.quick) { ran += 1 }
        #expect(ran == 2)
        #expect(ThawMotion.reveal == .easeOut(duration: 0.6))
    }
}
