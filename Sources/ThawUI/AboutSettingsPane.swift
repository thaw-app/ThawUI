//
//  AboutSettingsPane.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//
//  Floe changes © 2026 René Jiménez, under the same license.

import AppKit
import Observation
import SwiftUI

// MARK: - AboutStrings

/// The text of the About page, apart from its updates card.
public nonisolated struct AboutStrings: Sendable {
    public var tagline: LocalizedStringResource
    /// What VoiceOver reads for the version line.
    public var versionLabel: @Sendable (_ version: String, _ build: String, _ commit: String) -> LocalizedStringResource
    public var copied: LocalizedStringResource
    public var copyHelp: LocalizedStringResource
    public var copyLabel: LocalizedStringResource
    public var whatsNew: LocalizedStringResource
    public var reportBug: LocalizedStringResource
    public var more: LocalizedStringResource
    public var sourceCode: LocalizedStringResource
    public var credits: LocalizedStringResource
    public var support: LocalizedStringResource

    public init(
        tagline: LocalizedStringResource,
        versionLabel: @escaping @Sendable (_ version: String, _ build: String, _ commit: String) -> LocalizedStringResource,
        copied: LocalizedStringResource,
        copyHelp: LocalizedStringResource,
        copyLabel: LocalizedStringResource,
        whatsNew: LocalizedStringResource,
        reportBug: LocalizedStringResource,
        more: LocalizedStringResource,
        sourceCode: LocalizedStringResource,
        credits: LocalizedStringResource,
        support: LocalizedStringResource
    ) {
        self.tagline = tagline
        self.versionLabel = versionLabel
        self.copied = copied
        self.copyHelp = copyHelp
        self.copyLabel = copyLabel
        self.whatsNew = whatsNew
        self.reportBug = reportBug
        self.more = more
        self.sourceCode = sourceCode
        self.credits = credits
        self.support = support
    }
}

/// The text of the About page's updates card.
public nonisolated struct AboutUpdateStrings: Sendable {
    public var updateChannel: LocalizedStringResource
    public var automaticUpdates: LocalizedStringResource
    public var checkNow: LocalizedStringResource
    public var notChecked: LocalizedStringResource
    public var lastChecked: @Sendable (_ formattedDate: String) -> LocalizedStringResource
    public var channelName: @Sendable (UpdateChannel) -> LocalizedStringResource
    /// A choice's full name, which is its pill's help.
    public var automaticUpdatesName: @Sendable (AutomaticUpdates) -> LocalizedStringResource
    /// The name in a pill, where the full one doesn't fit.
    public var automaticUpdatesShortName: @Sendable (AutomaticUpdates) -> LocalizedStringResource

    public init(
        updateChannel: LocalizedStringResource,
        automaticUpdates: LocalizedStringResource,
        checkNow: LocalizedStringResource,
        notChecked: LocalizedStringResource,
        lastChecked: @escaping @Sendable (_ formattedDate: String) -> LocalizedStringResource,
        channelName: @escaping @Sendable (UpdateChannel) -> LocalizedStringResource,
        automaticUpdatesName: @escaping @Sendable (AutomaticUpdates) -> LocalizedStringResource,
        automaticUpdatesShortName: @escaping @Sendable (AutomaticUpdates) -> LocalizedStringResource
    ) {
        self.updateChannel = updateChannel
        self.automaticUpdates = automaticUpdates
        self.checkNow = checkNow
        self.notChecked = notChecked
        self.lastChecked = lastChecked
        self.channelName = channelName
        self.automaticUpdatesName = automaticUpdatesName
        self.automaticUpdatesShortName = automaticUpdatesShortName
    }

    /// When updates were last checked, or plainly that they have not been.
    func footnote(lastCheck date: Date?) -> LocalizedStringResource {
        guard let date else {
            return notChecked
        }
        return lastChecked(date.formatted(date: .abbreviated, time: .shortened))
    }
}

// MARK: - AboutContent

/// Which build this is.
public nonisolated struct AboutVersionDetails: Sendable {
    public var version: String
    public var build: String
    public var commit: String
    /// What the copy button copies: the full block a bug report asks for.
    public var report: String

    public init(
        version: String,
        build: String,
        commit: String,
        report: String
    ) {
        self.version = version
        self.build = build
        self.commit = commit
        self.report = report
    }

    var line: String {
        "\(version) (\(build)) · \(commit)"
    }
}

/// The page's web links. A link without a URL does not show.
public nonisolated struct AboutLinks: Sendable {
    public var sourceCode: URL?
    public var reportBug: URL?
    public var support: URL?

    public init(
        sourceCode: URL?,
        reportBug: URL?,
        support: URL?
    ) {
        self.sourceCode = sourceCode
        self.reportBug = reportBug
        self.support = support
    }
}

/// One entry in the menu behind the page's actions button.
public struct AboutMenuItem {
    public enum Action {
        /// Opens through the environment's openURL, as the page's other links do.
        case open(URL)
        case perform(@MainActor () -> Void)
    }

    public var title: LocalizedStringResource
    public var systemImage: String
    public var action: Action

    public init(
        _ title: LocalizedStringResource,
        systemImage: String,
        url: URL
    ) {
        self.title = title
        self.systemImage = systemImage
        action = .open(url)
    }

    public init(
        _ title: LocalizedStringResource,
        systemImage: String,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = .perform(action)
    }
}

// MARK: - AboutUpdateControls

/// What the updates card reads and changes, so the page needs no updater of its own.
/// Observable, so the card follows the updater while it is on screen.
@MainActor
public protocol AboutUpdatesModel: AutomaticUpdateSwitches, Observable {
    var updateChannel: UpdateChannel { get set }
    /// Whether a manual check can begin now.
    var canCheckNow: Bool { get }
    var lastUpdateCheckDate: Date? { get }
    func checkForUpdates()
}

/// The updates card: an updater, the channels on offer, and the card's text.
public struct AboutUpdateControls {
    let model: any AboutUpdatesModel
    let channels: [UpdateChannel]
    let strings: AboutUpdateStrings

    public init(
        model: any AboutUpdatesModel,
        channels: [UpdateChannel],
        strings: AboutUpdateStrings
    ) {
        self.model = model
        self.channels = channels
        self.strings = strings
    }

    @MainActor
    var channel: Binding<UpdateChannel> {
        let model = model
        return Binding {
            model.updateChannel
        } set: {
            model.updateChannel = $0
        }
    }

    @MainActor
    var automaticUpdates: Binding<AutomaticUpdates> {
        let model = model
        return Binding {
            model.automaticUpdates
        } set: {
            model.automaticUpdates = $0
        }
    }
}

// MARK: - AboutSettingsPane

/// The About page: who the app is and which build this is, then one card for
/// updates, then news and help actions. Project links and copyright form a
/// quiet footer; the app's secondary destinations sit in the actions' menu.
public struct AboutSettingsPane: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let appName: String
    private let version: AboutVersionDetails
    private let links: AboutLinks
    private let moreMenu: [[AboutMenuItem]]
    private let updates: AboutUpdateControls?
    private let copyright: Text
    private let strings: AboutStrings
    private let showWhatsNew: @MainActor () -> Void
    private let showCredits: @MainActor () -> Void

    private static let iconSize: CGFloat = 96

    /// Half the icon, so the name beside it does not outweigh it.
    private static let nameSize: CGFloat = 48

    @State private var applicationIcon = AboutSettingsPane.currentApplicationIcon()
    @State private var didCopy = false
    @State private var copyFeedbackTask: Task<Void, Never>?
    @State private var menuAnchor = MoreMenuAnchor()

    /// - Parameters:
    ///   - moreMenu: The actions' menu, as groups with a separator between them. With no
    ///     items, the button does not show.
    ///   - updates: The updates card. Nil for a build that cannot update, which has no card.
    public init(
        appName: String,
        version: AboutVersionDetails,
        links: AboutLinks,
        moreMenu: [[AboutMenuItem]] = [],
        updates: AboutUpdateControls? = nil,
        copyright: Text,
        strings: AboutStrings,
        showWhatsNew: @escaping @MainActor () -> Void,
        showCredits: @escaping @MainActor () -> Void
    ) {
        self.appName = appName
        self.version = version
        self.links = links
        self.moreMenu = moreMenu
        self.updates = updates
        self.copyright = copyright
        self.strings = strings
        self.showWhatsNew = showWhatsNew
        self.showCredits = showCredits
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: ThawSpacing.section) {
                identity
                if let updates {
                    updatesCard(updates)
                }
                actions
                footer
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, ThawSpacing.section)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center, for: .alignment)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        // The sidebar's material, so About reads as one surface with it, or black on a
        // black window. Other panes keep the window background for their forms.
        .background {
            SettingsPaneBackdrop(material: .sidebar)
                .ignoresSafeArea()
        }
        .onChange(of: colorScheme, initial: true) {
            applicationIcon = Self.currentApplicationIcon()
        }
        .onDisappear {
            copyFeedbackTask?.cancel()
        }
    }

    // MARK: Identity

    private var identity: some View {
        VStack(spacing: ThawSpacing.gutter) {
            VStack(spacing: ThawSpacing.base) {
                HStack(spacing: ThawSpacing.inset) {
                    Text(verbatim: appName)
                        .font(.system(size: Self.nameSize, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Image(nsImage: applicationIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Self.iconSize, height: Self.iconSize)
                        .accessibilityHidden(true)
                }
                Text(strings.tagline)
                    .font(ThawType.detail)
                    .foregroundStyle(ThawInk.supporting)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            details
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Details

    /// One line, monospaced so it can be selected and pasted. The copy button beside
    /// it copies the full block a bug report asks for.
    private var details: some View {
        HStack(alignment: .firstTextBaseline, spacing: ThawSpacing.row) {
            // Label a container, not the selectable text: labeling the AppKit text view
            // directly recurses until the stack overflows under VoiceOver.
            Text(verbatim: version.line)
                .font(ThawType.detail)
                .monospaced()
                .foregroundStyle(ThawInk.supporting)
                .textSelection(.enabled)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(strings.versionLabel(version.version, version.build, version.commit)))
            Button {
                copyVersionInfo()
            } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            }
            .buttonStyle(.settingsGlass)
            .controlSize(.small)
            .help(Text(didCopy ? strings.copied : strings.copyHelp))
            .accessibilityLabel(Text(didCopy ? strings.copied : strings.copyLabel))
        }
    }

    // MARK: Actions

    private var actions: some View {
        ThawActionGroup {
            Button(strings.whatsNew) {
                showWhatsNew()
            }
            if let url = links.reportBug {
                Button(strings.reportBug) {
                    openURL(url)
                }
            }
            if moreMenu.contains(where: { !$0.isEmpty }) {
                // A plain button that pops the menu, so it takes the same style,
                // size and corner as its neighbours; a SwiftUI Menu does not.
                Button {
                    showMoreMenu()
                } label: {
                    // Inside a Text the symbol takes a line of text's height, so
                    // the button matches its neighbours instead of sitting short.
                    Text(Image(systemName: "ellipsis"))
                }
                .help(Text(strings.more))
                .accessibilityLabel(Text(strings.more))
                // The anchor only places the menu, so it stays out of the accessibility
                // tree, where it could stand in for the labeled button.
                .background { MoreMenuAnchorView(anchor: menuAnchor).accessibilityHidden(true) }
            }
        }
        .buttonStyle(.thawGrouped)
    }

    private var footer: some View {
        VStack(spacing: ThawSpacing.inset) {
            HStack(spacing: ThawSpacing.inset) {
                if let url = links.sourceCode {
                    Link(destination: url) {
                        Text(strings.sourceCode).underline()
                    }
                    footerSeparator
                }
                Button {
                    showCredits()
                } label: {
                    Text(strings.credits).underline()
                }
                if let url = links.support {
                    footerSeparator
                    Link(destination: url) {
                        Text(strings.support).underline()
                    }
                }
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: false, vertical: true)

            copyright
        }
        .font(ThawType.footnote)
        .foregroundStyle(ThawInk.supporting)
        .multilineTextAlignment(.center)
    }

    private var footerSeparator: some View {
        Text(verbatim: "·")
            .accessibilityHidden(true)
    }

    /// Pops the secondary destinations under the actions button, for both
    /// clicks and keyboard activation.
    private func showMoreMenu() {
        let openURL = openURL
        let menu = AboutMoreMenu.make(groups: moreMenu) { openURL($0) }
        guard let anchor = menuAnchor.view else { return }
        // The anchor's own coordinate system is not flipped, so minY is its
        // bottom edge and the menu opens just below the button.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.minY), in: anchor)
    }

    // MARK: Updates

    /// The choices are pills, short enough to sit beside their labels.
    private func updatesCard(_ updates: AboutUpdateControls) -> some View {
        let strings = updates.strings
        return VStack(spacing: 0) {
            updateRow(strings.updateChannel) {
                ThawPillPicker(strings.updateChannel, selection: updates.channel, values: updates.channels, title: strings.channelName)
            }
            Divider()
            updateRow(strings.automaticUpdates) {
                ThawPillPicker(
                    strings.automaticUpdates,
                    selection: updates.automaticUpdates,
                    options: AutomaticUpdates.allCases.map {
                        ThawPillPicker.Option($0, title: strings.automaticUpdatesShortName($0), help: strings.automaticUpdatesName($0))
                    }
                )
            }
            Divider()
            updateRow(strings.footnote(lastCheck: updates.model.lastUpdateCheckDate), isSecondary: true) {
                Button(strings.checkNow) {
                    updates.model.checkForUpdates()
                }
                .buttonStyle(.settingsGlass)
                .disabled(!updates.model.canCheckNow)
            }
        }
        .font(ThawType.detail)
        .background(.quinary, in: RoundedRectangle(cornerRadius: ThawRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ThawRadius.card, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        }
    }

    private func updateRow(
        _ label: LocalizedStringResource,
        isSecondary: Bool = false,
        @ViewBuilder control: () -> some View
    ) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(isSecondary ? AnyShapeStyle(ThawInk.supporting) : AnyShapeStyle(.primary))
            Spacer(minLength: ThawSpacing.inset)
            control()
                .labelsHidden()
                .fixedSize()
        }
        .padding(.horizontal, ThawSpacing.inset)
        .padding(.vertical, ThawSpacing.base)
    }

    // MARK: Helpers

    public static func currentApplicationIcon() -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        return (icon.copy() as? NSImage) ?? icon
    }

    private func copyVersionInfo() {
        Self.copy(version.report, to: .general)

        copyFeedbackTask?.cancel()
        didCopy = true
        copyFeedbackTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return
            }
            didCopy = false
            copyFeedbackTask = nil
        }
    }

    static func copy(_ text: String, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - AboutMoreMenu

/// Builds the AppKit menu behind the actions button.
@MainActor
enum AboutMoreMenu {
    /// Empty groups leave no separator behind.
    static func make(groups: [[AboutMenuItem]], openURL: @escaping @MainActor (URL) -> Void) -> NSMenu {
        let menu = NSMenu()
        for (index, group) in groups.filter({ !$0.isEmpty }).enumerated() {
            if index > 0 {
                menu.addItem(.separator())
            }
            for item in group {
                let entry = ClosureMenuItem(title: String(localized: item.title)) {
                    switch item.action {
                    case let .open(url): openURL(url)
                    case let .perform(action): action()
                    }
                }
                entry.image = NSImage(systemSymbolName: item.systemImage, accessibilityDescription: nil)
                menu.addItem(entry)
            }
        }
        return menu
    }
}

/// A menu item that runs a closure.
@MainActor
private final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    /// AppKit's initializers are nonisolated, and so must be what stands in for them here.
    @available(*, unavailable)
    override nonisolated init(title _: String, action _: Selector?, keyEquivalent _: String) {
        fatalError("init(title:action:keyEquivalent:) has not been implemented")
    }

    @available(*, unavailable)
    required nonisolated init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}

/// Holds the AppKit view behind the actions button so the menu can be
/// positioned against the button itself. A reference box keeps the
/// representable from writing SwiftUI state during a view update.
@MainActor
private final class MoreMenuAnchor {
    weak var view: NSView?
}

/// An empty view behind the actions button for NSMenu.popUp to position
/// against, including on keyboard activation.
private struct MoreMenuAnchorView: NSViewRepresentable {
    let anchor: MoreMenuAnchor

    func makeNSView(context _: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        anchor.view = nsView
    }
}
