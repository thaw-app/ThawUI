//
//  LauncherResultList.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 René Jiménez
//  Licensed under the GNU GPLv3

import SwiftUI

/// A launcher's results: rows in a lazy stack, a heading wherever the section changes, and the
/// highlighted row kept in view. The highlight is a position in rows, so a list can never hold
/// one it does not show, and moving it redraws the rows that change and not the list.
///
/// The keys stay with the panel: it moves the selection and the list follows. A second handler
/// here would answer a held arrow's repeats as well, against a highlight a step behind.
public struct LauncherResultList<Row: Identifiable, RowContent: View>: View {
    public let rows: [Row]
    /// The highlighted row's position in rows.
    public let selection: Int
    public let section: (Row) -> String?
    public let select: (Int) -> Void
    public let activate: (Int) -> Void
    @ViewBuilder public let rowContent: (Row, _ selected: Bool) -> RowContent

    public init(
        rows: [Row],
        selection: Int,
        section: @escaping (Row) -> String? = { _ in nil },
        select: @escaping (Int) -> Void,
        activate: @escaping (Int) -> Void,
        @ViewBuilder rowContent: @escaping (Row, _ selected: Bool) -> RowContent
    ) {
        self.rows = rows
        self.selection = selection
        self.section = section
        self.select = select
        self.activate = activate
        self.rowContent = rowContent
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        // One view per row, heading included: a lazy stack walks the whole list when rows vary in count.
                        VStack(alignment: .leading, spacing: 0) {
                            if let title = section(row), index == 0 || section(rows[index - 1]) != title {
                                ListSectionHeading(title: title, isFirst: index == 0)
                            }
                            rowContent(row, index == selection)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { activate(index) }
                                .onTapGesture { select(index) }
                        }
                        .id(row.id)
                    }
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .contentMargins(.all, PanelPieces.listInset, for: .scrollContent)
            .onChange(of: selection) {
                if rows.indices.contains(selection) {
                    proxy.scrollTo(rows[selection].id)
                }
            }
        }
    }
}

/// Moves a launcher's highlight: ↑↓ by one, Page Up and Page Down by a screenful, Home and End to the ends.
public nonisolated enum LauncherListStep {
    /// Rows a Page Up or Page Down moves.
    public static let page = 9

    /// The step for a key, or nil for any other key.
    public static func delta(for key: KeyCode) -> Int? {
        switch key {
        case .downArrow: 1
        case .upArrow: -1
        case .pageDown: page
        case .pageUp: -page
        case .end: Int.max / 2
        case .home: -(Int.max / 2)
        default: nil
        }
    }

    /// selection moved by delta, held to the rows there are.
    public static func moved(_ selection: Int, by delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return max(0, min(selection + delta, count - 1))
    }
}
