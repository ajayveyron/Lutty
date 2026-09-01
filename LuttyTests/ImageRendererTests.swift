import CoreGraphics
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Lutty

@Suite("Image renderer")
struct ImageRendererTests {
    @Test("Identity LUT preserves source color")
    func identityLUTPreservesColor() throws {
        let source = try solidPNG(red: 0.25, green: 0.50, blue: 0.75, alpha: 1)
        let renderer = ImageRenderer()
        let original = try renderer.preview(sourceData: source, recipe: .original, lut: nil)
        let identity = try CubeLUTParser.parse(data: Data(CubeLUTParserTests.identityCube.utf8))
        var recipe = EditRecipe.original
        recipe.selectedLUTID = UUID()
        let filtered = try renderer.preview(sourceData: source, recipe: recipe, lut: identity)

        let originalPixel = try pixel(from: original)
        let filteredPixel = try pixel(from: filtered)
        #expect(abs(Int(originalPixel.red) - Int(filteredPixel.red)) <= 3)
        #expect(abs(Int(originalPixel.green) - Int(filteredPixel.green)) <= 3)
        #expect(abs(Int(originalPixel.blue) - Int(filteredPixel.blue)) <= 3)
    }

    @Test("Exposure changes the rendered result")
    func exposureChangesImage() throws {
        let source = try solidPNG(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
        let renderer = ImageRenderer()
        let original = try renderer.preview(sourceData: source, recipe: .original, lut: nil)
        var brighterRecipe = EditRecipe.original
        brighterRecipe.exposure = 1
        let brighter = try renderer.preview(sourceData: source, recipe: brighterRecipe, lut: nil)

        #expect(try pixel(from: brighter).red > pixel(from: original).red)
    }

    @Test("Highlights and shadows change their tonal regions")
    func tonalAdjustmentsChangeImage() throws {
        let renderer = ImageRenderer()

        let highlightSource = try solidPNG(red: 0.75, green: 0.75, blue: 0.75, alpha: 1)
        let originalHighlights = try renderer.preview(
            sourceData: highlightSource,
            recipe: .original,
            lut: nil
        )
        var highlightRecipe = EditRecipe.original
        highlightRecipe.highlights = 0.8
        let adjustedHighlights = try renderer.preview(
            sourceData: highlightSource,
            recipe: highlightRecipe,
            lut: nil
        )
        #expect(try rgbaBytes(from: originalHighlights) != rgbaBytes(from: adjustedHighlights))

        let shadowSource = try solidPNG(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
        let originalShadows = try renderer.preview(
            sourceData: shadowSource,
            recipe: .original,
            lut: nil
        )
        var shadowRecipe = EditRecipe.original
        shadowRecipe.shadows = 0.8
        let adjustedShadows = try renderer.preview(
            sourceData: shadowSource,
            recipe: shadowRecipe,
            lut: nil
        )
        #expect(try rgbaBytes(from: originalShadows) != rgbaBytes(from: adjustedShadows))
    }

    @Test("Dehaze and sharpness change the rendered result")
    func detailAdjustmentsChangeImage() throws {
        let source = try splitTonePNG()
        let renderer = ImageRenderer()
        let original = try renderer.preview(sourceData: source, recipe: .original, lut: nil)

        var dehazeRecipe = EditRecipe.original
        dehazeRecipe.dehaze = 0.8
        let dehazed = try renderer.preview(sourceData: source, recipe: dehazeRecipe, lut: nil)
        #expect(try rgbaBytes(from: original) != rgbaBytes(from: dehazed))

        var sharpnessRecipe = EditRecipe.original
        sharpnessRecipe.sharpness = 1
        let sharpened = try renderer.preview(sourceData: source, recipe: sharpnessRecipe, lut: nil)
        #expect(try rgbaBytes(from: original) != rgbaBytes(from: sharpened))
    }

    @Test("Vignette and film grain change the rendered result")
    func textureAdjustmentsChangeImage() throws {
        let source = try solidPNG(red: 0.5, green: 0.5, blue: 0.5, alpha: 1, size: 64)
        let renderer = ImageRenderer()
        let original = try renderer.preview(sourceData: source, recipe: .original, lut: nil)

        var vignetteRecipe = EditRecipe.original
        vignetteRecipe.vignette = 1
        let vignette = try renderer.preview(sourceData: source, recipe: vignetteRecipe, lut: nil)
        #expect(try rgbaBytes(from: original) != rgbaBytes(from: vignette))

        var grainRecipe = EditRecipe.original
        grainRecipe.filmGrain = 1
        let grain = try renderer.preview(sourceData: source, recipe: grainRecipe, lut: nil)
        #expect(try rgbaBytes(from: original) != rgbaBytes(from: grain))
    }

    @Test("Image orientation metadata is applied")
    func appliesOrientationMetadata() throws {
        let encoded = try orientedJPEG(width: 6, height: 4, orientation: 6)
        let preview = try ImageRenderer().preview(sourceData: encoded, recipe: .original, lut: nil)

        #expect(preview.width == 4)
        #expect(preview.height == 6)
    }

    @Test("PNG export preserves alpha and full dimensions")
    func pngExportPreservesAlpha() throws {
        let source = try solidPNG(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.4, size: 12)
        var recipe = EditRecipe.original
        recipe.vignette = 0.7
        recipe.filmGrain = 0.8
        let outputURL = try ImageRenderer().export(
            sourceData: source,
            recipe: recipe,
            lut: nil,
            asPNG: true
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        guard let source = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            Issue.record("Unable to read exported PNG")
            return
        }
        #expect(outputURL.pathExtension == "png")
        #expect(image.width == 12)
        #expect(image.height == 12)
        #expect(try pixel(from: image).alpha < 255)
    }

    @Test("Photo export uses HEIC")
    func exportsHEIC() throws {
        let source = try solidPNG(red: 0.4, green: 0.5, blue: 0.6, alpha: 1)
        let outputURL = try ImageRenderer().export(
            sourceData: source,
            recipe: .original,
            lut: nil,
            asPNG: false
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        #expect(outputURL.pathExtension == "heic")
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }

    private func solidPNG(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat,
        size: CGFloat = 8
    ) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            UIColor(red: red, green: green, blue: blue, alpha: alpha).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }
        guard let data = image.pngData() else { throw ImageRendererError.renderingFailed }
        return data
    }

    private func orientedJPEG(width: Int, height: Int, orientation: UInt32) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw ImageRendererError.renderingFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageRendererError.renderingFailed
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImagePropertyOrientation: orientation] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw ImageRendererError.renderingFailed
        }
        return data as Data
    }

    private func splitTonePNG(size: CGFloat = 32) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            UIColor(white: 0.35, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size / 2, height: size))
            UIColor(white: 0.65, alpha: 1).setFill()
            context.fill(CGRect(x: size / 2, y: 0, width: size / 2, height: size))
        }
        guard let data = image.pngData() else { throw ImageRendererError.renderingFailed }
        return data
    }

    private func rgbaBytes(from image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageRendererError.renderingFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return bytes
    }

    private func pixel(from image: CGImage) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageRendererError.renderingFailed
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}

@Suite("Adjustment gestures")
struct AdjustmentGestureTests {
    @Test("Vertical swipes move through adjustments and stay in bounds")
    func verticalSelection() {
        #expect(AdjustmentGestureMath.selectionIndex(start: 2, verticalTranslation: -52, count: 4) == 1)
        #expect(AdjustmentGestureMath.selectionIndex(start: 1, verticalTranslation: 60, count: 4) == 2)
        #expect(AdjustmentGestureMath.selectionIndex(start: 0, verticalTranslation: -500, count: 4) == 0)
        #expect(AdjustmentGestureMath.selectionIndex(start: 3, verticalTranslation: 500, count: 4) == 3)
    }

    @Test("Horizontal swipes change values and clamp to their range")
    func horizontalAdjustment() {
        let range = -2.0...2.0
        #expect(AdjustmentGestureMath.adjustedValue(
            start: 0,
            horizontalTranslation: 160,
            range: range
        ) == 1)
        #expect(AdjustmentGestureMath.adjustedValue(
            start: 0,
            horizontalTranslation: 1_000,
            range: range
        ) == 2)
        #expect(AdjustmentGestureMath.adjustedValue(
            start: 0,
            horizontalTranslation: -1_000,
            range: range
        ) == -2)
    }
}

@Suite("Export sharing")
@MainActor
struct ExportSharingTests {
    @Test("A successful automatic save removes the duplicate Save Image action")
    func excludesDuplicatePhotosSave() {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "LuttyExportPolicyTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let viewModel = EditorViewModel(
            asset: PhotoAsset(data: Data(), isPNG: false),
            lutStore: LUTStore(rootURL: storeURL)
        )

        #expect(viewModel.excludedShareActivityTypes.isEmpty)
        viewModel.didSaveToPhotos = true
        #expect(viewModel.excludedShareActivityTypes == [.saveToCameraRoll])
    }

    @Test("Dismissing share removes its temporary rendered file")
    func removesTemporaryShareFile() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "LuttyShareCleanupTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "LuttyShareCleanup-\(UUID().uuidString).heic")
        try Data([0x01]).write(to: fileURL)

        let viewModel = EditorViewModel(
            asset: PhotoAsset(data: Data(), isPNG: false),
            lutStore: LUTStore(rootURL: storeURL)
        )
        viewModel.shareURL = fileURL
        viewModel.isSharePresented = true
        viewModel.didSaveToPhotos = true

        viewModel.shareDidDismiss()

        #expect(viewModel.shareURL == nil)
        #expect(!viewModel.isSharePresented)
        #expect(!viewModel.didSaveToPhotos)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
}
