import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class EditorViewModel {
    var recipe = EditRecipe.original
    var selectedAdjustment: AdjustmentKind = .exposure
    var previewImage: UIImage?
    var originalImage: UIImage?
    var isRendering = true
    var isExporting = false
    var errorMessage: String?
    var exportNotice: String?
    var shareURL: URL?
    var isSharePresented = false

    let asset: PhotoAsset

    private let lutStore: LUTStore
    private let renderer: ImageRenderer
    private var preparedPreview: PreparedPreviewImage?
    private var pendingPreviewRequest: PreviewRequest?
    private var loadTask: Task<Void, Never>?
    private var previewLoopTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?

    init(asset: PhotoAsset, lutStore: LUTStore, renderer: ImageRenderer = ImageRenderer()) {
        self.asset = asset
        self.lutStore = lutStore
        self.renderer = renderer
    }

    func loadInitialPreview() {
        loadTask?.cancel()
        previewLoopTask?.cancel()
        pendingPreviewRequest = nil
        let sourceData = asset.data
        let renderer = renderer
        loadTask = Task {
            isRendering = true
            do {
                let prepared = try await Task.detached(priority: .userInitiated) {
                    try renderer.preparePreview(sourceData: sourceData)
                }.value
                try Task.checkCancellation()
                preparedPreview = prepared
                let uiImage = UIImage(cgImage: prepared.original)
                originalImage = uiImage
                previewImage = uiImage
                if recipe != .original {
                    schedulePreview()
                }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
            isRendering = false
        }
    }

    func schedulePreview() {
        guard preparedPreview != nil else { return }

        do {
            pendingPreviewRequest = PreviewRequest(
                recipe: recipe,
                lut: try lutStore.parsedLUT(for: recipe.selectedLUTID)
            )
            startPreviewLoopIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startPreviewLoopIfNeeded() {
        guard previewLoopTask == nil, let preparedPreview else { return }
        let renderer = renderer

        previewLoopTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(8))

                while !Task.isCancelled, let request = pendingPreviewRequest {
                    pendingPreviewRequest = nil
                    let image = try await Task.detached(priority: .userInitiated) {
                        try renderer.preview(
                            prepared: preparedPreview,
                            recipe: request.recipe,
                            lut: request.lut
                        )
                    }.value
                    try Task.checkCancellation()

                    if request.recipe == recipe {
                        previewImage = UIImage(cgImage: image)
                    }
                }
            } catch is CancellationError {
                // A newer editor lifecycle owns preview rendering now.
            } catch {
                errorMessage = error.localizedDescription
            }

            previewLoopTask = nil
            if pendingPreviewRequest != nil {
                startPreviewLoopIfNeeded()
            }
        }
    }

    func selectLUT(_ id: UUID?) {
        recipe.selectedLUTID = id
    }

    func applyPreset(_ preset: EditPreset) {
        var savedRecipe = preset.recipe
        if let selectedLUTID = savedRecipe.selectedLUTID,
           !lutStore.luts.contains(where: { $0.id == selectedLUTID }) {
            savedRecipe.selectedLUTID = nil
            errorMessage = "\(preset.name) used a LUT that is no longer available. The other adjustments were applied."
        }
        recipe = savedRecipe
        selectedAdjustment = .exposure
    }

    func reset() {
        recipe = .original
        selectedAdjustment = .exposure
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

private struct PreviewRequest: Sendable {
    let recipe: EditRecipe
    let lut: ParsedCubeLUT?
}
