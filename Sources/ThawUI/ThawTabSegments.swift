//
//  ThawTabSegments.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 René Jiménez
//  Licensed under the GNU GPLv3

import SwiftUI

/// The system's tabs control, new in macOS 27, for ThawPillPicker and ThawTabStrip: the selection
/// is the system's own glass lens, which swells on press and follows a drag across the segments.
@available(macOS 27, *)
struct ThawTabSegments<Value: Hashable>: View {
    @Binding var selection: Value
    let segments: [ThawSegment<Value>]
    let sizing: ThawCapsuleSegments<Value>.Sizing

    var body: some View {
        Picker(selection: $selection) {
            ForEach(segments, id: \.value) { segment in
                SegmentLabel(segment: segment, showsTitle: sizing.showsTitles)
                    .tag(segment.value)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.tabs)
        .labelsHidden()
        .controlSize(sizing == .filling ? .large : .regular)
        .frame(maxWidth: sizing.maxWidth)
        .fixedSize(horizontal: sizing != .filling, vertical: true)
    }
}

/// A segment's symbol, title or both. A symbol alone keeps the title as its name and its help.
private struct SegmentLabel<Value: Hashable>: View {
    let segment: ThawSegment<Value>
    let showsTitle: Bool

    var body: some View {
        if let systemImage = segment.systemImage {
            if showsTitle {
                Label {
                    Text(segment.title)
                } icon: {
                    Image(systemName: systemImage)
                }
                .labelStyle(.titleAndIcon)
                .modifier(SegmentHelp(text: segment.help))
            } else {
                Image(systemName: systemImage)
                    .accessibilityLabel(Text(segment.title))
                    .modifier(SegmentHelp(text: segment.help))
            }
        } else {
            Text(segment.title)
                .modifier(SegmentHelp(text: segment.help))
        }
    }
}
