import XCTest
@testable import Plugin

/// Pins the CharRules decisions for non-ASCII code units. The expected values are the .NET
/// results for char.IsLetterOrDigit, char.IsWhiteSpace, char.IsDigit and ToLowerInvariant.
final class CharacterRuleTests: XCTestCase {
    func testWhiteSpace() {
        for unit: UInt16 in [0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x2003, 0x2028, 0x2029, 0x3000] {
            XCTAssertTrue(CharRules.isWhiteSpace(unit), String(unit, radix: 16))
        }
        for unit: UInt16 in [0x200B, 0xFEFF, 0x180E, 0x41, 0x5F] {
            XCTAssertFalse(CharRules.isWhiteSpace(unit), String(unit, radix: 16))
        }
    }

    func testLetterOrDigit() {
        for unit: UInt16 in [0x41, 0x7A, 0x30, 0xE9, 0xDF, 0x3A3, 0x4E2D, 0x663, 0xFF11, 0x2B0] {
            XCTAssertTrue(CharRules.isLetterOrDigit(unit), String(unit, radix: 16))
        }
        // Combining marks, No, Nl, Cs, Cf, So and punctuation are not letters or digits.
        for unit: UInt16 in [0x301, 0xB2, 0xBD, 0x2167, 0x2460, 0xD83D, 0xDD27, 0x200B, 0x2764, 0x2019, 0x2D, 0x5F] {
            XCTAssertFalse(CharRules.isLetterOrDigit(unit), String(unit, radix: 16))
        }
    }

    func testDigit() {
        for unit: UInt16 in [0x30, 0x39, 0x663, 0xFF11] {
            XCTAssertTrue(CharRules.isDigit(unit), String(unit, radix: 16))
        }
        for unit: UInt16 in [0xB2, 0x2167, 0x41] {
            XCTAssertFalse(CharRules.isDigit(unit), String(unit, radix: 16))
        }
    }

    func testLowercase() {
        XCTAssertEqual(CharRules.lowercase(0x41), 0x61)
        XCTAssertEqual(CharRules.lowercase(0xC9), 0xE9)
        XCTAssertEqual(CharRules.lowercase(0x3A3), 0x3C3)   // Sigma goes to sigma, never final sigma
        XCTAssertEqual(CharRules.lowercase(0x1E9E), 0xDF)   // capital sharp s goes to sharp s
        XCTAssertEqual(CharRules.lowercase(0x212A), 0x6B)   // Kelvin sign goes to k
        XCTAssertEqual(CharRules.lowercase(0x130), 0x130)   // dotted capital I stays, as in .NET invariant
        XCTAssertEqual(CharRules.lowercase(0x131), 0x131)
        XCTAssertEqual(CharRules.lowercase(0xD83D), 0xD83D) // surrogates pass through
    }

    func testSupplementaryCharactersAreDropped() {
        // Mathematical bold letters are letters in Unicode but surrogate pairs in UTF-16.
        XCTAssertEqual(Tokenizer.tokenize("\u{1D429}\u{1D42E}\u{1D426}\u{1D429} pump"), ["pump"])
    }
}
