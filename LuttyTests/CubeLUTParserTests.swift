import Foundation
import Testing
@testable import Lutty

@Suite("Cube LUT parser")
struct CubeLUTParserTests {
    @Test("Parses title, size, domain, and samples")
    func parsesValidCube() throws {
        let parsed = try CubeLUTParser.parse(data: Data(Self.identityCube.utf8))

        #expect(parsed.title == "Identity")
        #expect(parsed.size == 2)
        #expect(parsed.domainMinimum == .zero)
        #expect(parsed.domainMaximum == .one)
        #expect(parsed.rgbaData.count == 8 * 4 * MemoryLayout<Float>.size)
    }

    @Test("Rejects one-dimensional LUTs")
    func rejectsOneDimensionalCube() {
        let source = "LUT_1D_SIZE 2\n0 0 0\n1 1 1"
        do {
            _ = try CubeLUTParser.parse(data: Data(source.utf8))
            Issue.record("Expected the parser to reject a 1D LUT")
        } catch let error as CubeLUTParserError {
            #expect(error == .unsupportedOneDimensionalLUT)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Rejects a mismatched sample count")
    func rejectsWrongSampleCount() {
        let source = "LUT_3D_SIZE 2\n0 0 0\n1 1 1"
        do {
            _ = try CubeLUTParser.parse(data: Data(source.utf8))
            Issue.record("Expected the parser to reject the sample count")
        } catch let error as CubeLUTParserError {
            #expect(error == .incorrectSampleCount(expected: 8, actual: 2))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Rejects invalid domains and oversized cubes")
    func rejectsInvalidMetadata() {
        let invalidDomain = "LUT_3D_SIZE 2\nDOMAIN_MIN 1 0 0\nDOMAIN_MAX 0 1 1"
        #expect(throws: CubeLUTParserError.self) {
            try CubeLUTParser.parse(data: Data(invalidDomain.utf8))
        }

        let oversized = "LUT_3D_SIZE 129"
        #expect(throws: CubeLUTParserError.self) {
            try CubeLUTParser.parse(data: Data(oversized.utf8))
        }
    }

    static let identityCube = """
    TITLE "Identity"
    LUT_3D_SIZE 2
    DOMAIN_MIN 0 0 0
    DOMAIN_MAX 1 1 1
    0 0 0
    1 0 0
    0 1 0
    1 1 0
    0 0 1
    1 0 1
    0 1 1
    1 1 1
    """
}
