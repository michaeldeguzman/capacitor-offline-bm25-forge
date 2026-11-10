import XCTest
@testable import Plugin

final class TokenizerParityTests: XCTestCase {
    func testEveryCaseMatchesCSharp() throws {
        let fixture = try FixtureLoader.load("tokenizer")
        let cases = try XCTUnwrap(fixture["cases"] as? [[String: Any]])
        XCTAssertEqual(cases.count, fixture["count"] as? Int)
        XCTAssertGreaterThan(cases.count, 0)

        var mismatches: [String] = []
        for item in cases {
            let name = try XCTUnwrap(item["name"] as? String)
            let input = try XCTUnwrap(item["input"] as? String)
            let expected = try XCTUnwrap(item["tokens"] as? [String])
            let actual = Tokenizer.tokenize(input)
            if actual != expected {
                mismatches.append("case=\(name) input=\(input.debugDescription) csharp=\(expected) swift=\(actual)")
            }
        }
        print("tokenizer: \(cases.count) cases, \(mismatches.count) mismatches")
        XCTAssertTrue(mismatches.isEmpty, "Tokenizer mismatches:\n" + mismatches.joined(separator: "\n"))
    }

    /// Swift String equality uses canonical equivalence. The port must compare by UTF-16 units.
    func testStopWordMatchIsOrdinal() {
        XCTAssertTrue(StopWords.isStopWord("the"))
        XCTAssertFalse(StopWords.isStopWord("The"))
        XCTAssertFalse(StopWords.isStopWord("thé"))
        XCTAssertEqual(StopWords.english.count, 174)
    }
}
