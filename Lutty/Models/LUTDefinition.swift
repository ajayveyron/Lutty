import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let cubeLUT = UTType(importedAs: "com.ajaypawriya.lutty.cube", conformingTo: .data)
}

struct LUTDomain: Codable, Equatable, Hashable, Sendable {
    var red: Float
    var green: Float
    var blue: Float

    static let zero = LUTDomain(red: 0, green: 0, blue: 0)
    static let one = LUTDomain(red: 1, green: 1, blue: 1)

    var values: [Float] { [red, green, blue] }
}

struct LUTDefinition: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    let storedFilename: String
    let importDate: Date
    let cubeSize: Int
    let domainMinimum: LUTDomain
    let domainMaximum: LUTDomain
}

struct ParsedCubeLUT: Equatable, Sendable {
    let title: String?
    let size: Int
    let domainMinimum: LUTDomain
    let domainMaximum: LUTDomain
    let rgbaData: Data
}
