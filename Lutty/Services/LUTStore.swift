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

    private let fileManager: FileManager
    private let rootURL: URL
    private let filesURL: URL
    private let manifestURL: URL

    init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseURL = rootURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Lutty", directoryHint: .isDirectory)
        self.rootURL = baseURL
        self.filesURL = baseURL.appending(path: "LUTs", directoryHint: .isDirectory)
        self.manifestURL = baseURL.appending(path: "luts.json")
        prepareStorage()
        loadManifest()
    }

    @discardableResult
    func importLUT(from sourceURL: URL) throws -> LUTDefinition {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
        let parsed = try CubeLUTParser.parse(data: data)
        let id = UUID()
        let storedFilename = "\(id.uuidString).cube"
        let destinationURL = filesURL.appending(path: storedFilename)
        try data.write(to: destinationURL, options: .atomic)

        let fallbackName = sourceURL.deletingPathExtension().lastPathComponent
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
        sortLUTs()

        do {
            try saveManifest()
        } catch {
            luts.removeAll { $0.id == id }
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
        return definition
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
        do {
            try saveManifest()
            try? fileManager.removeItem(at: fileURL)
        } catch {
            luts.append(lut)
            sortLUTs()
            if let fileData, !fileManager.fileExists(atPath: fileURL.path) {
                try? fileData.write(to: fileURL, options: .atomic)
            }
            throw error
        }
    }

    func parsedLUT(for id: UUID?) throws -> ParsedCubeLUT? {
        guard let id else { return nil }
        guard let lut = luts.first(where: { $0.id == id }) else {
            throw LUTStoreError.missingLUT
        }
        let data = try Data(contentsOf: filesURL.appending(path: lut.storedFilename), options: .mappedIfSafe)
        return try CubeLUTParser.parse(data: data)
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
