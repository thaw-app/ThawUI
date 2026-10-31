//
//  ChangelogDocumentDegradationTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation
import Testing
@testable import ThawUI

/// The parser on input it does not fully recognize, and what it makes of a
/// release's optional parts: an empty release, stray headers, dates, badges.
@MainActor
@Suite("ChangelogDocument degradation")
struct ChangelogDocumentDegradationTests {
    /// The plain-text characters of an AttributedString bullet, for
    /// asserting content independent of inline styling runs.
    private func plain(_ text: AttributedString) -> String {
        String(text.characters)
    }

    /// The plain text of a block, so a prose block and a callout assert the
    /// same way.
    private func plain(_ block: ChangelogDocument.Block) -> String {
        switch block {
        case let .text(text):
            plain(text)
        case let .callout(callout):
            plain(callout)
        }
    }

    /// A callout's parts joined with newlines.
    private func plain(_ callout: ChangelogDocument.Callout) -> String {
        callout.parts.map { part in
            switch part {
            case let .paragraph(text), let .bullet(text): plain(text)
            }
        }
        .joined(separator: "\n")
    }

    // MARK: - Document shape

    @Test("newestRelease skips an empty [Unreleased] release")
    func newestReleaseSkipsEmptyUnreleased() {
        let document = ChangelogDocument.parse("""
        ## [Unreleased]

        ## [1.2.0]

        ### Fixed

        - The fix.
        """)

        #expect(document.newestRelease?.version == "1.2.0")
    }

    @Test("newestRelease returns [Unreleased] when it has content")
    func newestReleaseKeepsPopulatedUnreleased() {
        let document = ChangelogDocument.parse("""
        ## [Unreleased]

        ### Added

        - Something upcoming.

        ## [1.2.0]

        ### Fixed

        - The fix.
        """)

        #expect(document.newestRelease?.version == "Unreleased")
    }

    @Test("newestRelease is nil for a document with no content at all")
    func newestReleaseNilForEmptyDocument() {
        #expect(ChangelogDocument.parse("").newestRelease == nil)
        #expect(ChangelogDocument.parse("# Changelog\n\nProse only.").newestRelease == nil)
    }

    // MARK: - Inline markdown

    @Test("inline markdown is interpreted; plain characters survive")
    func inlineMarkdownSurvives() {
        let document = ChangelogDocument.parse("""
        ## [1.0.0]

        ### Added

        - Supports **bold**, _italic_, `code`, and [links](https://example.com).
        """)

        let bullet = document.releases[0].sections[0].themes[0].bullets[0]
        // The markup characters are consumed by inline parsing; the visible
        // text keeps the words themselves.
        #expect(plain(bullet) == "Supports bold, italic, code, and links.")
    }

    // MARK: - Malformed input degrades sanely

    @Test("bullets before any release header are dropped without crashing")
    func bulletsBeforeAnyReleaseAreDropped() {
        let document = ChangelogDocument.parse("""
        - An orphan bullet.

        ## [1.0.0]

        ### Added

        - A real bullet.
        """)

        #expect(document.releases.count == 1)
        #expect(document.releases[0].intro.isEmpty)
        #expect(document.releases[0].sections[0].themes[0].bullets.map(plain) == ["A real bullet."])
    }

    @Test("a '###' section header before any release is ignored")
    func sectionBeforeAnyReleaseIsIgnored() {
        let document = ChangelogDocument.parse("""
        ### Added

        - Lost bullet.

        ## [1.0.0]

        ### Fixed

        - Kept bullet.
        """)

        #expect(document.releases.count == 1)
        #expect(document.releases[0].sections.map(\.title) == ["Fixed"])
    }

    @Test("a '####' theme with no open section is dropped; the release survives")
    func themeWithoutSectionKeepsRelease() {
        // A theme header before any ### section has nothing to attach to.
        // The parser drops the orphan header but must keep the release; the
        // bullets that follow degrade into the release intro.
        let document = ChangelogDocument.parse("""
        ## [1.0.0]

        #### Orphan theme

        - Orphan bullet.

        ## [0.9.0]

        ### Fixed

        - Surviving bullet.
        """)

        #expect(document.releases.map(\.version) == ["1.0.0", "0.9.0"])
        #expect(document.releases[0].sections.isEmpty)
        #expect(document.releases[0].intro.map(plain) == ["Orphan bullet."])
        #expect(document.newestRelease?.version == "1.0.0")
    }

    @Test("headers out of order never crash and unrecognized lines fall away")
    func headersOutOfOrderDegrade() {
        let document = ChangelogDocument.parse("""
        #### Theme first

        ### Section next

        - Homeless bullet.

        ## [1.0.0]

        random prose
        ### Added
        - Attached bullet.
        """)

        #expect(document.releases.count == 1)
        #expect(document.releases[0].version == "1.0.0")
        #expect(document.releases[0].sections.map(\.title) == ["Added"])
        #expect(document.releases[0].sections[0].themes[0].bullets.map(plain) == ["Attached bullet."])
    }

    // MARK: - Release dates

    @Test("a Keep a Changelog date after the version is read; its absence is nil")
    func releaseDates() throws {
        let document = ChangelogDocument.parse("""
        ## [2.0.0] - 2026-09-02
        - Dated.

        ## [1.5.0] -   2026-01-15
        - Dated with extra spaces.

        ## [1.0.0]
        - Undated.

        ## [0.9.0] - not a date
        - Garbage trailer.
        """)

        #expect(document.releases.count == 4)

        let calendar = Calendar(identifier: .gregorian)
        let dated = try #require(document.releases[0].date)
        // The parser reads a release date as a local day.
        let parts = calendar.dateComponents(in: TimeZone.current, from: dated)
        #expect((parts.year, parts.month, parts.day) == (2026, 9, 2))

        let spaced = try #require(document.releases[1].date)
        let spacedParts = calendar.dateComponents(in: TimeZone.current, from: spaced)
        #expect((spacedParts.year, spacedParts.month, spacedParts.day) == (2026, 1, 15))

        #expect(document.releases[2].date == nil)
        #expect(document.releases[2].version == "1.0.0")
        #expect(document.releases[3].date == nil)
        #expect(document.releases[3].version == "0.9.0")
    }

    @Test("numbered steps in the intro stay separate lines and keep their numbers")
    func numberedStepsStaySeparate() throws {
        let document = ChangelogDocument.parse("""
        ## [3.0.0] - 2026-10-11

        After you update:

        1. Open Settings > Layout and look at **Hiding method**.
        2. If the icon is missing,
           open Settings.

        ### Fixed

        - A real bullet.
        """)

        let release = try #require(document.releases.first)
        #expect(release.intro.map(plain) == [
            "After you update:",
            "1. Open Settings > Layout and look at Hiding method.",
            "2. If the icon is missing, open Settings.",
        ])
    }

    // MARK: - Intro prose and badges

    @Test("prose ahead of a release's first section is kept as intro; a badge line becomes a badge")
    func introProseAndBadges() throws {
        let document = ChangelogDocument.parse("""
        # Changelog

        Preamble prose that never surfaces.

        ## [1.0.0] - 2026-09-03

        A rebuilt release, written
        across two lines.

        [![On Product Hunt](Badge.svg)](https://example.com/thaw)

        <div>raw html for the repository page</div>

        - An intro bullet.

        ### Added

        Prose inside a section is still dropped.

        - A real bullet.
        """)

        let release = try #require(document.releases.first)
        #expect(release.intro.map(plain) == ["A rebuilt release, written across two lines.", "An intro bullet."])
        #expect(release.badges.count == 1)
        #expect(release.badges.first?.alt == "On Product Hunt")
        #expect(release.badges.first?.imageFileName == "Badge.svg")
        #expect(release.badges.first?.url.absoluteString == "https://example.com/thaw")
        #expect(release.sections[0].themes[0].bullets.map(plain) == ["A real bullet."])
    }

    @Test(
        "a badge whose link is not https is dropped, and the rest of the release stays",
        arguments: [
            "http://example.com/thaw",
            "file:///etc/passwd",
            "thaw://reset",
            "javascript:alert",
            "/relative/path",
            "https:no-host",
        ]
    )
    func nonHTTPSBadgeIsDropped(url: String) throws {
        let document = ChangelogDocument.parse("""
        ## [1.0.0]

        [![Dropped](Dropped.svg)](\(url))

        [![Kept](Kept.svg)](https://example.com/thaw)

        An intro paragraph.
        """)

        let release = try #require(document.releases.first)
        #expect(release.badges.map(\.alt) == ["Kept"])
        #expect(release.intro.map(plain) == ["An intro paragraph."])
    }

    @Test("a badge's https scheme is matched in any case")
    func httpsBadgeSchemeIgnoresCase() throws {
        let document = ChangelogDocument.parse("""
        ## [1.0.0]

        [![Upper](Upper.svg)](HTTPS://example.com/thaw)
        """)

        let release = try #require(document.releases.first)
        #expect(release.badges.map(\.alt) == ["Upper"])
    }
}
