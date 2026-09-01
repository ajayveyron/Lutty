import Foundation

struct EditRecipe: Codable, Equatable, Sendable {
    var selectedLUTID: UUID?
    var lutStrength: Double = 1
    var exposure: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var highlights: Double = 0
    var shadows: Double = 0
    var temperature: Double = 0
    var dehaze: Double = 0
    var sharpness: Double = 0
    var vignette: Double = 0
    var filmGrain: Double = 0

    static let original = EditRecipe()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case selectedLUTID
        case lutStrength
        case exposure
        case contrast
        case saturation
        case highlights
        case shadows
        case temperature
        case dehaze
        case sharpness
        case vignette
        case filmGrain
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedLUTID = try container.decodeIfPresent(UUID.self, forKey: .selectedLUTID)
        lutStrength = try container.decodeIfPresent(Double.self, forKey: .lutStrength) ?? 1
        exposure = try container.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
        contrast = try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
        saturation = try container.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
        highlights = try container.decodeIfPresent(Double.self, forKey: .highlights) ?? 0
        shadows = try container.decodeIfPresent(Double.self, forKey: .shadows) ?? 0
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0
        dehaze = try container.decodeIfPresent(Double.self, forKey: .dehaze) ?? 0
        sharpness = try container.decodeIfPresent(Double.self, forKey: .sharpness) ?? 0
        vignette = try container.decodeIfPresent(Double.self, forKey: .vignette) ?? 0
        filmGrain = try container.decodeIfPresent(Double.self, forKey: .filmGrain) ?? 0
    }

    subscript(adjustment: AdjustmentKind) -> Double {
        get {
            switch adjustment {
            case .lut: lutStrength
            case .exposure: exposure
            case .contrast: contrast
            case .saturation: saturation
            case .highlights: highlights
            case .shadows: shadows
            case .temperature: temperature
            case .dehaze: dehaze
            case .sharpness: sharpness
            case .vignette: vignette
            case .filmGrain: filmGrain
            }
        }
        set {
            switch adjustment {
            case .lut: lutStrength = newValue
            case .exposure: exposure = newValue
            case .contrast: contrast = newValue
            case .saturation: saturation = newValue
            case .highlights: highlights = newValue
            case .shadows: shadows = newValue
            case .temperature: temperature = newValue
            case .dehaze: dehaze = newValue
            case .sharpness: sharpness = newValue
            case .vignette: vignette = newValue
            case .filmGrain: filmGrain = newValue
            }
        }
    }
}

struct EditPreset: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    let createdAt: Date
    var recipe: EditRecipe
}

enum AdjustmentKind: String, CaseIterable, Identifiable, Sendable {
    case lut
    case exposure
    case contrast
    case saturation
    case highlights
    case shadows
    case temperature
    case dehaze
    case sharpness
    case vignette
    case filmGrain

    var id: Self { self }

    var title: String {
        switch self {
        case .lut: "Strength"
        case .exposure: "Exposure"
        case .contrast: "Contrast"
        case .saturation: "Saturation"
        case .highlights: "Highlights"
        case .shadows: "Shadows"
        case .temperature: "Temperature"
        case .dehaze: "Dehaze"
        case .sharpness: "Sharpness"
        case .vignette: "Vignette"
        case .filmGrain: "Film Grain"
        }
    }

    var systemImage: String {
        switch self {
        case .lut: "camera.filters"
        case .exposure: "plusminus.circle"
        case .contrast: "circle.lefthalf.filled"
        case .saturation: "drop.halffull"
        case .highlights: "sun.max"
        case .shadows: "moon"
        case .temperature: "thermometer.variable"
        case .dehaze: "cloud"
        case .sharpness: "triangle"
        case .vignette: "circle.dotted"
        case .filmGrain: "square.grid.3x3"
        }
    }

    static let basicAdjustments: [AdjustmentKind] = [
        .exposure,
        .contrast,
        .saturation,
        .highlights,
        .shadows,
        .temperature,
        .dehaze,
        .sharpness,
        .vignette,
        .filmGrain
    ]

    var valueRange: ClosedRange<Double> {
        switch self {
        case .lut: 0...1
        case .exposure: -2...2
        case .contrast: 0.5...1.5
        case .saturation: 0...2
        case .highlights, .shadows, .temperature, .dehaze: -1...1
        case .sharpness, .vignette, .filmGrain: 0...1
        }
    }

    func formattedValue(_ value: Double) -> String {
        switch self {
        case .lut: value.formatted(.percent.precision(.fractionLength(0)))
        case .exposure: String(format: "%+.1f", value)
        case .contrast, .saturation: String(format: "%.2f", value)
        case .highlights, .shadows, .temperature, .dehaze:
            String(format: "%+.0f", value * 100)
        case .sharpness, .vignette, .filmGrain:
            value.formatted(.percent.precision(.fractionLength(0)))
        }
    }
}

struct PhotoAsset: Identifiable, Sendable {
    let id = UUID()
    let data: Data
    let isPNG: Bool
}
