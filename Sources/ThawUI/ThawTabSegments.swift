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
        // Chosen here: a branch inside a segment's label leaks the picker's selection binding each time it closes.
        if sizing.showsTitles {
            picker.labelStyle(.titleAndIcon)
        } else {
            picker.labelStyle(.iconOnly)
        }
    }

    /// Each segment is one Label, so a symbol alone keeps the title as its name.
    private var picker: some View {
        Picker(selection: $selection) {
            ForEach(segments, id: \.value) { segment in
                Label {
                    Text(segment.title)
                } icon: {
                    if let systemImage = segment.systemImage {
                        Image(systemName: systemImage)
                    }
                }
                .modifier(SegmentHelp(text: segment.help))
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
