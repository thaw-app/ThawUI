//
//  ThawPillPicker.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// Choices in one glass capsule: the system's tabs control on macOS 27, a capsule drawn by hand on
/// macOS 26. Without titles, the titles become help and VoiceOver labels.
public struct ThawPillPicker<Value: Hashable>: View {
    public typealias Option = ThawSegment<Value>

    @Binding private var selection: Value
    let options: [Option]
    let label: LocalizedStringResource?
    private let showsTitles: Bool

    /// A label, when given, sits beside the pills in a LabeledContent and is the
    /// pills' VoiceOver label.
    public init(
        _ label: LocalizedStringResource? = nil,
        selection: Binding<Value>,
        options: [Option],
        showsTitles: Bool = true
    ) {
        _selection = selection
        self.options = options
        self.label = label
        self.showsTitles = showsTitles
    }

    /// A labelled row with one pill per value, in order, each named by title.
    public init(
        _ label: LocalizedStringResource,
        selection: Binding<Value>,
        values: some Sequence<Value>,
        title: (Value) -> LocalizedStringResource
    ) {
        self.init(label, selection: selection, options: values.map { Option($0, title: title($0)) })
    }

    public var body: some View {
        if let label {
            LabeledContent(label) {
                segments
                    .accessibilityLabel(Text(label))
            }
        } else {
            segments
        }
    }

    private var segments: some View {
        ThawCapsuleSegments(
            selection: $selection,
            segments: options.map { option in
                Option(option.value, title: option.title, systemImage: option.systemImage, help: option.help ?? option.title)
            },
            sizing: .fitted(showsTitles: showsTitles)
        )
    }
}

#if DEBUG
    private struct ThawPillPickerPreview: View {
        enum Mode: CaseIterable {
            case hidden, shown, always
        }

        @State private var mode = Mode.shown
        @State private var icon = Mode.hidden

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                ThawPillPicker("Visibility", selection: $mode, values: Mode.allCases) { mode in
                    switch mode {
                    case .hidden: "Hidden"
                    case .shown: "Shown"
                    case .always: "Always shown, even with a long name"
                    }
                }
                ThawPillPicker(
                    selection: $icon,
                    options: [
                        .init(Mode.hidden, title: "Hidden", systemImage: "eye.slash"),
                        .init(Mode.shown, title: "Shown", systemImage: "eye"),
                        .init(Mode.always, title: "Always", systemImage: "pin"),
                    ],
                    showsTitles: false
                )
                ThawPillPicker("Disabled", selection: .constant(Mode.shown), values: Mode.allCases) { _ in "Option" }
                    .disabled(true)
            }
            .padding()
            .frame(width: 520)
        }
    }

    #Preview("Pill picker") {
        ThawPillPickerPreview()
    }
#endif
