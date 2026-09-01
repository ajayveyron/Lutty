import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import Foundation
import ImageIO
import Metal

enum ImageRendererError: LocalizedError {
    case unreadableImage
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: "This photo could not be opened."
        case .renderingFailed: "Lutty could not render this photo."
        }
    }
}
final class ImageRenderer: @unchecked Sendable {
    private let context: CIContext
    private let colorSpace: CGColorSpace

    init() {
        colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let options: [CIContextOption: Any] = [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
            .cacheIntermediates: false
        ]
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device, options: options)
        } else {
            context = CIContext(options: options)
        }
    }

    func preview(
        sourceData: Data,
        recipe: EditRecipe,
        lut: ParsedCubeLUT?,
        maximumDimension: CGFloat = 1_600
    ) throws -> CGImage {
        let source = try sourceImage(from: sourceData)
        let maximumSourceDimension = max(source.extent.width, source.extent.height)
        let scale = min(1, maximumDimension / maximumSourceDimension)
        let previewSource = scale < 1
            ? source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : source
        let output = normalizedExtent(process(image: previewSource, recipe: recipe, lut: lut))
        guard let image = context.createCGImage(
            output,
            from: output.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        ) else {
            throw ImageRendererError.renderingFailed
        }
        return image
    }

    func export(
        sourceData: Data,
        recipe: EditRecipe,
        lut: ParsedCubeLUT?,
        asPNG: Bool
    ) throws -> URL {
        let source = try sourceImage(from: sourceData)
        let output = normalizedExtent(process(image: source, recipe: recipe, lut: lut))
        let fileExtension = asPNG ? "png" : "heic"
        let outputURL = FileManager.default.temporaryDirectory
            .appending(path: "Lutty-\(UUID().uuidString).\(fileExtension)")

        if asPNG {
            try context.writePNGRepresentation(
                of: output,
                to: outputURL,
                format: .RGBA8,
                colorSpace: colorSpace
            )
        } else {
            try context.writeHEIFRepresentation(
                of: output,
                to: outputURL,
                format: .RGBA8,
                colorSpace: colorSpace,
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95]
            )
        }
        return outputURL
    }

    private func sourceImage(from data: Data) throws -> CIImage {
        guard let image = CIImage(
            data: data,
            options: [.applyOrientationProperty: true, .colorSpace: colorSpace]
        ), !image.extent.isEmpty, !image.extent.isInfinite else {
            throw ImageRendererError.unreadableImage
        }
        return normalizedExtent(image)
    }

    private func process(image: CIImage, recipe: EditRecipe, lut: ParsedCubeLUT?) -> CIImage {
        var output = image

        if let lut, recipe.selectedLUTID != nil {
            let domainAdjusted = applyDomain(to: output, lut: lut)
            let cube = CIFilter.colorCubeWithColorSpace()
            cube.inputImage = domainAdjusted
            cube.cubeDimension = Float(lut.size)
            cube.cubeData = lut.rgbaData
            cube.colorSpace = colorSpace

            if let filtered = cube.outputImage {
                output = blend(
                    foreground: filtered,
                    background: output,
                    amount: recipe.lutStrength
                )
            }
        }

        if recipe.exposure != 0 {
            let exposure = CIFilter.exposureAdjust()
            exposure.inputImage = output
            exposure.ev = Float(recipe.exposure)
            output = exposure.outputImage ?? output
        }

        if recipe.contrast != 1 || recipe.saturation != 1 {
            let controls = CIFilter.colorControls()
            controls.inputImage = output
            controls.contrast = Float(recipe.contrast)
            controls.saturation = Float(recipe.saturation)
            output = controls.outputImage ?? output
        }

        if recipe.temperature != 0 {
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = output
            temperature.neutral = CIVector(x: 6_500, y: 0)
            temperature.targetNeutral = CIVector(x: 6_500 + recipe.temperature * 2_500, y: 0)
            output = temperature.outputImage ?? output
        }

        return output.cropped(to: image.extent)
    }

    private func applyDomain(to image: CIImage, lut: ParsedCubeLUT) -> CIImage {
        let minimum = lut.domainMinimum
        let maximum = lut.domainMaximum
        guard minimum != .zero || maximum != .one else { return image }

        let redScale = 1 / (maximum.red - minimum.red)
        let greenScale = 1 / (maximum.green - minimum.green)
        let blueScale = 1 / (maximum.blue - minimum.blue)

        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        matrix.rVector = CIVector(x: CGFloat(redScale), y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: CGFloat(greenScale), z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: CGFloat(blueScale), w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.biasVector = CIVector(
            x: CGFloat(-minimum.red * redScale),
            y: CGFloat(-minimum.green * greenScale),
            z: CGFloat(-minimum.blue * blueScale),
            w: 0
        )
        return matrix.outputImage ?? image
    }

    private func blend(foreground: CIImage, background: CIImage, amount: Double) -> CIImage {
        guard amount < 0.999 else { return foreground }
        guard amount > 0.001 else { return background }
        let mask = CIImage(
            color: CIColor(red: amount, green: amount, blue: amount)
        ).cropped(to: background.extent)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = foreground
        blend.backgroundImage = background
        blend.maskImage = mask
        return blend.outputImage ?? foreground
    }

    private func normalizedExtent(_ image: CIImage) -> CIImage {
        guard image.extent.origin != .zero else { return image }
        return image.transformed(
            by: CGAffineTransform(
                translationX: -image.extent.origin.x,
                y: -image.extent.origin.y
            )
        )
    }
}
