//
//  SettingsFilterField.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 René Jiménez
//  Licensed under the GNU GPLv3

import SwiftUI

/// A page's own search: a filled field as wide as the page, so it reads apart from the settings search at
/// the top of the sidebar. Escape and the clear button empty it.
public struct SettingsFilterField: View {
    public let prompt: LocalizedStringResource
    @Binding public var text: String
    @FocusState private var isFocused: Bool

    public init(
        prompt: LocalizedStringResource,
        text: Binding<String>
    ) {
        self.prompt = prompt
        _text = text
    }

    public var body: some View {
        HStack(spacing: ThawSpacing.tight) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .labelsHidden()
                .focused($isFocused)
                .onExitCommand { text = "" }
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear"))
            }
        }
        .padding(.horizontal, ThawSpacing.inset)
        .frame(height: 36)
        .background(.quaternary.opacity(0.6), in: Self.shape)
        // A click anywhere on the field, the glass included, puts the cursor in it.
        .contentShape(Self.shape)
        .onTapGesture { isFocused = true }
    }

    private static let shape = RoundedRectangle(cornerRadius: ThawRadius.control, style: .continuous)
}

/// What a page's filter shows when nothing matches, in the empty state the rest of Settings uses.
public struct NoMatchesState: View {
    public let query: String

    public init(
        query: String
    ) {
        self.query = query
    }

    public var body: some View {
        ThawEmptyState(
            systemImage: "magnifyingglass",
            title: "No results for “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”",
            caption: "Check the spelling or try a shorter term."
        )
    }
}
