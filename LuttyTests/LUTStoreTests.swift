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
}
