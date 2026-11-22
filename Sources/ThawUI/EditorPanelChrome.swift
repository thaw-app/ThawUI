//
//  EditorPanelChrome.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// The title and bottom bar the quick-edit popovers (Layout, Appearance) put around their pane.
/// No glass: it would stack on the popover's material. In the safe area, the scroll edge effect keeps content legible.
public struct EditorPanelChrome<Content: View, BottomBar: View>: View {
    private let title: LocalizedStringResource
    private let subtitle: LocalizedStringResource?
    private let content: Content
    private let bottomBar: BottomBar

    public init(
        _ title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottomBar: () -> BottomBar
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.bottomBar = bottomBar()
    }

    public var body: some View {
        content
            .scrollEdgeEffectStyle(.automatic, for: .vertical)
            .safeAreaBar(edge: .top, spacing: 0) { heading }
            .safeAreaBar(edge: .bottom, spacing: 0) {
                HStack(spacing: ThawSpacing.base) {
                    bottomBar
                }
                .padding(.horizontal, ThawSpacing.gutter)
                .padding(.top, ThawSpacing.base)
                .padding(.bottom, ThawSpacing.gutter)
            }
            // Capsule buttons throughout, as in Settings.
            .buttonBorderShape(.capsule)
    }

    private var heading: some View {
        VStack(spacing: ThawSpacing.hairline) {
            Text(title)
                .font(ThawType.display)
            // A popover has no Settings sidebar to say what it is for.
            if let subtitle {
                Text(subtitle)
                    .font(ThawType.caption)
                    .foregroundStyle(ThawInk.supporting)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, ThawSpacing.gutter)
        .padding(.top, ThawSpacing.gutter)
        .padding(.bottom, ThawSpacing.base)
    }
}

#if DEBUG
    #Preview("Editor panel chrome") {
        EditorPanelChrome("Layout", subtitle: "Drag items to rearrange them.") {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(1 ... 12, id: \.self) { index in
                        Text("Row \(index)")
                            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
            }
        } bottomBar: {
            Button("Reset") { /* Preview only. */ }
            Spacer()
            Button("Done") { /* Preview only. */ }
                .buttonStyle(.borderedProminent)
        }
        .frame(width: 360, height: 360)
    }

    #Preview("Editor panel chrome, no subtitle") {
        EditorPanelChrome("Appearance") {
            Text("Content")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } bottomBar: {
            Button("Close") { /* Preview only. */ }
        }
        .frame(width: 360, height: 200)
    }
#endif
