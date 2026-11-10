import XCTest
@testable import Plugin

final class StemmerParityTests: XCTestCase {
    func testEveryStemMatchesCSharp() throws {
        let fixture = try FixtureLoader.load("stemmer")
        let pairs = try XCTUnwrap(fixture["pairs"] as? [[String: String]])
        XCTAssertEqual(pairs.count, fixture["count"] as? Int)
        XCTAssertGreaterThan(pairs.count, 0)

        var mismatches: [String] = []
        for pair in pairs {
            let word = try XCTUnwrap(pair["word"])
            let expected = try XCTUnwrap(pair["stem"])
            let actual = PorterStemmer.stem(word)
            if actual != expected {
                mismatches.append("word=\(word) csharp=\(expected) swift=\(actual)")
            }
        }
        print("stemmer: \(pairs.count) pairs, \(mismatches.count) mismatches")
        XCTAssertTrue(mismatches.isEmpty, "Stemmer mismatches:\n" + mismatches.joined(separator: "\n"))
    }
}
