import Foundation
import Photos

enum PhotoExporterError: LocalizedError {
    case accessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Photos access was denied. Your rendered image is still ready to share."
        case .saveFailed: "The image could not be added to Photos. It is still ready to share."
        }
    }
}
enum PhotoExporter {
    static func saveToPhotos(fileURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoExporterError.accessDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhotoExporterError.saveFailed)
                }
            }
        }
    }
}
