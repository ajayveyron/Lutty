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

struct PreparedPreviewImage: @unchecked Sendable {
    let source: CIImage
    let original: CGImage
}

final class ImageRenderer: @unchecked Sendable {
    private let context: CIContext
    private let colorSpace: CGColorSpace

    init() {
        colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let options: [CIContextOption: Any] = [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
            .cacheIntermediates: true
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
        maximumDimension: CGFloat = 1_200
    ) throws -> CGImage {
        let prepared = try preparePreview(
            sourceData: sourceData,
            maximumDimension: maximumDimension
        )
        return try preview(prepared: prepared, recipe: recipe, lut: lut)
    }

    func preparePreview(
        sourceData: Data,
        maximumDimension: CGFloat = 1_200
    ) throws -> PreparedPreviewImage {
        let source = try sourceImage(from: sourceData)
        let maximumSourceDimension = max(source.extent.width, source.extent.height)
        let scale = min(1, maximumDimension / maximumSourceDimension)
        let previewSource = normalizedExtent(scale < 1
            ? source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : source)
        guard let original = context.createCGImage(
            previewSource,
            from: previewSource.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        ) else {
            throw ImageRendererError.renderingFailed
        }
        return PreparedPreviewImage(source: previewSource, original: original)
    }

    func preview(
        prepared: PreparedPreviewImage,
        recipe: EditRecipe,
        lut: ParsedCubeLUT?
    ) throws -> CGImage {
        let output = normalizedExtent(process(image: prepared.source, recipe: recipe, lut: lut))
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

        if recipe.highlights != 0 || recipe.shadows != 0 {
            let toneCurve = CIFilter.toneCurve()
            toneCurve.inputImage = output
            toneCurve.point0 = CGPoint(x: 0, y: 0)
            toneCurve.point1 = CGPoint(
                x: 0.25,
                y: 0.25 + recipe.shadows * 0.20
            )
            toneCurve.point2 = CGPoint(x: 0.5, y: 0.5)
            toneCurve.point3 = CGPoint(
                x: 0.75,
                y: 0.75 + recipe.highlights * 0.20
            )
            toneCurve.point4 = CGPoint(x: 1, y: 1)
            output = toneCurve.outputImage ?? output
        }

        if recipe.temperature != 0 {
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = output
            temperature.neutral = CIVector(x: 6_500, y: 0)
            temperature.targetNeutral = CIVector(x: 6_500 + recipe.temperature * 2_500, y: 0)
            output = temperature.outputImage ?? output
        }

        if recipe.dehaze != 0 {
            let dehaze = CIFilter.colorControls()
            dehaze.inputImage = output
            dehaze.contrast = Float(1 + recipe.dehaze * 0.35)
            dehaze.saturation = Float(1 + recipe.dehaze * 0.15)
            dehaze.brightness = Float(-recipe.dehaze * 0.02)
            output = dehaze.outputImage ?? output
        }

        if recipe.sharpness > 0 {
            let sharpness = CIFilter.sharpenLuminance()
            sharpness.inputImage = output
            sharpness.sharpness = Float(recipe.sharpness * 1.5)
            output = sharpness.outputImage ?? output
        }

        if recipe.vignette > 0 {
            let vignette = CIFilter.vignette()
            vignette.inputImage = output
            vignette.intensity = Float(recipe.vignette)
            vignette.radius = 1
            output = vignette.outputImage ?? output
        }

        if recipe.filmGrain > 0 {
            output = applyFilmGrain(to: output, amount: recipe.filmGrain)
        }

        return output.cropped(to: image.extent)
    }

    private func applyFilmGrain(to image: CIImage, amount: Double) -> CIImage {
        let random = CIFilter.randomGenerator()
        guard var noise = random.outputImage else { return image }
        noise = noise
            .transformed(by: CGAffineTransform(scaleX: 1.35, y: 1.35))
            .cropped(to: image.extent)

        let monochrome = CIFilter.colorControls()
        monochrome.inputImage = noise
        monochrome.saturation = 0
        monochrome.contrast = 1.45
        guard let monochromeNoise = monochrome.outputImage else { return image }

        let opaqueNoise = CIFilter.colorMatrix()
        opaqueNoise.inputImage = monochromeNoise
        opaqueNoise.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        opaqueNoise.biasVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let noiseLayer = opaqueNoise.outputImage?.cropped(to: image.extent) else {
            return image
        }

        let constrainedNoise = CIFilter.sourceAtopCompositing()
        constrainedNoise.inputImage = noiseLayer
        constrainedNoise.backgroundImage = image
        guard let alphaMatchedNoise = constrainedNoise.outputImage else { return image }

        let softLight = CIFilter.softLightBlendMode()
        softLight.inputImage = alphaMatchedNoise
        softLight.backgroundImage = image
        guard let grained = softLight.outputImage?.cropped(to: image.extent) else { return image }

        return blend(
            foreground: grained,
            background: image,
            amount: amount * 0.65
        )
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
