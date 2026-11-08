//
//  PanelBottomBar.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 René Jiménez
//  Licensed under the GNU GPLv3

import SwiftUI

/// The bar under a launcher's list: what is on the left, then the selected row's actions with their keys.
public struct PanelBottomBar<Content: View>: View {
    @ViewBuilder public var content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: ThawSpacing.row) {
            content
        }
        .buttonStyle(SearchPanelButtonStyle())
        .padding(.horizontal, ThawSpacing.inset)
        .padding(.vertical, ThawSpacing.row)
    }
}
