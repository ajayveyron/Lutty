import Foundation
import Observation

enum PresetStoreError: LocalizedError {
    case invalidName
    case missingPreset

    var errorDescription: String? {
        switch self {
        case .invalidName: "Enter a name for this preset."
        case .missingPreset: "That preset is no longer available."
        }
    }
}

@MainActor
@Observable
final class PresetStore {
    private(set) var presets: [EditPreset] = []

    private let fileManager: FileManager
    private let rootURL: URL
    private let manifestURL: URL

    init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseURL = rootURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appending(path: "Lutty", directoryHint: .isDirectory)
        self.rootURL = baseURL
        self.manifestURL = baseURL.appending(path: "presets.json")
        prepareStorage()
        loadManifest()
    }

    @discardableResult
    func save(name proposedName: String, recipe: EditRecipe) throws -> EditPreset {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw PresetStoreError.invalidName }

        let preset = EditPreset(
            id: UUID(),
            name: name,
            createdAt: .now,
            recipe: recipe
        )
        presets.append(preset)
        sortPresets()

        do {
            try saveManifest()
        } catch {
            presets.removeAll { $0.id == preset.id }
            throw error
        }
        return preset
    }

    func delete(_ preset: EditPreset) throws {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else {
            throw PresetStoreError.missingPreset
        }
        let removed = presets.remove(at: index)
        do {
            try saveManifest()
        } catch {
            presets.append(removed)
            sortPresets()
            throw error
        }
    }

    private func prepareStorage() {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        } catch {
            assertionFailure("Unable to create preset storage: \(error.localizedDescription)")
        }
    }

    private func loadManifest() {
        guard fileManager.fileExists(atPath: manifestURL.path) else { return }
        do {
            let data = try Data(contentsOf: manifestURL)
            presets = try JSONDecoder().decode([EditPreset].self, from: data)
            sortPresets()
        } catch {
            presets = []
        }
    }

    private func saveManifest() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(presets).write(to: manifestURL, options: .atomic)
    }

    private func sortPresets() {
        presets.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
