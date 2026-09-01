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
        let outputURL = try ImageRenderer().export(
            sourceData: source,
            recipe: .original,
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
