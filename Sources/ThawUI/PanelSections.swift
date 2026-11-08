//
//  PanelSections.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 René Jiménez
//  Licensed under the GNU GPLv3

import SwiftUI

/// What a panel needs to draw itself in pieces. In the environment only while the setting is on.
public struct PanelPieces: Equatable {
    public var look: LauncherLook
    public var corners: SearchFieldCorners
    public var heights: PanelPieceHeights

    public init(look: LauncherLook, corners: SearchFieldCorners, heights: PanelPieceHeights) {
        self.look = look
        self.corners = corners
        self.heights = heights
    }

    public func fieldOutline() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: corners.fieldPieceRadius(height: heights.field), style: corners.pieceCornerStyle)
    }

    /// The results piece's edge. A list is clipped to it, so a scroll bar stays inside the corner.
    public func resultsOutline() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: corners.panelPieceRadius, style: .continuous)
    }

    /// The look for the field's piece. Collapsed there is nothing under it, so its shadow is whole.
    @MainActor public func fieldAppearance(facesResults: Bool) -> LauncherPanelAppearance {
        var appearance = LauncherPanelAppearance(look)
        appearance.cornerRadius = corners.fieldPieceRadius(height: heights.field)
        appearance.cornerStyle = corners.pieceCornerStyle
        appearance.shadow = .piece(facing: facesResults ? .bottom : nil)
        appearance.span = heights.fieldSpan
        return appearance
    }

    /// How far a list sits from the edges of the piece it is in (see the lists' content margins).
    public static let listInset = ThawSpacing.base

    /// The corner of a row's highlight in the results piece: the piece's radius less the list's inset, so the
    /// first row's corners share a centre with the piece's. Never less than a control's, which a square piece keeps.
    public var rowRadius: CGFloat {
        max(ThawRadius.control, corners.panelPieceRadius - Self.listInset)
    }

    @MainActor public func resultsAppearance() -> LauncherPanelAppearance {
        var appearance = LauncherPanelAppearance(look)
        appearance.cornerRadius = corners.panelPieceRadius
        appearance.shadow = .piece(facing: .top)
        appearance.span = heights.resultsSpan
        return appearance
    }

    /// A view with no search field stays one piece, with the corners the results have.
    @MainActor public func wholeAppearance() -> LauncherPanelAppearance {
        var appearance = LauncherPanelAppearance(look)
        appearance.cornerRadius = corners.panelPieceRadius
        return appearance
    }
}

public extension EnvironmentValues {
    /// Set by a launcher while its search field is separate; nil draws one panel.
    @Entry var panelPieces: PanelPieces?
}

/// A search field over its content, as every view with a field at the top is laid out:
/// one stack inside the panel, or two pieces of glass with a gap between them.
public struct PanelSections<Header: View, Content: View>: View {
    public var showsContent = true
    @ViewBuilder public var header: Header
    @ViewBuilder public var content: Content
    @Environment(\.panelPieces) private var pieces

    public init(showsContent: Bool = true, @ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.showsContent = showsContent
        self.header = header()
        self.content = content()
    }

    public var body: some View {
        if let pieces {
            VStack(spacing: pieces.heights.gap) {
                // Each piece's glass and content get containers of their own: in one shared container,
                // the field's glass frosts over once the results' glass appears beside it.
                GlassEffectContainer {
                    GlassEffectContainer { header }
                        .frame(maxWidth: .infinity)
                        .frame(height: pieces.heights.field)
                        .environment(\.fieldPieceOutline, pieces.fieldOutline())
                        .modifier(pieces.fieldAppearance(facesResults: showsContent))
                }
                if showsContent {
                    GlassEffectContainer {
                        GlassEffectContainer {
                            VStack(spacing: 0) { content }
                                // The scroll bar starts below the corner, and what still reaches it is cut off there.
                                .contentMargins(.top, pieces.corners.panelPieceRadius, for: .scrollIndicators)
                                .clipShape(pieces.resultsOutline())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: pieces.heights.results)
                        .environment(\.searchRowCornerRadius, pieces.rowRadius)
                        .modifier(pieces.resultsAppearance())
                    }
                }
            }
        } else {
            VStack(spacing: 0) {
                header
                if showsContent {
                    content
                }
            }
        }
    }
}

/// For a view with no search field: while the pieces are separate the look is drawn here, around the whole view.
public struct PanelOnePiece: ViewModifier {
    @Environment(\.panelPieces) private var pieces

    public init() {}

    public func body(content: Content) -> some View {
        if let pieces {
            GlassEffectContainer { content }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .modifier(pieces.wholeAppearance())
        } else {
            content
        }
    }
}

/// The look around the whole panel, or handed down for the views to draw piece by piece.
public struct PanelLook: ViewModifier {
    public let look: LauncherLook
    public let pieces: PanelPieces?

    public init(look: LauncherLook, pieces: PanelPieces?) {
        self.look = look
        self.pieces = pieces
    }

    public func body(content: Content) -> some View {
        if let pieces {
            content.environment(\.panelPieces, pieces)
        } else {
            content.modifier(LauncherPanelAppearance(look))
        }
    }
}

/// The heights of a panel drawn in two pieces: the search field's, the gap and the rest.
/// They add up to the panel's own height, so separating the pieces never resizes the window.
public struct PanelPieceHeights: Equatable, Sendable {
    public var field: CGFloat
    public var gap: CGFloat
    /// The piece under the gap, as tall as it is once the panel is open.
    public var results: CGFloat
    /// Collapsed, only the field's piece is drawn.
    public var isCollapsed = false

    public init(field: CGFloat, gap: CGFloat, results: CGFloat, isCollapsed: Bool = false) {
        self.field = field
        self.gap = gap
        self.results = results
        self.isCollapsed = isCollapsed
    }

    /// Floe's launcher: the search bar is 65 tall with less room under it than above, and 2 more even them out.
    public static let launcherField: CGFloat = 67
    /// Between the pieces: the step between siblings, so they read as one launcher.
    public static let launcherGap = ThawSpacing.base

    /// A launcher's pieces for a panel of the given height, with Floe's field and gap.
    public static func launcher(height: CGFloat, isCollapsed: Bool = false) -> PanelPieceHeights {
        PanelPieceHeights(
            field: launcherField,
            gap: launcherGap,
            results: height - launcherField - launcherGap,
            isCollapsed: isCollapsed
        )
    }

    private var open: CGFloat {
        field + gap + results
    }

    public var total: CGFloat {
        isCollapsed ? field : open
    }

    /// The share of the open panel's height each piece covers, for a fade that runs down both.
    public var fieldSpan: ClosedRange<CGFloat> {
        0 ... field / open
    }

    public var resultsSpan: ClosedRange<CGFloat> {
        (field + gap) / open ... 1
    }
}
