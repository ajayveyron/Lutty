import Foundation
import Observation

enum LUTStoreError: LocalizedError {
    case missingLUT
    case invalidName

    var errorDescription: String? {
        switch self {
        case .missingLUT: "That LUT is no longer available."
        case .invalidName: "Enter a name for this LUT."
        }
    }
}

@MainActor
@Observable
final class LUTStore {
    private(set) var luts: [LUTDefinition] = []
    private var parsedLUTCache: [UUID: ParsedCubeLUT] = [:]

    private let fileManager: FileManager
    private let rootURL: URL
    private let filesURL: URL
    private let manifestURL: URL
    private let bundledSeedMarkerURL: URL

    init(
        rootURL: URL? = nil,
        fileManager: FileManager = .default,
        bundledLUTURLs: [URL]? = nil
    ) {
        self.fileManager = fileManager
        let baseURL = rootURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Lutty", directoryHint: .isDirectory)
        self.rootURL = baseURL
        self.filesURL = baseURL.appending(path: "LUTs", directoryHint: .isDirectory)
        self.manifestURL = baseURL.appending(path: "luts.json")
        self.bundledSeedMarkerURL = baseURL.appending(path: "bundled-luts-v1.seeded")
        prepareStorage()
        loadManifest()

        let shouldSeed = rootURL == nil || bundledLUTURLs != nil
        if shouldSeed {
            let sourceURLs = bundledLUTURLs ?? Bundle.main.urls(
                forResourcesWithExtension: "cube",
                subdirectory: nil
            ) ?? []
            seedBundledLUTsIfNeeded(from: sourceURLs)
        }
    }

    @discardableResult
    func importLUT(from sourceURL: URL) throws -> LUTDefinition {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
        return try importLUT(
            data: data,
            fallbackName: sourceURL.deletingPathExtension().lastPathComponent
        )
    }

    private func importLUT(data: Data, fallbackName: String) throws -> LUTDefinition {
        let parsed = try CubeLUTParser.parse(data: data)
        let id = UUID()
        let storedFilename = "\(id.uuidString).cube"
        let destinationURL = filesURL.appending(path: storedFilename)
        try data.write(to: destinationURL, options: .atomic)

        let definition = LUTDefinition(
            id: id,
            displayName: parsed.title ?? fallbackName,
            storedFilename: storedFilename,
            importDate: .now,
            cubeSize: parsed.size,
            domainMinimum: parsed.domainMinimum,
            domainMaximum: parsed.domainMaximum
        )
        luts.append(definition)
        parsedLUTCache[id] = parsed
        sortLUTs()

        do {
            try saveManifest()
        } catch {
            luts.removeAll { $0.id == id }
            parsedLUTCache[id] = nil
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
        return definition
    }

    private func seedBundledLUTsIfNeeded(from sourceURLs: [URL]) {
        guard !fileManager.fileExists(atPath: bundledSeedMarkerURL.path) else { return }
        guard !sourceURLs.isEmpty else { return }

        do {
            for sourceURL in sourceURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
                _ = try importLUT(
                    data: data,
                    fallbackName: sourceURL.deletingPathExtension().lastPathComponent
                )
            }
            try Data().write(to: bundledSeedMarkerURL, options: .atomic)
        } catch {
            assertionFailure("Unable to seed bundled LUTs: \(error.localizedDescription)")
        }
    }

    func rename(_ lut: LUTDefinition, to proposedName: String) throws {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LUTStoreError.invalidName }
        guard let index = luts.firstIndex(where: { $0.id == lut.id }) else {
            throw LUTStoreError.missingLUT
        }
        let previous = luts[index].displayName
        luts[index].displayName = name
        sortLUTs()
        do {
            try saveManifest()
        } catch {
            if let restoredIndex = luts.firstIndex(where: { $0.id == lut.id }) {
                luts[restoredIndex].displayName = previous
            }
            sortLUTs()
            throw error
        }
    }

    func delete(_ lut: LUTDefinition) throws {
        guard let index = luts.firstIndex(where: { $0.id == lut.id }) else {
            throw LUTStoreError.missingLUT
        }
        let fileURL = filesURL.appending(path: lut.storedFilename)
        let fileData = try? Data(contentsOf: fileURL)
        luts.remove(at: index)
        let cachedLUT = parsedLUTCache.removeValue(forKey: lut.id)
        do {
            try saveManifest()
            try? fileManager.removeItem(at: fileURL)
        } catch {
            luts.append(lut)
            parsedLUTCache[lut.id] = cachedLUT
            sortLUTs()
            if let fileData, !fileManager.fileExists(atPath: fileURL.path) {
                try? fileData.write(to: fileURL, options: .atomic)
            }
            throw error
        }
    }

    func parsedLUT(for id: UUID?) throws -> ParsedCubeLUT? {
        guard let id else { return nil }
        if let cached = parsedLUTCache[id] {
            return cached
        }
        guard let lut = luts.first(where: { $0.id == id }) else {
            throw LUTStoreError.missingLUT
        }
        let data = try Data(contentsOf: filesURL.appending(path: lut.storedFilename), options: .mappedIfSafe)
        let parsed = try CubeLUTParser.parse(data: data)
        parsedLUTCache[id] = parsed
        return parsed
    }

    private func prepareStorage() {
        do {
            try fileManager.createDirectory(at: filesURL, withIntermediateDirectories: true)
        } catch {
            assertionFailure("Unable to create LUT storage: \(error.localizedDescription)")
        }
    }

    private func loadManifest() {
        guard fileManager.fileExists(atPath: manifestURL.path) else { return }
        do {
            let data = try Data(contentsOf: manifestURL)
            luts = try JSONDecoder().decode([LUTDefinition].self, from: data)
                .filter { fileManager.fileExists(atPath: filesURL.appending(path: $0.storedFilename).path) }
            sortLUTs()
        } catch {
            luts = []
        }
    }

    private func saveManifest() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(luts).write(to: manifestURL, options: .atomic)
    }

    private func sortLUTs() {
        luts.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}
