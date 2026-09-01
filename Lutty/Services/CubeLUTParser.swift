import Foundation

enum CubeLUTParserError: LocalizedError, Equatable {
    case fileTooLarge
    case unreadableText
    case missingCubeSize
    case duplicateCubeSize
    case unsupportedOneDimensionalLUT
    case unsupportedDirective(String)
    case invalidCubeSize
    case invalidDomain
    case invalidSample(line: Int)
    case incorrectSampleCount(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            "This LUT is too large to import."
        case .unreadableText:
            "This LUT is not readable text."
        case .missingCubeSize:
            "This file does not declare a 3D LUT size."
        case .duplicateCubeSize:
            "This file declares more than one LUT size."
        case .unsupportedOneDimensionalLUT:
            "1D and combined LUTs are not supported."
        case .unsupportedDirective(let directive):
            "Unsupported LUT directive: \(directive)."
        case .invalidCubeSize:
            "The LUT size must be between 2 and 128."
        case .invalidDomain:
            "The LUT color domain is invalid."
        case .invalidSample(let line):
            "The LUT has an invalid color sample on line \(line)."
        case .incorrectSampleCount(let expected, let actual):
            "The LUT declares \(expected) samples but contains \(actual)."
        }
    }
}
enum CubeLUTParser {
    static let maximumFileSize = 64 * 1_024 * 1_024

    static func parse(data: Data) throws -> ParsedCubeLUT {
        guard data.count <= maximumFileSize else {
            throw CubeLUTParserError.fileTooLarge
        }
        guard let source = String(data: data, encoding: .utf8) else {
            throw CubeLUTParserError.unreadableText
        }

        var title: String?
        var size: Int?
        var domainMinimum = LUTDomain.zero
        var domainMaximum = LUTDomain.one
        var samples: [Float] = []
        var hasStartedSamples = false

        for (index, rawLine) in source.components(separatedBy: .newlines).enumerated() {
            let lineNumber = index + 1
            let uncommented = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
            let line = uncommented.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("TITLE") {
                guard !hasStartedSamples else { throw CubeLUTParserError.invalidSample(line: lineNumber) }
                title = parseTitle(from: line)
                continue
            }

            let tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard let directive = tokens.first else { continue }

            switch directive.uppercased() {
            case "LUT_1D_SIZE":
                throw CubeLUTParserError.unsupportedOneDimensionalLUT
            case "LUT_3D_SIZE":
                guard !hasStartedSamples else { throw CubeLUTParserError.invalidSample(line: lineNumber) }
                guard size == nil else { throw CubeLUTParserError.duplicateCubeSize }
                guard tokens.count == 2, let parsedSize = Int(tokens[1]), (2...128).contains(parsedSize) else {
                    throw CubeLUTParserError.invalidCubeSize
                }
                size = parsedSize
                samples.reserveCapacity(parsedSize * parsedSize * parsedSize * 4)
            case "DOMAIN_MIN":
                guard !hasStartedSamples else { throw CubeLUTParserError.invalidSample(line: lineNumber) }
                domainMinimum = try parseDomain(tokens: tokens)
            case "DOMAIN_MAX":
                guard !hasStartedSamples else { throw CubeLUTParserError.invalidSample(line: lineNumber) }
                domainMaximum = try parseDomain(tokens: tokens)
            default:
                if directive.first?.isLetter == true {
                    throw CubeLUTParserError.unsupportedDirective(directive)
                }
                guard size != nil, tokens.count == 3,
                      let red = Float(tokens[0]),
                      let green = Float(tokens[1]),
                      let blue = Float(tokens[2]),
                      red.isFinite, green.isFinite, blue.isFinite else {
                    throw CubeLUTParserError.invalidSample(line: lineNumber)
                }
                hasStartedSamples = true
                samples.append(contentsOf: [red, green, blue, 1])
            }
        }

        guard let size else { throw CubeLUTParserError.missingCubeSize }
        guard domainMaximum.red > domainMinimum.red,
              domainMaximum.green > domainMinimum.green,
              domainMaximum.blue > domainMinimum.blue else {
            throw CubeLUTParserError.invalidDomain
        }

        let expected = size * size * size
        let actual = samples.count / 4
        guard actual == expected else {
            throw CubeLUTParserError.incorrectSampleCount(expected: expected, actual: actual)
        }

        let rgbaData = samples.withUnsafeBytes { Data($0) }
        return ParsedCubeLUT(
            title: title,
            size: size,
            domainMinimum: domainMinimum,
            domainMaximum: domainMaximum,
            rgbaData: rgbaData
        )
    }

    private static func parseTitle(from line: String) -> String? {
        let remainder = line.dropFirst("TITLE".count).trimmingCharacters(in: .whitespaces)
        let unquoted = remainder.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return unquoted.isEmpty ? nil : unquoted
    }

    private static func parseDomain(tokens: [String]) throws -> LUTDomain {
        guard tokens.count == 4,
              let red = Float(tokens[1]),
              let green = Float(tokens[2]),
              let blue = Float(tokens[3]),
              red.isFinite, green.isFinite, blue.isFinite else {
            throw CubeLUTParserError.invalidDomain
        }
        return LUTDomain(red: red, green: green, blue: blue)
    }
}
