import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class EditorViewModel {
    var recipe = EditRecipe.original
    var selectedAdjustment: AdjustmentKind = .lut
    var previewImage: UIImage?
    var originalImage: UIImage?
    var isRendering = true
    var isExporting = false
    var isComparing = false
    var errorMessage: String?
    var exportNotice: String?
    var shareURL: URL?
    var isSharePresented = false

    let asset: PhotoAsset

    private let lutStore: LUTStore
    private let renderer: ImageRenderer
    private var previewTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?

    init(asset: PhotoAsset, lutStore: LUTStore, renderer: ImageRenderer = ImageRenderer()) {
        self.asset = asset
        self.lutStore = lutStore
        self.renderer = renderer
    }

    func loadInitialPreview() {
        previewTask?.cancel()
        let sourceData = asset.data
        let renderer = renderer
        previewTask = Task {
            isRendering = true
            do {
                let image = try await Task.detached(priority: .userInitiated) {
                    try renderer.preview(sourceData: sourceData, recipe: .original, lut: nil)
                }.value
                try Task.checkCancellation()
                let uiImage = UIImage(cgImage: image)
                originalImage = uiImage
                previewImage = uiImage
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
            isRendering = false
        }
    }

    func schedulePreview() {
        previewTask?.cancel()
        let sourceData = asset.data
        let currentRecipe = recipe
        let renderer = renderer

        do {
            let lut = try lutStore.parsedLUT(for: currentRecipe.selectedLUTID)
            previewTask = Task {
                do {
                    try await Task.sleep(for: .milliseconds(45))
                    let image = try await Task.detached(priority: .userInitiated) {
                        try renderer.preview(sourceData: sourceData, recipe: currentRecipe, lut: lut)
                    }.value
                    try Task.checkCancellation()
                    previewImage = UIImage(cgImage: image)
                } catch is CancellationError {
                    return
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectLUT(_ id: UUID?) {
        recipe.selectedLUTID = id
        selectedAdjustment = .lut
    }

    func reset() {
        recipe = .original
        selectedAdjustment = .lut
    }

    func export() {
        guard !isExporting else { return }
        exportTask?.cancel()
        isExporting = true
        exportNotice = nil

        let sourceData = asset.data
        let currentRecipe = recipe
        let asPNG = asset.isPNG
        let renderer = renderer

        do {
            let lut = try lutStore.parsedLUT(for: currentRecipe.selectedLUTID)
            exportTask = Task {
                defer { isExporting = false }
                do {
                    let fileURL = try await Task.detached(priority: .userInitiated) {
                        try renderer.export(
                            sourceData: sourceData,
                            recipe: currentRecipe,
                            lut: lut,
                            asPNG: asPNG
                        )
                    }.value
                    try Task.checkCancellation()
                    shareURL = fileURL

                    do {
                        try await PhotoExporter.saveToPhotos(fileURL: fileURL)
                        exportNotice = "Saved to Photos"
                    } catch {
                        exportNotice = error.localizedDescription
                    }
                    isSharePresented = true
                } catch is CancellationError {
                    return
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } catch {
            isExporting = false
            errorMessage = error.localizedDescription
        }
    }
}
