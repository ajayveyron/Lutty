import Foundation

struct EditRecipe: Equatable, Sendable {
    var selectedLUTID: UUID?
    var lutStrength: Double = 1
    var exposure: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var temperature: Double = 0

    static let original = EditRecipe()
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
}

struct PhotoAsset: Identifiable, Sendable {
    let id = UUID()
    let data: Data
    let isPNG: Bool
}
