//
//  ThawTabStrip.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// A tab that names itself, for ThawTabStrip(selection:tabs:).
public nonisolated protocol ThawTab: Hashable {
    var title: LocalizedStringResource { get }
    var systemImage: String { get }
}

/// Icon-and-title tabs for Settings pages: the larger counterpart to ThawPillPicker. On macOS 27 it is
/// the system's tabs control, centred and as wide as its tabs; on macOS 26 the tabs share the strip's width.
public struct ThawTabStrip<Tab: Hashable>: View {
    public typealias Item = ThawSegment<Tab>

    @Binding private var selection: Tab
    private let items: [Item]

    public init(selection: Binding<Tab>, items: [Item]) {
        _selection = selection
        self.items = items
    }

    /// Tabs that carry their own name and symbol, in the order given.
    public init(selection: Binding<Tab>, tabs: [Tab]) where Tab: ThawTab {
        self.init(selection: selection, items: tabs.map { Item($0, title: $0.title, systemImage: $0.systemImage) })
    }

    public var body: some View {
        ThawCapsuleSegments(selection: $selection, segments: items, sizing: .filling)
    }
}

#if DEBUG
    private struct ThawTabStripPreview: View {
        @State private var selection = 0

        var body: some View {
            ThawTabStrip(
                selection: $selection,
                items: [
                    .init(0, title: "General", systemImage: "gearshape"),
                    .init(1, title: "Appearance", systemImage: "paintbrush"),
                    .init(2, title: "Advanced", systemImage: "slider.horizontal.3"),
                ]
            )
            .padding()
            .frame(width: 480)
        }
    }

    #Preview("Tab strip") {
        ThawTabStripPreview()
    }
#endif
