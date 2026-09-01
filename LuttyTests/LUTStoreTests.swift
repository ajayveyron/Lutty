import Foundation
import Testing
@testable import Lutty

@Suite("Local LUT library")
@MainActor
struct LUTStoreTests {
    @Test("Imports, renames, reloads, and deletes a LUT")
    func persistsLibraryChanges() throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appending(path: "LuttyStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: testRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        let sourceURL = testRoot.appending(path: "Source.cube")
        try Data(CubeLUTParserTests.identityCube.utf8).write(to: sourceURL)
        let storageURL = testRoot.appending(path: "Storage", directoryHint: .isDirectory)

        let store = LUTStore(rootURL: storageURL)
        let imported = try store.importLUT(from: sourceURL)
        #expect(store.luts.count == 1)
        #expect(imported.displayName == "Identity")

        try store.rename(imported, to: "Daily Color")
        #expect(store.luts.first?.displayName == "Daily Color")

        let reloaded = LUTStore(rootURL: storageURL)
        #expect(reloaded.luts.first?.displayName == "Daily Color")
        #expect(try reloaded.parsedLUT(for: imported.id)?.size == 2)

        guard let persisted = reloaded.luts.first else {
            Issue.record("Expected the imported LUT to persist")
            return
        }
        try reloaded.delete(persisted)
        #expect(reloaded.luts.isEmpty)
        #expect(LUTStore(rootURL: storageURL).luts.isEmpty)
    }

    @Test("Rejects an empty rename")
    func rejectsEmptyRename() throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appending(path: "LuttyRenameTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: testRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        let sourceURL = testRoot.appending(path: "Source.cube")
        try Data(CubeLUTParserTests.identityCube.utf8).write(to: sourceURL)
        let store = LUTStore(rootURL: testRoot.appending(path: "Storage"))
        let imported = try store.importLUT(from: sourceURL)

        #expect(throws: LUTStoreError.self) {
            try store.rename(imported, to: "   ")
        }
    }

    @Test("Seeds bundled LUTs only once")
    func seedsBundledLUTsOnce() throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appending(path: "LuttySeedTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: testRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        let sourceURL = testRoot.appending(path: "Soft-Warm.cube")
        try Data(CubeLUTParserTests.identityCube.utf8).write(to: sourceURL)
        let storageURL = testRoot.appending(path: "Storage", directoryHint: .isDirectory)

        let seeded = LUTStore(rootURL: storageURL, bundledLUTURLs: [sourceURL])
        #expect(seeded.luts.map(\.displayName) == ["Identity"])

        guard let bundledLUT = seeded.luts.first else {
            Issue.record("Expected a bundled LUT")
            return
        }
        try seeded.delete(bundledLUT)

        let reloaded = LUTStore(rootURL: storageURL, bundledLUTURLs: [sourceURL])
        #expect(reloaded.luts.isEmpty)
    }

    @Test("Bundles four valid warm presets")
    func bundlesWarmPresets() throws {
        let urls = Bundle.main.urls(forResourcesWithExtension: "cube", subdirectory: nil) ?? []
        let parsed = try urls.map { url in
            try CubeLUTParser.parse(data: Data(contentsOf: url))
        }

        #expect(parsed.count == 4)
        #expect(Set(parsed.compactMap(\.title)) == [
            "Soft Warm",
            "Golden Hour",
            "Rose Fade",
            "Story Glow"
        ])
        #expect(parsed.allSatisfy { $0.size == 17 })
    }
}

@Suite("Local edit presets")
@MainActor
struct PresetStoreTests {
    @Test("Saves, reloads, and deletes the complete edit recipe")
    func persistsPresetChanges() throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appending(path: "LuttyPresetTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        let lutID = UUID()
        var recipe = EditRecipe.original
        recipe.selectedLUTID = lutID
        recipe.lutStrength = 0.72
        recipe.exposure = 0.4
        recipe.highlights = -0.3
        recipe.shadows = 0.25
        recipe.dehaze = 0.35
        recipe.sharpness = 0.45
        recipe.vignette = 0.5
        recipe.filmGrain = 0.2

        let store = PresetStore(rootURL: testRoot)
        let saved = try store.save(name: "  Evening Walk  ", recipe: recipe)
        #expect(saved.name == "Evening Walk")
        #expect(saved.recipe == recipe)

        let reloaded = PresetStore(rootURL: testRoot)
        #expect(reloaded.presets.count == 1)
        #expect(reloaded.presets.first?.recipe.selectedLUTID == lutID)
        #expect(reloaded.presets.first?.recipe.filmGrain == 0.2)

        guard let persisted = reloaded.presets.first else {
            Issue.record("Expected the preset to persist")
            return
        }
        try reloaded.delete(persisted)
        #expect(PresetStore(rootURL: testRoot).presets.isEmpty)
    }

    @Test("Rejects an empty preset name")
    func rejectsEmptyName() {
        let testRoot = FileManager.default.temporaryDirectory
            .appending(path: "LuttyPresetNameTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        let store = PresetStore(rootURL: testRoot)
        #expect(throws: PresetStoreError.self) {
            try store.save(name: "   ", recipe: .original)
        }
    }
}
