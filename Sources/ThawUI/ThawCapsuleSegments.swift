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

/// The segmented choice ThawPillPicker and ThawTabStrip draw. It is the system's segmented picker, so the
/// moving glass selection, keyboard, VoiceOver and the accessibility display settings come from macOS.
struct ThawCapsuleSegments<Value: Hashable>: View {
    /// How the picker takes up space.
    enum Sizing: Equatable {
        /// Each segment as wide as its label, which may be a symbol alone.
        case fitted(showsTitles: Bool)
        /// The segments share the width evenly and the picker fills its container.
        case filling

        var showsTitles: Bool {
            switch self {
            case let .fitted(showsTitles): showsTitles
            case .filling: true
            }
        }

        var maxWidth: CGFloat? {
            self == .filling ? .infinity : nil
        }

        /// A tab strip stands as tall as the pane's other headers; pills sit in a row at the form's size.
        var controlSize: ControlSize {
            self == .filling ? .large : .regular
        }
    }

    /// What a segment shows.
    enum SegmentLabel: Equatable {
        case title
        case titleAndSymbol(String)
        case symbol(String)
    }

    @Binding var selection: Value
    let segments: [ThawSegment<Value>]
    let sizing: Sizing

    /// A segment with no symbol keeps its title even when titles are off, so it never draws empty.
    static func label(for segment: ThawSegment<Value>, showsTitles: Bool) -> SegmentLabel {
        switch (segment.systemImage, showsTitles) {
        case let (symbol?, true): .titleAndSymbol(symbol)
        case let (symbol?, false): .symbol(symbol)
        case (nil, _): .title
        }
    }

    var body: some View {
        Picker(selection: $selection) {
            ForEach(segments, id: \.value) { segment in
                segmentLabel(segment)
                    .modifier(SegmentHelp(text: segment.help))
                    .tag(segment.value)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .tint(.accentColor)
        .controlSize(sizing.controlSize)
        .frame(maxWidth: sizing.maxWidth)
    }

    @ViewBuilder
    private func segmentLabel(_ segment: ThawSegment<Value>) -> some View {
        switch Self.label(for: segment, showsTitles: sizing.showsTitles) {
        case .title:
            Text(segment.title)
        case let .titleAndSymbol(symbol):
            Label { Text(segment.title) } icon: { Image(systemName: symbol) }
        case let .symbol(symbol):
            Image(systemName: symbol)
                .accessibilityLabel(Text(segment.title))
        }
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
