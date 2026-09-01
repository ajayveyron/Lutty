import Foundation

struct EditRecipe: Equatable, Sendable {
    var selectedLUTID: UUID?
    var lutStrength: Double = 1
    var exposure: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var temperature: Double = 0

    static let original = EditRecipe()

    subscript(adjustment: AdjustmentKind) -> Double {
        get {
            switch adjustment {
            case .lut: lutStrength
            case .exposure: exposure
            case .contrast: contrast
            case .saturation: saturation
            case .temperature: temperature
            }
        }
        set {
            switch adjustment {
            case .lut: lutStrength = newValue
            case .exposure: exposure = newValue
            case .contrast: contrast = newValue
            case .saturation: saturation = newValue
            case .temperature: temperature = newValue
            }
        }
    }
}

enum AdjustmentKind: String, CaseIterable, Identifiable, Sendable {
    case lut
    case exposure
    case contrast
    case saturation
    case temperature

    var id: Self { self }

    var title: String {
        switch self {
        case .lut: "Strength"
        case .exposure: "Exposure"
        case .contrast: "Contrast"
        case .saturation: "Saturation"
        case .temperature: "Temperature"
        }
    }

    var systemImage: String {
        switch self {
        case .lut: "camera.filters"
        case .exposure: "plusminus.circle"
        case .contrast: "circle.lefthalf.filled"
        case .saturation: "drop.halffull"
        case .temperature: "thermometer.variable"
        }
    }

    static let basicAdjustments: [AdjustmentKind] = [
        .exposure,
        .contrast,
        .saturation,
        .temperature
    ]

    var valueRange: ClosedRange<Double> {
        switch self {
        case .lut: 0...1
        case .exposure: -2...2
        case .contrast: 0.5...1.5
        case .saturation: 0...2
        case .temperature: -1...1
        }
    }

    func formattedValue(_ value: Double) -> String {
        switch self {
        case .lut: value.formatted(.percent.precision(.fractionLength(0)))
        case .exposure: String(format: "%+.1f", value)
        case .contrast, .saturation: String(format: "%.2f", value)
        case .temperature: String(format: "%+.0f", value * 100)
        }
    }
}

struct PhotoAsset: Identifiable, Sendable {
    let id = UUID()
    let data: Data
    let isPNG: Bool
}
