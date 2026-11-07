//
//  ThawTogglePillsTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI
import Testing
@testable import ThawUI

@MainActor
@Suite("Toggle pills")
struct ThawTogglePillsTests {
    /// The size the view lays out at, after drawing it once offscreen.
    private static func renderedSize(of view: some View) -> CGSize {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
        }
        return host.fittingSize
    }

    @Test("Keeps the pill measurements a titled pill picker had")
    func sizing() {
        typealias Metrics = ThawTogglePillStyle.Metrics
        #expect(Metrics.spacing == ThawSpacing.hairline)
        #expect(Metrics.inset == ThawSpacing.capsuleInset)
        #expect(Metrics.horizontalPadding == ThawSpacing.row)
        #expect(Metrics.minWidth == 28 && Metrics.minHeight == 24)
    }

    @Test("Each switch adds width, on or off, and the capsule is at least a pill tall")
    func layout() {
        let one = Self.renderedSize(of: ThawTogglePills {
            Toggle("First", isOn: .constant(true))
        })
        let two = Self.renderedSize(of: ThawTogglePills {
            Toggle("First", isOn: .constant(true))
            Toggle("Second", isOn: .constant(false))
        })
        #expect(two.width > one.width)
        #expect(one.height >= ThawTogglePillStyle.Metrics.minHeight)
    }
}
