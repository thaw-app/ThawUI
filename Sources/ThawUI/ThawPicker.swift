//
//  ThawPicker.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

public struct ThawPicker<Label: View, SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue

    let label: Label
    let content: Content

    public init(
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self._selection = selection
        self.label = label()
        self.content = content()
    }

    public init(
        _ titleKey: LocalizedStringResource,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) where Label == Text {
        self.init(selection: selection) {
            content()
        } label: {
            Text(titleKey)
        }
    }

    public var body: some View {
        LabeledContent {
            Picker(selection: $selection) {
                content
                    .labelStyle(.titleAndIcon)
                    .toggleStyle(.automatic)
            } label: {
                label
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        } label: {
            label
        }
    }
}

#if DEBUG
    private struct ThawPickerPreview: View {
        @State private var position = "top"
        @State private var style = "plain"

        var body: some View {
            Form {
                ThawPicker("Position", selection: $position) {
                    Text("Top").tag("top")
                    Text("Bottom").tag("bottom")
                    Text("Center").tag("center")
                }
                ThawPicker("With icons", selection: $style) {
                    Label("Plain", systemImage: "circle").tag("plain")
                    Label("Glass", systemImage: "square.on.square").tag("glass")
                }
                ThawPicker("Disabled", selection: $position) {
                    Text("Top").tag("top")
                    Text("Bottom").tag("bottom")
                }
                .disabled(true)
            }
            .formStyle(.grouped)
            .frame(width: 420, height: 220)
        }
    }

    #Preview("Picker") {
        ThawPickerPreview()
    }
#endif
