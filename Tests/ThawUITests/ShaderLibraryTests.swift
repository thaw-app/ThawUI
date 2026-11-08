//
//  ShaderLibraryTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CryptoKit
import Foundation
import Testing
@testable import ThawUI

@Suite("Precompiled shaders")
struct ShaderLibraryTests {
    private static let packageRoot = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test("ThawUI ships the precompiled metallib")
    func metallibIsBundled() throws {
        let url = try #require(Bundle.module.url(forResource: "ThawUI", withExtension: "metallib"))
        #expect(try Data(contentsOf: url).isEmpty == false)
    }

    @Test("The metallib was built from the current shader sources")
    func metallibMatchesSources() throws {
        let shaders = Self.packageRoot.appending(path: "Shaders")
        let recorded = try String(contentsOf: shaders.appending(path: "sources.sha256"), encoding: .utf8)
        let sources = try FileManager.default.contentsOfDirectory(atPath: shaders.path)
            .filter { $0.hasSuffix(".metal") }
            .sorted()
        let current = try sources.map { name in
            let digest = try SHA256.hash(data: Data(contentsOf: shaders.appending(path: name)))
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            return "\(hex)  Shaders/\(name)\n"
        }.joined()
        #expect(current == recorded, "A shader changed. Run scripts/build-shaders.sh and commit the new metallib.")
    }
}
